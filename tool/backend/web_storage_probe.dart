import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:omi_app/data/sync/local_sync_database.dart';

/// 只供本機瀏覽器驗證 IndexedDB／SQLite worker；不連 Supabase、不碰使用者資料。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var message = '';
  try {
    // 與自動測試相同的隔離資料庫，避免驗證工具寫到 App 真實工作區。
    // ignore: invalid_use_of_visible_for_testing_member
    final db = await LocalSyncDatabase.openWith(databaseFactoryFfiWeb, 'omi-storage-probe.db');
    final old = await db.workspace('probe');
    final visit = (old?['visits'] as int? ?? 0) + 1;
    await db.saveWorkspace('probe', {'visits': visit});
    await Future.wait(List.generate(10, (_) => db.edit('probe', 'checkins', 'counter',
      (row) => {'amount': (row?['amount'] as int? ?? 0) + 1})));
    final amount = (await db.records('probe')).single.data['amount'];
    if (amount != visit * 10) throw StateError('transaction count mismatch: $amount');
    message = 'PASS · SQLite 網頁交易與持久儲存\n開啟次數 $visit · 累積寫入 $amount\n重新整理後數值應增加 1 與 10。';
  } catch (error) { message = 'FAIL · $error'; }
  runApp(MaterialApp(home: Scaffold(body: Center(child: SelectableText(message, style: const TextStyle(fontSize: 22))))));
}
