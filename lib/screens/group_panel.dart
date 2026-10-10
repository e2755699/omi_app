import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/challenge_store.dart';
import '../data/sync/local_sync_database.dart';
import '../models/challenge.dart';
import '../models/rules.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';

class GroupPanel extends StatefulWidget {
  const GroupPanel({super.key, required this.store});
  final ChallengeStore store;
  @override
  State<GroupPanel> createState() => _GroupPanelState();
}

class _GroupPanelState extends State<GroupPanel> {
  List<Json> _groups = [];
  bool _busy = false;
  String? _message;
  String? _invite;
  final _name = TextEditingController(text: 'Omi 一起挑戰');
  final _code = TextEditingController();
  ChallengeStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _message = '操作尚未完成。請確認網路、邀請碼及開跑日期後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final account = store.account;
    final uid = account.userId;
    if (uid == null) return;
    final memberships = await account.client!
        .from('memberships')
        .select('group_id')
        .eq('user_id', uid)
        .eq('active', true);
    if (account.userId != uid) return;
    final ids = memberships.map((m) => m['group_id'] as String).toList();
    final groups = ids.isEmpty ? <Json>[] : await account.client!.from('challenge_groups').select().inFilter('id', ids);
    if (mounted && account.userId == uid) setState(() => _groups = groups);
  }

  Future<void> _createOrJoin({required bool create}) async {
    final account = store.account;
    final uid = account.userId;
    if (uid == null) return;
    final profile = store.profile;
    final start = profile.startDate ?? store.today;
    final nourish = profile.nourishChoice.toList()..sort();
    final id = await account.client!.rpc(
      create ? 'create_challenge_group' : 'join_challenge_group',
      params: create
          ? {
              'p_name': _name.text.trim(),
              'p_starts_on': dateKey(officialStart),
              'p_ends_on': dateKey(challengeEnd),
              'p_personal_start': dateKey(start),
              'p_nourish': nourish,
              'p_timezone': 'Asia/Taipei',
            }
          : {'p_token': _code.text.trim(), 'p_starts_on': dateKey(start), 'p_nourish': nourish},
    );
    if (account.userId != uid) return;
    await store.openGroup(id as String);
    // 建立／加入時僅帶入顯示名稱和頭像；私人設定與紀錄由使用者另外選擇匯入。
    final cloud = store.cloud;
    if (cloud != null && !cloud.records.any((r) => r.table == 'profiles')) {
      await cloud.edit('profiles', 'self', (_) => {'display_name': profile.name, 'avatar': profile.avatar});
    }
    await _load();
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('先不要')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final cloud = store.cloud;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const SectionTitle(tag: 'GROUP', title: '和夥伴一起走'),
          const SizedBox(height: 12),
          if (cloud != null) ...[
            PixelBox(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cloud.group['name'] as String, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('還沒同步到帳號 ${cloud.engine.pending} 筆 · 等你選版本 ${cloud.engine.conflicts} 筆'),
                  const Text('群組日期以台北時間計算。沒網路時也能記錄，連上網路後重新開啟 App 或按「立即同步」就會補上。'),
                  if (cloud.engine.error ?? cloud.message case final String error) Text(error),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: _busy ? null : () => _run(cloud.refresh), child: const Text('立即同步')),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (!await _confirm(
                                  '把這台裝置的紀錄存到帳號？',
                                  '會把符合群組日期的打卡、私人心得、設定和照片存到你的帳號。心得只有你看得到，照片同組成員看得到。帳號裡已經有的紀錄不會被蓋掉，這台裝置上原本的紀錄也會留著。',
                                )) {
                                  return;
                                }
                                if (!mounted || store.cloud != cloud || !cloud.remote.authorized) return;
                                await store.importLocalRecords();
                              }),
                        child: const Text('把這台裝置的紀錄存到帳號'),
                      ),
                      TextButton(onPressed: _busy ? null : () => _run(store.useLocal), child: const Text('改回只存在這台裝置')),
                    ],
                  ),
                  if (cloud.group['owner_id'] == store.account.userId)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final uid = store.account.userId;
                              final token = await store.account.client!.rpc(
                                'rotate_group_invite',
                                params: {'p_group_id': cloud.remote.groupId},
                              );
                              if (mounted && store.account.userId == uid) setState(() => _invite = token as String);
                            }),
                      child: const Text('產生邀請碼（舊碼會失效）'),
                    ),
                  if (_invite != null) ...[
                    SelectableText(_invite!),
                    TextButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: _invite!)),
                      child: const Text('複製邀請碼 · 七天有效'),
                    ),
                  ],
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (!await _confirm('離開這個群組？', '離開後彼此看不到進度。你的紀錄會留在帳號裡，使用有效邀請碼重新加入即可繼續。')) return;
                            if (!mounted || store.cloud != cloud || !cloud.remote.authorized) return;
                            await store.account.client!.rpc(
                              'leave_challenge_group',
                              params: {'p_group_id': cloud.remote.groupId},
                            );
                            if (!mounted || store.cloud != cloud || !cloud.remote.authorized) return;
                            await store.useLocal();
                            await _load();
                          }),
                    child: const Text('離開群組'),
                  ),
                ],
              ),
            ),
            for (final record in cloud.records.where((r) => r.conflict != null))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PixelBox(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('兩台裝置都有修改 · ${_recordLabel(record)}'),
                      Text('這台裝置的版本：${_describe(record.data)}'),
                      Text('帳號裡的版本：${_describe(Map<String, dynamic>.from(record.conflict!['data'] as Map))}'),
                      Wrap(
                        children: [
                          for (final useLocal in [true, false])
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await cloud.local.resolve(cloud.scope, record, useLocal: useLocal);
                                      await cloud.readLocal();
                                      await cloud.refresh();
                                    }),
                              child: Text(useLocal ? '用這台裝置的版本' : '用帳號裡的版本'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          for (final group in _groups.where((g) => g['id'] != cloud?.remote.groupId))
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      _invite = null;
                      await store.openGroup(group['id'] as String);
                    }),
              child: Text('開啟 ${group['name']}'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: '夥伴給你的邀請碼'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _run(() => _createOrJoin(create: false)),
            child: const Text('加入群組'),
          ),
          TextField(
            controller: _name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '建立新群組的名稱'),
          ),
          const Text('本輪挑戰：2026/10/9－12/31。建立或加入時會使用目前的開跑日、Nourish 選擇、顯示名稱和頭像。'),
          TextButton(
            onPressed: _busy ? null : () => _run(() => _createOrJoin(create: true)),
            child: const Text('建立群組'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null) Text(_message!),
        ],
      );
    },
  );

  /// Turns a sync record key (`2026-10-12|workout`, `2026-10-12`, `self`) into a
  /// label the owner recognises; the raw key is for storage, not for people.
  String _recordLabel(SyncRecord record) {
    if (record.table == 'profiles') return '個人設定';
    final parts = record.key.split('|');
    final day = parseDateKey(parts.first);
    final date = '${day.month}/${day.day}';
    if (record.table == 'weekly_photos') return '$date 那週的照片';
    return '$date 的${itemById(parts.last).title}';
  }

  String _describe(Json data) {
    if (data.containsKey('object_path')) return data['object_path'] == null ? '移除照片' : '保留照片';
    const labels = {'amount': '數量', 'answers': '心得', 'display_name': '名字', 'avatar': '頭像',
      'starts_on': '開跑日', 'nourish_choice': 'Nourish 選擇', 'weight_kg': '體重',
      'bedtime': '就寢分鐘', 'wake_time': '起床分鐘', 'book': '閱讀書籍',
      'week1_move': '本週運動', 'week1_obstacle': '可能的阻礙'};
    return data.entries.where((e) => labels.containsKey(e.key))
      .map((e) => '${labels[e.key]}：${e.value is List ? (e.value as List).join('／') : e.value ?? '未填'}').join('、');
  }
}
