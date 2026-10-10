import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:omi_app/data/sync/cloud_repository.dart';
import 'package:omi_app/data/sync/cloud_workspace.dart';
import 'package:omi_app/data/sync/local_sync_database.dart';
import 'package:omi_app/models/activity_log.dart';
import 'package:omi_app/models/profile.dart';
import 'package:omi_app/models/rules.dart';

class WorkspaceRemote extends CloudRepository {
  WorkspaceRemote(super.client) : super(userId: 'alice', groupId: 'group');
  bool online = true;
  List<SyncRecord> rows = [];
  @override
  bool get authorized => true;
  @override
  Future<List<SyncRecord>> fetchOwn() async {
    if (!online) throw StateError('offline');
    return rows;
  }

  @override
  Future<SyncRecord> save(SyncRecord record) async {
    final saved = SyncRecord(
      table: record.table,
      key: record.key,
      data: record.sharedData,
      version: record.version + 1,
    );
    rows = [...rows.where((r) => r.table != record.table || r.key != record.key), saved];
    return saved;
  }

  @override
  Future<({List<Json> members, List<Json> profiles, List<Json> checkins, List<Json> cheers})> teammates() async {
    if (!online) throw StateError('offline');
    return (
      members: <Json>[
        {
          'user_id': 'bob',
          'starts_on': '2026-10-10',
          'nourish_choice': ['protein', 'water'],
        },
      ],
      profiles: <Json>[
        {'user_id': 'bob', 'display_name': '夥伴', 'avatar': '😀'},
      ],
      checkins: <Json>[
        {'user_id': 'bob', 'period_date': '2026-10-10', 'item_id': 'noticed', 'amount': 1},
      ],
      cheers: <Json>[],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalSyncDatabase local;
  late WorkspaceRemote remote;
  late CloudWorkspace workspace;
  setUp(() async {
    local = await LocalSyncDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    remote = WorkspaceRemote(SupabaseClient('https://test.invalid', 'public-test-key'));
    remote.rows = [
      const SyncRecord(
        table: 'memberships',
        key: 'self',
        version: 1,
        data: {
          'starts_on': '2026-10-09',
          'nourish_choice': ['produce', 'water'],
        },
      ),
      const SyncRecord(table: 'profiles', key: 'self', version: 1, data: {'display_name': '雲端名稱', 'avatar': '😀'}),
    ];
    workspace = CloudWorkspace(
      local: local,
      remote: remote,
      group: {'name': 'Omi', 'starts_on': '2026-10-09', 'ends_on': '2026-12-31', 'timezone': 'Asia/Taipei'},
    );
    await local.merge(workspace.scope, remote.rows);
    await workspace.readLocal();
  });
  tearDown(() async {
    await workspace.engine.sync();
    workspace.dispose();
    await remote.client.dispose();
    await local.db.close();
  });
  test('私人心得與週回顧覆蓋共享數量，週間第一天正確映射', () async {
    remote.online = false;
    await workspace.saveNotes(itemById('noticed'), DateTime(2026, 10, 9), ['今天的私人文字']);
    await workspace.saveNotes(itemById('review'), DateTime(2026, 10, 9), ['做得好', '', '下週計畫']);
    expect(workspace.log.entryOn(itemById('noticed'), DateTime(2026, 10, 9)).notes, ['今天的私人文字']);
    expect(workspace.log.entryOn(itemById('review'), DateTime(2026, 10, 10)).amount, 2);
    expect(workspace.records.any((r) => r.key == '2026-10-05|review'), true);
  });
  test('匯入跳過群組前的日子與既有列，原稿保持完整', () async {
    remote.online = false;
    await local.merge(workspace.scope, [
      const SyncRecord(table: 'checkins', key: '2026-10-09|reading', version: 1, data: {'amount': 0}),
    ]);
    final guest = ActivityLog()
      ..set(itemById('reading'), DateTime(2026, 10, 9), const Entry(amount: 1))
      ..set(itemById('sleep'), DateTime(2026, 10, 8), const Entry(amount: 1))
      ..set(itemById('review'), DateTime(2026, 10, 9), const Entry(amount: 1, notes: ['第一週', '', '']));
    await workspace.importGuest(const Profile(name: '本機名稱', weightKg: 60), guest);
    expect(workspace.profile.name, '雲端名稱');
    expect(workspace.profile.weightKg, 60);
    expect(workspace.log.entryOn(itemById('reading'), DateTime(2026, 10, 9)).amount, 0);
    expect(workspace.log.entryOn(itemById('sleep'), DateTime(2026, 10, 8)).amount, 0);
    expect(workspace.log.entryOn(itemById('review'), DateTime(2026, 10, 9)).notes.first, '第一週');
    expect(guest.entryOn(itemById('reading'), DateTime(2026, 10, 9)).amount, 1);
  });
  test('隊友使用自己的開跑日，只顯示心得完成數；失去連線清除舊隊友', () async {
    await workspace.refresh();
    final peer = workspace.peers.single;
    expect(workspace.challengeFor(peer.profile).start, DateTime(2026, 10, 10));
    expect(peer.log.entryOn(itemById('noticed'), DateTime(2026, 10, 10)).amount, 1);
    expect(peer.log.entryOn(itemById('noticed'), DateTime(2026, 10, 10)).notes, isEmpty);
    expect(peer.profile.weightKg, isNull);
    remote.online = false;
    await workspace.refresh();
    expect(workspace.peers, isEmpty);
    expect(workspace.profile.name, '雲端名稱');
  });
}
