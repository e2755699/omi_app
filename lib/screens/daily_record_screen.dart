import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/challenge.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';
import '../widgets/week_strip.dart';
import 'weekly_screen.dart';

/// 每日打卡：一顆一顆鍵帽，按下去就是已打卡；下面寫 Reflect（今天我注意到的事）。
/// 每週回顧和照片在「本週任務」（WeeklyScreen）。
class DailyRecordScreen extends StatefulWidget {
  const DailyRecordScreen({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<DailyRecordScreen> createState() => _DailyRecordScreenState();
}

class _DailyRecordScreenState extends State<DailyRecordScreen> {
  static final _noticed = itemById('noticed');
  static final _review = itemById('review');
  static final _photo = itemById('photo');

  late DateTime _date = widget.store.today;
  final _noticedText = TextEditingController();
  late final String _scope;

  ChallengeStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _scope = _store.dataScope;
    _loadNotes();
  }

  @override
  void dispose() {
    _noticedText.dispose();
    super.dispose();
  }

  void _loadNotes() {
    final notes = _store.entryOn(_noticed, _date).notes;
    _noticedText.text = notes.isNotEmpty ? notes.first : '';
  }

  Future<void> _saveNotes() async {
    if (_scope != _store.dataScope) return;
    // 先把字讀出來：離開畫面時 controller 可能接著就被 dispose 了。
    final date = _date;
    final noticed = [_noticedText.text];
    await _store.saveNotes(_noticed, date, noticed);
  }

  Future<void> _selectDay(DateTime date) async {
    await _saveNotes();
    if (!mounted) return;
    setState(() {
      _date = date;
      _loadNotes();
    });
  }

  Future<void> _finish() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final date = _date;
    await _saveNotes();
    navigator.pop();
    final summary = _store.summary;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          date == _store.today
              ? '打卡完成！今天 ${summary.dailyDone}/${summary.dailyTotal} 項 ⚡'
              : '已補登 ${formatDate(date)} 的紀錄',
        ),
      ),
    );
  }

  void _tapKey(ChallengeItem item) {
    switch (item.kind) {
      case ItemKind.weeklyAmount when item.quickAdds.isNotEmpty:
        _editAmount(item);
      case ItemKind.weeklyAmount:
        // 肌力：按一下就是今天做了一次，再按一下取消。
        _store.setAmount(item, _date, _store.entryOn(item, _date).isDone ? 0 : item.step);
      case ItemKind.daily:
        _store.toggle(item, _date);
      case ItemKind.weekly:
        break;
    }
  }

  Future<void> _editAmount(ChallengeItem item) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => _AmountSheet(store: _store, item: item, date: _date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveNotes();
      },
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final challenge = _store.challenge;
          final keys = [
            for (final item in _store.items)
              if (item.pillar != Pillar.reflect) item,
          ];
          final done = keys.where((item) => _store.entryOn(item, _date).isDone).length;

          final checkIn = [
            Row(
              children: [
                PixelTag('DAY ${challenge.dayNumber(_date)}', dot: 3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(formatDate(_date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                PixelText('$done/${keys.length}', dot: 3),
              ],
            ),
            const SizedBox(height: 14),
            WeekStrip(
              color: PixelColors.yellow,
              days: [
                for (final day in challenge.weekOf(_date))
                  WeekStripDay(
                    date: day,
                    inChallenge: challenge.contains(day),
                    filled: !day.isAfter(_store.today) && _store.dayComplete(day),
                    highlighted: day == _date,
                    onTap: _store.canLogOn(day) && day != _date ? () => _selectDay(day) : null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('點上面的格子可以補登這週前幾天', style: TextStyle(fontSize: 11, color: PixelColors.muted)),
            const SizedBox(height: 20),
            const SectionTitle(tag: 'CHECK-IN', title: '做到了就按下去'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 136,
                mainAxisExtent: 134,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: keys.length,
              itemBuilder: (context, i) => _ItemKey(
                item: keys[i],
                on: _store.entryOn(keys[i], _date).isDone,
                legend: _legend(keys[i]),
                onTap: () => _tapKey(keys[i]),
              ),
            ),
          ];
          final reflect = [
            const SectionTitle(tag: 'REFLECT', title: '今天我注意到的事'),
            const SizedBox(height: 6),
            const Text('每日微反思：記下一件今天注意到的事或心得，一句話就好；沒做到的也寫在這裡', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: _noticedText,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '例如：今天忘記閱讀、太忙了沒有跑步、感冒所以喝很多水、早上運動比較簡單'),
            ),
            const SizedBox(height: 8),
            // 照今天的打卡狀況給幾句現成的：沒按的先給「沒做到」的寫法，按了的給心得的寫法。點一下填進去。
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _noteSuggestions(keys))
                  _SuggestionChip(text: suggestion, onTap: () => _appendNote(suggestion)),
              ],
            ),
            const SizedBox(height: 22),
            _weeklySection(),
            const SizedBox(height: 26),
            // 像空白鍵一樣的長鍵帽。
            SizedBox(
              height: 64,
              child: Keycap(
                onTap: _finish,
                faceColor: PixelColors.yellow,
                child: const Center(
                  child: Text('完成打卡 ✓', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ];

          const padding = EdgeInsets.fromLTRB(16, 16, 16, 32);
          return Scaffold(
            appBar: AppBar(
              title: const Text('每日打卡', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            body: Center(
              child: isWideLayout(context)
                  // 寬螢幕：左邊鍵帽打卡，右邊寫 Reflect。
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView(padding: padding, children: checkIn),
                          ),
                          Expanded(
                            child: ListView(padding: padding, children: reflect),
                          ),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(padding: padding, children: [...checkIn, const SizedBox(height: 26), ...reflect]),
                    ),
            ),
          );
        },
      ),
    );
  }

  /// 每個項目「沒做到」和「做到了」的現成句子（Jimmy 給的例子加上同一種口吻）。
  static const _missPhrases = {
    'aerobic': '太忙了沒有運動',
    'strength': '今天沒練肌力',
    'alcohol': '今天喝了一杯',
    'produce': '蔬果沒吃夠',
    'protein': '蛋白質沒吃夠',
    'water': '水喝太少了',
    'reading': '今天忘記閱讀',
    'sleep': '睡不到 8 小時',
    'schedule': '今天晚睡了',
  };
  static const _donePhrases = {
    'aerobic': '早上運動比較簡單',
    'strength': '肌力練完很有感',
    'alcohol': '聚餐也撐住沒喝',
    'produce': '今天蔬菜吃得比平常多',
    'protein': '蛋白質有吃夠',
    'water': '多喝水之後比較不想吃零食',
    'reading': '睡前讀 20 分鐘比較好睡',
    'sleep': '睡飽精神好',
    'schedule': '準時上床了',
  };

  /// 今天的建議句：沒按的項目先給「沒做到」的句子，再補兩句做到的，最多 6 句。
  List<String> _noteSuggestions(List<ChallengeItem> keys) {
    final misses = [
      for (final item in keys)
        if (!_store.entryOn(item, _date).isDone && _missPhrases[item.id] != null) _missPhrases[item.id]!,
    ];
    final dones = [
      for (final item in keys)
        if (_store.entryOn(item, _date).isDone && _donePhrases[item.id] != null) _donePhrases[item.id]!,
    ];
    final current = _noticedText.text;
    return [
      for (final phrase in [...misses.take(4), ...dones.take(6 - misses.take(4).length)])
        if (!current.contains(phrase)) phrase,
    ];
  }

  /// 把建議句填進去：空的就直接放，已經有字就接在後面。
  void _appendNote(String phrase) {
    final current = _noticedText.text.trim();
    setState(() => _noticedText.text = current.isEmpty ? phrase : '$current，$phrase');
  }

  String _legend(ChallengeItem item) {
    if (item.kind == ItemKind.weeklyAmount) {
      final today = _store.entryOn(item, _date).amount;
      final progress = _store.progress(item);
      return today > 0 && item.quickAdds.isNotEmpty ? '今天 $today ${item.unit}' : '本週 ${progressText(item, progress)}';
    }
    return itemTarget(item, _store.profile);
  }

  /// 每週回顧和照片在「本週任務」，這裡只放一個入口。
  Widget _weeklySection() {
    final answered = _store.progress(_review).value;
    final hasPhoto = _store.entryOn(_photo, _date).isDone;
    return PixelBox(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WeeklyScreen(store: _store, date: _date)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const PixelTag('WEEKLY'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('本週任務：回顧三題・一張照片', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  '回顧 $answered/${_review.prompts.length} 題 · 照片${hasPhoto ? '已留' : '還沒'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// 心得的建議句：點一下填進輸入框。
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: PixelColors.paper,
          border: Border.all(color: PixelColors.ink, width: 2),
        ),
        child: Text('＋ $text', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// 一個挑戰項目的鍵帽：圖示＋名稱＋小字說明，打卡後亮起來。
class _ItemKey extends StatelessWidget {
  const _ItemKey({required this.item, required this.on, required this.legend, required this.onTap});

  final ChallengeItem item;
  final bool on;
  final String legend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = pillarColor(item.pillar);
    final ink = on ? onColor(color) : PixelColors.ink;
    return Keycap(
      on: on,
      color: color,
      onTap: onTap,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    legend,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: on ? ink.withValues(alpha: 0.8) : PixelColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (on) Positioned(top: 4, right: 4, child: PixelText('✓', dot: 2, color: ink)),
        ],
      ),
    );
  }
}

/// 有氧分鐘數：用鍵帽加上去。
class _AmountSheet extends StatelessWidget {
  const _AmountSheet({required this.store, required this.item, required this.date});

  final ChallengeStore store;
  final ChallengeItem item;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final color = pillarColor(item.pillar);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final amount = store.entryOn(item, date).amount;
        Widget key(String label, VoidCallback? onTap, {bool on = false}) => SizedBox(
          width: 74,
          height: 66,
          child: Keycap(
            onTap: onTap,
            on: on,
            color: color,
            child: Center(
              child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${item.emoji} ${item.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${formatDate(date)} 做了幾分鐘？', style: const TextStyle(color: PixelColors.muted)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PixelText('$amount', dot: 7),
                  const SizedBox(width: 8),
                  Text(item.unit, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final add in [item.step, ...item.quickAdds])
                    key('+$add', () => store.setAmount(item, date, amount + add)),
                  key('-${item.step}', amount > 0 ? () => store.setAmount(item, date, amount - item.step) : null),
                  key('清除', amount > 0 ? () => store.setAmount(item, date, 0) : null),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: Keycap(
                  faceColor: PixelColors.yellow,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Center(
                    child: Text('好了', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
