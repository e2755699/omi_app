import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/activity_log.dart';
import '../../models/challenge.dart';
import '../../models/profile.dart';
import '../../models/progress.dart';
import '../../models/rules.dart';
import '../photo_store.dart';
import 'cloud_repository.dart';
import 'local_sync_database.dart';
import 'sync_engine.dart';

/// 雲端空間與訪客紀錄完全分開。隊友只保留於記憶體，登出即清除。
class CloudWorkspace extends ChangeNotifier {
  CloudWorkspace({required this.local, required this.remote, required this.group}) {
    engine = SyncEngine(scope: scope, local: local, remote: remote);
  }
  final LocalSyncDatabase local;
  final CloudRepository remote;
  final Json group;
  late final SyncEngine engine;
  String get scope => '${remote.userId}/${remote.groupId}';
  Profile profile = const Profile();
  ActivityLog log = ActivityLog();
  List<Player> peers = [];
  List<Json> cheers = [];
  List<SyncRecord> records = [];
  bool _closed = false;
  bool _refreshing = false;
  final Map<String, String> _photoUrls = {};
  String? message;

  DateTime get today {
    // 第一版群組固定台北時區；本機訪客仍沿用裝置日期。
    final taipei = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(taipei.year, taipei.month, taipei.day);
  }

  Challenge challengeFor(Profile p) => Challenge(
    title: group['name'] as String,
    start: p.startDate ?? parseDateKey(group['starts_on'] as String),
    end: parseDateKey(group['ends_on'] as String),
  );

  static Profile profileFrom(Json p, Json m, Json s) => Profile(
    name: p['display_name'] as String? ?? Profile.defaultName,
    avatar: p['avatar'] as String? ?? '😀',
    startDate: parseDateKey(m['starts_on'] as String),
    nourishChoice: {...(m['nourish_choice'] as List).cast<String>()},
    weightKg: (s['weight_kg'] as num?)?.toDouble(),
    bedtime: s['bedtime'] as int?,
    wakeTime: s['wake_time'] as int?,
    book: s['book'] as String? ?? '',
    week1Move: s['week1_move'] as String? ?? '',
    week1Obstacle: s['week1_obstacle'] as String? ?? '',
  );

  Future<void> readLocal() async {
    final rows = await local.records(scope);
    if (_closed) return;
    records = rows;
    Json data(String table) => rows.where((r) => r.table == table).firstOrNull?.data ?? {};
    final member = data('memberships');
    if (member.isEmpty) return;
    profile = profileFrom(data('profiles'), member, data('personal_settings'));
    final next = ActivityLog();
    for (final row in rows.where((r) => r.table == 'checkins')) {
      final parts = row.key.split('|');
      next.set(itemById(parts.last), parseDateKey(parts.first), Entry(amount: row.data['amount'] as int? ?? 0));
    }
    // 私人內容蓋過共享完成數，離線新增心得時也會立即顯示。
    for (final row in rows.where((r) => r.table == 'reflections')) {
      final parts = row.key.split('|');
      final notes = (row.data['answers'] as List? ?? []).cast<String>();
      next.set(
        itemById(parts.last),
        parseDateKey(parts.first),
        Entry(amount: notes.where((n) => n.trim().isNotEmpty).length, notes: notes),
      );
    }
    for (final row in rows.where((r) => r.table == 'weekly_photos')) {
      final path = row.data['object_path'] as String?;
      final ref = row.data['local_ref'] as String? ?? _photoUrls[path];
      next.set(
        itemById('photo'),
        parseDateKey(row.key),
        path == null ? Entry.empty : Entry(amount: 1, notes: ref == null ? [] : [ref]),
      );
    }
    log = next;
    await engine.refreshCounts();
    if (!_closed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_closed || _refreshing || !remote.authorized) return;
    _refreshing = true;
    message = null;
    try {
      await engine.sync();
      if (_closed || !remote.authorized) return;
      await readLocal();
      // 讀取失败先移除舊隊友，避免離組之後仍顯示快取。
      peers = [];
      cheers = [];
      final team = await remote.teammates();
      if (_closed || !remote.authorized) return;
      for (final member in team.members.where((m) => m['user_id'] != remote.userId)) {
        final id = member['user_id'] as String;
        final p = team.profiles.where((p) => p['user_id'] == id).firstOrNull ?? {};
        final activity = ActivityLog();
        for (final row in team.checkins.where((r) => r['user_id'] == id)) {
          activity.set(
            itemById(row['item_id'] as String),
            parseDateKey(row['period_date'] as String),
            Entry(amount: row['amount'] as int),
          );
        }
        peers.add(Player(id: id, profile: profileFrom(p, member, {}), log: activity));
      }
      cheers = team.cheers;
      for (final photo in records.where(
        (r) => r.table == 'weekly_photos' && r.data['object_path'] != null && r.data['local_ref'] == null,
      )) {
        final path = photo.data['object_path'] as String;
        final url = await remote.photoUrl(path);
        if (_closed || !remote.authorized) return;
        if (url != null) _photoUrls[path] = url;
      }
      await readLocal();
    } catch (_) {
      peers = [];
      cheers = [];
      message = '目前無法更新群組，自己的紀錄仍可在本機使用。';
    } finally {
      _refreshing = false;
      if (!_closed) notifyListeners();
    }
  }

  Future<void> edit(String table, String key, Json Function(Json?) change) async {
    if (_closed || !remote.authorized) throw SessionChanged();
    await local.edit(scope, table, key, change);
    await readLocal();
    unawaited(engine.sync().then((_) => readLocal()));
  }

  Future<void> saveProfile(Profile p) async {
    await edit('profiles', 'self', (_) => {'display_name': p.name, 'avatar': p.avatar});
    await edit(
      'memberships',
      'self',
      (_) => {'starts_on': dateKey(p.startDate!), 'nourish_choice': p.nourishChoice.toList()..sort()},
    );
    await edit(
      'personal_settings',
      'self',
      (_) => {
        'weight_kg': p.weightKg,
        'bedtime': p.bedtime,
        'wake_time': p.wakeTime,
        'book': p.book,
        'week1_move': p.week1Move,
        'week1_obstacle': p.week1Obstacle,
      },
    );
  }

  Future<void> toggle(ChallengeItem item, DateTime day, {int? amount}) => edit(
    'checkins',
    entryKey(item.id, day),
    (old) => {'amount': amount ?? ((old?['amount'] as int? ?? 0) > 0 ? 0 : item.quickAmount)},
  );

  Future<void> saveNotes(ChallengeItem item, DateTime day, List<String> notes) =>
      edit('reflections', entryKey(item.id, day), (_) => {'answers': notes.map((n) => n.trim()).toList()});

  Future<void> setPhoto(DateTime day, String? ref) {
    final period = dateKey(weekStart(day));
    final nonce = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    return edit(
      'weekly_photos',
      period,
      (_) => {
        'object_path': ref == null ? null : '${remote.groupId}/${remote.userId}/$period/$nonce.jpg',
        'local_ref': ?ref,
      },
    );
  }

  /// 僅帶入該群組可接受的日期，且不覆蓋任何既有雲端列。
  Future<void> importGuest(Profile p, ActivityLog guest) async {
    final original = await local.records(scope);
    final present = {for (final r in original) '${r.table}/${r.key}'};
    final start = profile.startDate!;
    if (!present.contains('profiles/self')) {
      await edit('profiles', 'self', (_) => {'display_name': p.name, 'avatar': p.avatar});
    }
    if (!present.contains('personal_settings/self')) {
      await edit(
        'personal_settings',
        'self',
        (_) => {
          'weight_kg': p.weightKg,
          'bedtime': p.bedtime,
          'wake_time': p.wakeTime,
          'book': p.book,
          'week1_move': p.week1Move,
          'week1_obstacle': p.week1Obstacle,
        },
      );
    }
    for (final period in guest.toJson().entries) {
      final weekly = period.key.startsWith('W');
      final day = parseDateKey(weekly ? period.key.substring(1) : period.key);
      final eligible = weekly ? !day.add(const Duration(days: 6)).isBefore(start) : !day.isBefore(start);
      if (!eligible || day.isAfter(today) || day.isAfter(challengeFor(profile).end)) continue;
      final rows = period.value as Map<String, Object?>;
      for (final row in rows.entries) {
        final e = Entry.fromJson(Map<String, dynamic>.from(row.value as Map));
        final item = itemById(row.key);
        final table = row.key == 'photo'
            ? 'weekly_photos'
            : ['noticed', 'review'].contains(row.key)
            ? 'reflections'
            : 'checkins';
        final key = row.key == 'photo' ? dateKey(day) : entryKey(row.key, day);
        if (present.contains('$table/$key')) continue;
        if (table == 'reflections') {
          await saveNotes(item, day, e.notes);
        } else if (table == 'weekly_photos') {
          if (e.notes.isNotEmpty) await setPhoto(day, await PhotoStore.copyForCloud(e.notes.first));
        } else {
          await toggle(item, day, amount: e.amount);
        }
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    peers = [];
    cheers = [];
    engine.dispose();
    super.dispose();
  }
}
