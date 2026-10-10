import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/challenge.dart';
import '../photo_store.dart';
import 'local_sync_database.dart';

class SyncConflict implements Exception {
  SyncConflict(this.remote);
  final SyncRecord remote;
}

class SessionChanged implements Exception {}

abstract class SyncGateway {
  Future<List<SyncRecord>> fetchOwn();
  Future<SyncRecord> save(SyncRecord record);
  bool get authorized;
}

/// 每次請求都驗證固定 user；切帳號後不能讓舊的同步工作沿用新 JWT。
class CloudRepository implements SyncGateway {
  CloudRepository(this.client, {required this.userId, required this.groupId});
  final SupabaseClient client;
  final String userId;
  final String groupId;
  @override
  bool get authorized => client.auth.currentUser?.id == userId;
  void _check() {
    if (!authorized) throw SessionChanged();
  }

  static const fields = <String, List<String>>{
    'profiles': ['display_name', 'avatar'],
    'memberships': ['starts_on', 'nourish_choice'],
    'personal_settings': ['weight_kg', 'bedtime', 'wake_time', 'book', 'week1_move', 'week1_obstacle'],
    'checkins': ['amount'],
    'reflections': ['answers'],
    'weekly_photos': ['object_path'],
  };

  static String recordKey(String table, Json row) => switch (table) {
    'checkins' || 'reflections' => '${row['period_date']}|${row['item_id']}',
    'weekly_photos' => row['period_date'] as String,
    _ => 'self',
  };

  static SyncRecord decode(String table, Json row) => SyncRecord(
    table: table,
    key: recordKey(table, row),
    version: (row['version'] as num).toInt(),
    data: {for (final field in fields[table]!) field: row[field]},
  );

  Map<String, Object> _identity(SyncRecord record) {
    if (!fields.containsKey(record.table)) throw ArgumentError('不支援的資料表');
    return {
      'user_id': userId,
      if (record.table != 'profiles') 'group_id': groupId,
      if (record.table == 'checkins' || record.table == 'reflections') ...{
        'period_date': record.key.split('|').first,
        'item_id': record.key.split('|').last,
      },
      if (record.table == 'weekly_photos') 'period_date': record.key,
    };
  }

  Future<SyncRecord?> _current(SyncRecord record) async {
    _check();
    final row = await client.from(record.table).select().match(_identity(record)).maybeSingle();
    _check();
    return row == null ? null : decode(record.table, row);
  }

  @override
  Future<List<SyncRecord>> fetchOwn() async {
    _check();
    final membership = await client
        .from('memberships')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('active', true)
        .maybeSingle();
    _check();
    if (membership == null) throw StateError('你目前不是這個群組的成員，紀錄仍保留在本機。');
    final records = <SyncRecord>[];
    for (final table in fields.keys) {
      _check();
      var query = client.from(table).select().eq('user_id', userId);
      if (table != 'profiles') query = query.eq('group_id', groupId);
      var ordered = query.order('user_id');
      if (table != 'profiles') ordered = ordered.order('group_id');
      if (['checkins', 'reflections', 'weekly_photos'].contains(table)) ordered = ordered.order('period_date');
      if (table == 'checkins' || table == 'reflections') ordered = ordered.order('item_id');
      // 84 天的單人紀錄也可能超過 API 預設的 1,000 列。
      for (var offset = 0; ; offset += 500) {
        final rows = await ordered.range(offset, offset + 499);
        _check();
        records.addAll(rows.map((row) => decode(table, row)));
        if (rows.length < 500) break;
      }
    }
    return records;
  }

  @override
  Future<SyncRecord> save(SyncRecord record) async {
    _check();
    final existing = await _current(record);
    if (existing != null && const DeepCollectionEquality().equals(existing.sharedData, record.sharedData)) {
      return existing;
    }
    if ((existing?.version ?? 0) != record.version) {
      throw SyncConflict(existing ?? SyncRecord(table: record.table, key: record.key, data: {}));
    }
    if (record.table == 'weekly_photos' && record.data['local_ref'] != null && record.data['object_path'] != null) {
      final bytes = await PhotoStore.read(record.data['local_ref'] as String);
      final type = bytes.length >= 12 && bytes[0] == 0x89 && bytes[1] == 0x50
          ? 'image/png'
          : bytes.length >= 12 && bytes[0] == 0x52 && bytes[8] == 0x57
          ? 'image/webp'
          : 'image/jpeg';
      _check();
      try {
        await client.storage
            .from('weekly-photos')
            .uploadBinary(
              record.data['object_path'] as String,
              bytes,
              fileOptions: FileOptions(contentType: type, upsert: false),
            );
      } on StorageException catch (error) {
        // 路徑是這次本機照片的唯一 ID；網路回應遺失後重試可沿用已上傳檔案。
        if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
      }
    }
    _check();
    final payload = {for (final key in fields[record.table]!) key: record.data[key]};
    try {
      Json? row;
      if (existing == null) {
        row = await client.from(record.table).insert({..._identity(record), ...payload}).select().single();
      } else {
        final updated = await client
            .from(record.table)
            .update({...payload, 'version': record.version})
            .match(_identity(record))
            .eq('version', record.version)
            .select();
        row = updated.firstOrNull;
      }
      _check();
      if (row == null) {
        throw SyncConflict(await _current(record) ?? SyncRecord(table: record.table, key: record.key, data: {}));
      }
      return decode(record.table, row);
    } on PostgrestException catch (error) {
      if (error.code != '23505' && error.code != '40001') rethrow;
      final current = await _current(record);
      if (current != null && const DeepCollectionEquality().equals(current.sharedData, record.sharedData)) {
        return current;
      }
      throw SyncConflict(current ?? SyncRecord(table: record.table, key: record.key, data: {}));
    }
  }

  Future<Json> group() async {
    _check();
    final row = await client.from('challenge_groups').select().eq('id', groupId).single();
    _check();
    return row;
  }

  Future<({List<Json> members, List<Json> profiles, List<Json> checkins, List<Json> cheers})> teammates() async {
    _check();
    // 先確認仍在組內，失去資格時不可把只有自己的 RLS 結果當成完整群組。
    final member = await client
        .from('memberships')
        .select('active')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    if (member?['active'] != true) throw StateError('已離開群組');
    Future<List<Json>> all(String table, List<String> order) async {
      final result = <Json>[];
      var query = client.from(table).select().eq('group_id', groupId).order(order.first);
      for (final field in order.skip(1)) {
        query = query.order(field);
      }
      for (var offset = 0; ; offset += 500) {
        _check();
        final page = await query.range(offset, offset + 499);
        _check();
        result.addAll(page);
        if (page.length < 500) return result;
      }
    }

    final members = (await all('memberships', ['user_id'])).where((m) => m['active'] == true).toList();
    _check();
    final ids = members.map((m) => m['user_id'] as String).toList();
    final profiles = <Json>[];
    for (var offset = 0; offset < ids.length; offset += 50) {
      _check();
      profiles.addAll(await client.from('profiles').select().inFilter('user_id', ids.skip(offset).take(50).toList()));
    }
    _check();
    final entries = await all('checkins', ['user_id', 'period_date', 'item_id']);
    _check();
    final cheers = await all('cheers', ['from_user_id', 'to_user_id', 'cheer_date']);
    _check();
    return (members: members, profiles: profiles, checkins: entries, cheers: cheers);
  }

  Future<String?> photoUrl(String? path) async {
    if (path == null) return null;
    _check();
    final url = await client.storage.from('weekly-photos').createSignedUrl(path, 900);
    _check();
    return url;
  }

  Future<void> cheer(String toUserId, bool complete) async {
    _check();
    await client.rpc(
      'send_cheer',
      params: {'p_group_id': groupId, 'p_to_user_id': toUserId, 'p_kind': complete ? 'celebrate' : 'cheer'},
    );
    _check();
  }
}

/// 以日曆日期穩定對應原有 ActivityLog 的每日／每週紀錄。
String entryKey(String itemId, DateTime day) =>
    '${dateKey(itemId == 'review' || itemId == 'photo' ? weekStart(day) : day)}|$itemId';
