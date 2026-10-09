import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omi_app/data/sync/cloud_repository.dart';
import 'package:omi_app/data/sync/local_sync_database.dart';
import 'package:omi_app/data/sync/sync_engine.dart';

class FakeGateway implements SyncGateway {
  @override
  bool authorized = true;
  List<SyncRecord> rows = [];
  bool offline = false;
  bool loseReply = false;
  Completer<void>? hold;
  Completer<void>? started;
  int writes = 0;
  @override
  Future<List<SyncRecord>> fetchOwn() async {
    if (offline) throw StateError('offline');
    return rows;
  }

  @override
  Future<SyncRecord> save(SyncRecord record) async {
    started?.complete();
    await hold?.future;
    if (!authorized) throw SessionChanged();
    final current = rows.where((r) => r.key == record.key && r.table == record.table).firstOrNull;
    if (current != null && current.version != record.version) throw SyncConflict(current);
    writes++;
    final saved = SyncRecord(
      table: record.table,
      key: record.key,
      data: record.sharedData,
      version: record.version + 1,
    );
    rows = [...rows.where((r) => r.key != record.key || r.table != record.table), saved];
    if (loseReply) {
      loseReply = false;
      throw StateError('response lost');
    }
    return saved;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalSyncDatabase local;
  late FakeGateway remote;
  late SyncEngine engine;
  const scope = 'alice/group-a';
  const key = '2026-10-09|reading';
  Future<void> edit(int amount, {String target = scope}) =>
      local.edit(target, 'checkins', key, (_) => {'amount': amount});
  Future<SyncRecord> row({String target = scope}) async => (await local.records(target)).single;
  SyncRecord server(int amount, int version) =>
      SyncRecord(table: 'checkins', key: key, data: {'amount': amount}, version: version);
  setUp(() async {
    local = await LocalSyncDatabase.openWith(databaseFactoryFfi, inMemoryDatabasePath);
    remote = FakeGateway();
    engine = SyncEngine(scope: scope, local: local, remote: remote);
  });
  tearDown(() async {
    engine.dispose();
    await local.db.close();
  });

  test('離線佇列保留，重新連線後同步並清掉 dirty', () async {
    await edit(1);
    remote.offline = true;
    await engine.sync();
    expect((await row()).dirty, true);
    expect(engine.error, isNotNull);
    remote.offline = false;
    await engine.sync();
    expect((await row()).dirty, false);
    expect(remote.rows.single.data['amount'], 1);
  });
  test('回應遺失重試不會把一次打卡重複成兩次', () async {
    await edit(1);
    remote.loseReply = true;
    await engine.sync();
    expect((await row()).dirty, true);
    await engine.sync();
    expect((await row()).dirty, false);
    expect(remote.writes, 1);
  });
  test('上傳期間再次編輯不會被舊回應覆蓋', () async {
    await edit(1);
    remote.hold = Completer();
    remote.started = Completer();
    final syncing = engine.sync();
    await remote.started!.future;
    await edit(0);
    remote.hold!.complete();
    await syncing;
    expect((await row()).data['amount'], 0);
    expect((await row()).dirty, true);
    expect((await row()).version, 1);
    remote.hold = null;
    remote.started = null;
    await engine.sync();
    expect(remote.rows.single.data['amount'], 0);
    expect((await row()).dirty, false);
  });
  test('跨裝置修改需要選擇衝突，保留本機後沿用新版本同步', () async {
    await local.merge(scope, [server(1, 1)]);
    await edit(0);
    remote.rows = [server(2, 2)];
    await engine.sync();
    expect(engine.conflicts, 1);
    expect(remote.writes, 0);
    await local.resolve(scope, await row(), useLocal: true);
    await engine.sync();
    expect(remote.rows.single.data['amount'], 0);
    expect((await row()).version, 3);
  });
  test('採用雲端解決衝突後不再上傳本機舊值', () async {
    await local.merge(scope, [server(1, 1)]);
    await edit(0);
    remote.rows = [server(2, 2)];
    await engine.sync();
    await local.resolve(scope, await row(), useLocal: false);
    await engine.sync();
    expect((await row()).data['amount'], 2);
    expect(remote.writes, 0);
  });
  test('零值是可同步的取消紀錄，不會被舊雲端值復活', () async {
    await local.merge(scope, [server(1, 1)]);
    remote.rows = [server(1, 1)];
    await edit(0);
    await engine.sync();
    expect(remote.rows.single.data['amount'], 0);
    expect((await row()).dirty, false);
  });
  test('不同帳號與群組的佇列互不影響', () async {
    await edit(1);
    await edit(2, target: 'bob/group-a');
    await edit(3, target: 'alice/group-b');
    await engine.sync();
    expect(remote.rows.single.data['amount'], 1);
    expect((await row(target: 'bob/group-a')).dirty, true);
    expect((await row(target: 'alice/group-b')).dirty, true);
  });
  test('登出發生在請求途中，不會确认舊帳號的佇列', () async {
    await edit(1);
    remote.hold = Completer();
    remote.started = Completer();
    final syncing = engine.sync();
    await remote.started!.future;
    remote.authorized = false;
    remote.hold!.complete();
    await syncing;
    expect((await row()).dirty, true);
    expect(remote.writes, 0);
  });
  test('同時做 read-modify-write 會在交易內串行，不遺失編輯', () async {
    await Future.wait(
      List.generate(
        20,
        (_) => local.edit(scope, 'checkins', key, (old) => {'amount': (old?['amount'] as int? ?? 0) + 1}),
      ),
    );
    expect((await row()).data['amount'], 20);
    expect((await row()).revision, 20);
  });
  test('關閉再打開資料庫仍保有待同步工作與所屬群組', () async {
    final dir = await Directory.systemTemp.createTemp('omi-sync-test-');
    try {
      var disk = await LocalSyncDatabase.openWith(databaseFactoryFfi, '${dir.path}/outbox.db');
      await disk.edit(scope, 'checkins', key, (_) => {'amount': 1});
      await disk.saveWorkspace(scope, {'name': 'Omi'});
      await disk.db.close();
      disk = await LocalSyncDatabase.openWith(databaseFactoryFfi, '${dir.path}/outbox.db');
      expect((await disk.records(scope)).single.dirty, true);
      expect((await disk.workspace(scope))!['name'], 'Omi');
      await disk.db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('照片 local_ref 不會被當成雲端衝突或上傳欄位', () async {
    await local.edit(
      scope,
      'weekly_photos',
      '2026-10-05',
      (_) => {'object_path': 'path.jpg', 'local_ref': '/private/local.jpg'},
    );
    final sent = (await local.records(scope)).single;
    expect(sent.sharedData.containsKey('local_ref'), false);
    await local.merge(scope, [
      const SyncRecord(table: 'weekly_photos', key: '2026-10-05', version: 1, data: {'object_path': 'path.jpg'}),
    ]);
    final merged = (await local.records(scope)).single;
    expect(merged.dirty, false);
    expect(merged.data['local_ref'], '/private/local.jpg');
  });
}
