import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cloud_repository.dart';
import 'local_sync_database.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine({required this.scope, required this.local, required this.remote});
  final String scope;
  final LocalSyncDatabase local;
  final SyncGateway remote;
  bool busy = false;
  String? error;
  int pending = 0;
  int conflicts = 0;
  bool _closed = false;
  bool _again = false;
  Completer<void>? _done;

  Future<void> refreshCounts() async {
    final records = await local.records(scope);
    pending = records.where((r) => r.dirty).length;
    conflicts = records.where((r) => r.conflict != null).length;
    if (!_closed) notifyListeners();
  }

  Future<void> sync() async {
    if (_closed || !remote.authorized) return;
    if (busy) {
      _again = true;
      return _done!.future;
    }
    final done = Completer<void>();
    _done = done;
    busy = true;
    error = null;
    notifyListeners();
    try {
      do {
        _again = false;
        final incoming = await remote.fetchOwn();
        if (_closed || !remote.authorized) return;
        await local.merge(scope, incoming);
        final pending = (await local.records(scope)).where((r) => r.dirty && r.conflict == null).toList();
        for (final record in pending) {
          if (_closed || !remote.authorized) return;
          try {
            final saved = await remote.save(record);
            if (_closed || !remote.authorized) return;
            await local.acknowledge(scope, record, saved);
          } on SyncConflict catch (conflict) {
            await local.merge(scope, [conflict.remote]);
          }
        }
      } while (_again && !_closed && remote.authorized);
    } on SessionChanged {
      // 登出時中斷；未完成的工作仍留在原帳號的本機佇列。
    } catch (_) {
      error = '尚未同步完成，紀錄已保存在這台裝置。連線後可再試一次。';
    } finally {
      try {
        if (!_closed) await refreshCounts();
      } finally {
        busy = false;
        done.complete();
        if (_again && !_closed && remote.authorized) unawaited(sync());
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
