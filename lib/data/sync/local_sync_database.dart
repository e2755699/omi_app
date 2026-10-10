import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

typedef Json = Map<String, dynamic>;

/// 一列的本機內容，同時就是 durable outbox。取消打卡保留零值，不刪除列。
class SyncRecord {
  const SyncRecord({
    required this.table,
    required this.key,
    required this.data,
    this.version = 0,
    this.revision = 0,
    this.dirty = false,
    this.conflict,
  });
  final String table;
  final String key;
  final Json data;
  final int version;
  final int revision;
  final bool dirty;
  final Json? conflict;

  Json get sharedData => Map<String, dynamic>.from(data)..remove('local_ref');

  factory SyncRecord.fromRow(Json row) => SyncRecord(
    table: row['table_name'] as String,
    key: row['record_key'] as String,
    data: jsonDecode(row['payload'] as String) as Json,
    version: row['remote_version'] as int,
    revision: row['revision'] as int,
    dirty: row['dirty'] == 1,
    conflict: row['conflict'] == null ? null : jsonDecode(row['conflict'] as String) as Json,
  );
}

/// 每個 user + group 都有獨立 scope，使用 SQL 交易保護紀錄與待同步狀態。
class LocalSyncDatabase {
  LocalSyncDatabase(this.db);
  final Database db;
  static Future<LocalSyncDatabase>? _opening;

  static Future<LocalSyncDatabase> open() => _opening ??= () async {
    final factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactory;
    final path = kIsWeb ? 'omi-cloud-v1.db' : '${await factory.getDatabasesPath()}/omi-cloud-v1.db';
    return openWith(factory, path);
  }();

  @visibleForTesting
  static Future<LocalSyncDatabase> openWith(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE records(scope TEXT NOT NULL, table_name TEXT NOT NULL, '
            'record_key TEXT NOT NULL, payload TEXT NOT NULL, base_payload TEXT, '
            'remote_version INTEGER NOT NULL DEFAULT 0, revision INTEGER NOT NULL DEFAULT 1, '
            'dirty INTEGER NOT NULL DEFAULT 0, conflict TEXT, '
            'PRIMARY KEY(scope, table_name, record_key))',
          );
          await db.execute('CREATE INDEX outbox ON records(scope, dirty)');
          await db.execute('CREATE TABLE workspaces(scope TEXT PRIMARY KEY, metadata TEXT NOT NULL)');
        },
      ),
    );
    return LocalSyncDatabase(db);
  }

  Future<void> saveWorkspace(String scope, Json metadata) => db
      .insert('workspaces', {
        'scope': scope,
        'metadata': jsonEncode(metadata),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<Json?> workspace(String scope) async {
    final rows = await db.query('workspaces', where: 'scope=?', whereArgs: [scope]);
    return rows.isEmpty ? null : jsonDecode(rows.single['metadata'] as String) as Json;
  }

  Future<List<SyncRecord>> records(String scope) async => [
    for (final row in await db.query('records', where: 'scope=?', whereArgs: [scope])) SyncRecord.fromRow(row),
  ];

  Future<SyncRecord?> _find(DatabaseExecutor tx, String scope, String table, String key) async {
    final rows = await tx.query(
      'records',
      where: 'scope=? AND table_name=? AND record_key=?',
      whereArgs: [scope, table, key],
    );
    return rows.isEmpty ? null : SyncRecord.fromRow(rows.single);
  }

  /// read-modify-write 在交易內，不以整包舊快照覆蓋其他編輯。
  Future<void> edit(String scope, String table, String key, Json Function(Json?) transform) =>
      db.transaction((tx) async {
        final old = await _find(tx, scope, table, key);
        final next = transform(old?.data);
        await tx.insert('records', {
          'scope': scope,
          'table_name': table,
          'record_key': key,
          'payload': jsonEncode(next),
          'remote_version': old?.version ?? 0,
          'revision': (old?.revision ?? 0) + 1,
          'dirty': 1,
          'base_payload': old == null
              ? null
              : (await tx.query(
                  'records',
                  columns: ['base_payload'],
                  where: 'scope=? AND table_name=? AND record_key=?',
                  whereArgs: [scope, table, key],
                )).single['base_payload'],
          'conflict': old?.conflict == null ? null : jsonEncode(old!.conflict),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

  /// 上傳回應抵達時若已再次編輯，只推進基底版本，保留最新本機內容與 dirty。
  Future<void> acknowledge(String scope, SyncRecord sent, SyncRecord saved) => db.transaction((tx) async {
    final current = await _find(tx, scope, sent.table, sent.key);
    if (current == null) return;
    final unchanged = current.revision == sent.revision;
    await tx.update(
      'records',
      {
        'remote_version': saved.version,
        'base_payload': jsonEncode(saved.sharedData),
        'conflict': null,
        if (unchanged)
          'payload': jsonEncode({
            ...saved.data,
            if (sent.data['local_ref'] != null) 'local_ref': sent.data['local_ref'],
          }),
        'dirty': unchanged ? 0 : 1,
      },
      where: 'scope=? AND table_name=? AND record_key=?',
      whereArgs: [scope, sent.table, sent.key],
    );
  });

  Future<void> merge(String scope, List<SyncRecord> incoming) => db.transaction((tx) async {
    for (final remote in incoming) {
      final local = await _find(tx, scope, remote.table, remote.key);
      final same = local != null && const DeepCollectionEquality().equals(local.sharedData, remote.sharedData);
      if (local != null && local.dirty && !same) {
        if (local.version != remote.version) {
          await tx.update(
            'records',
            {
              'conflict': jsonEncode({'data': remote.data, 'version': remote.version}),
            },
            where: 'scope=? AND table_name=? AND record_key=?',
            whereArgs: [scope, remote.table, remote.key],
          );
        }
        continue;
      }
      final data = {...remote.data};
      if (local?.data['object_path'] == remote.data['object_path'] && local?.data['local_ref'] != null) {
        data['local_ref'] = local!.data['local_ref'];
      }
      await tx.insert('records', {
        'scope': scope,
        'table_name': remote.table,
        'record_key': remote.key,
        'payload': jsonEncode(data),
        'base_payload': jsonEncode(remote.sharedData),
        'remote_version': remote.version,
        'revision': local?.revision ?? 1,
        'dirty': 0,
        'conflict': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });

  Future<void> resolve(String scope, SyncRecord record, {required bool useLocal}) => db.transaction((tx) async {
    final current = await _find(tx, scope, record.table, record.key);
    final conflict = current?.conflict;
    if (current == null || conflict == null) return;
    if (!useLocal && (conflict['data'] as Map).isEmpty) {
      await tx.delete(
        'records',
        where: 'scope=? AND table_name=? AND record_key=?',
        whereArgs: [scope, record.table, record.key],
      );
      return;
    }
    await tx.update(
      'records',
      {
        'remote_version': conflict['version'],
        'base_payload': jsonEncode(conflict['data']),
        if (!useLocal) 'payload': jsonEncode(conflict['data']),
        'dirty': useLocal ? 1 : 0,
        'conflict': null,
        'revision': current.revision + 1,
      },
      where: 'scope=? AND table_name=? AND record_key=?',
      whereArgs: [scope, record.table, record.key],
    );
  });
}

/// JSON map 的 key 順序不代表內容差異。
class DeepCollectionEquality {
  const DeepCollectionEquality();
  bool equals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      return a.length == b.length && a.keys.every((k) => b.containsKey(k) && equals(a[k], b[k]));
    }
    if (a is List && b is List) {
      return a.length == b.length && List.generate(a.length, (i) => i).every((i) => equals(a[i], b[i]));
    }
    return a == b;
  }
}
