import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/challenge.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';
import '../widgets/week_strip.dart';

/// 每日打卡：一顆一顆鍵帽，按下去就是已打卡；下面寫 Reflect（今天我注意到的事），
/// 每週回顧、下週計畫、照片也在這裡。
class DailyRecordScreen extends StatefulWidget {
  const DailyRecordScreen({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<DailyRecordScreen> createState() => _DailyRecordScreenState();
}

class _DailyRecordScreenState extends State<DailyRecordScreen> {
  static final _noticed = itemById('noticed');
  static final _review = itemById('review');
  static final _plan = itemById('plan');
  static final _photo = itemById('photo');

  late DateTime _date = widget.store.today;
  final _noticedText = TextEditingController();
  final _reviewTexts = [for (var i = 0; i < _review.prompts.length; i++) TextEditingController()];
  final _planText = TextEditingController();
  late bool _weeklyOpen;

  ChallengeStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    // 週末或這週已經開始寫了，就直接展開每週回顧。
    _weeklyOpen = _date.weekday >= DateTime.saturday ||
        _store.entryOn(_review, _date).isDone ||
        _store.entryOn(_plan, _date).isDone;
  }

  @override
  void dispose() {
    _noticedText.dispose();
    for (final controller in _reviewTexts) {
      controller.dispose();
    }
    _planText.dispose();
    super.dispose();
  }

  void _loadNotes() {
    String note(ChallengeItem item, int i) {
      final notes = _store.entryOn(item, _date).notes;
      return i < notes.length ? notes[i] : '';
    }

    _noticedText.text = note(_noticed, 0);
    for (var i = 0; i < _reviewTexts.length; i++) {
      _reviewTexts[i].text = note(_review, i);
    }
    _planText.text = note(_plan, 0);
  }

  Future<void> _saveNotes() async {
    // 先把字讀出來：離開畫面時 controller 可能接著就被 dispose 了。
    final date = _date;
    final noticed = [_noticedText.text];
    final review = [for (final controller in _reviewTexts) controller.text];
    final plan = [_planText.text];
    await _store.saveNotes(_noticed, date, noticed);
    await _store.saveNotes(_review, date, review);
    await _store.saveNotes(_plan, date, plan);
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
      case ItemKind.daily || ItemKind.weekly:
        _store.toggle(item, _date);
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

          return Scaffold(
            appBar: AppBar(title: const Text('每日打卡', style: TextStyle(fontWeight: FontWeight.w900))),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Row(
                      children: [
                        PixelTag('DAY ${challenge.dayNumber(_date)}', dot: 3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            formatDate(_date),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
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
                    const Text(
                      '點上面的格子可以補登這週前幾天',
                      style: TextStyle(fontSize: 11, color: PixelColors.muted),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle(tag: 'CHECK-IN', title: '做到了就按下去'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 130,
                        mainAxisExtent: 128,
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
                    const SizedBox(height: 26),
                    const SectionTitle(tag: 'REFLECT', title: '今天我注意到的事'),
                    const SizedBox(height: 6),
                    const Text(
                      '每日微反思：記下一件今天注意到的事，一句話就好',
                      style: TextStyle(fontSize: 12, color: PixelColors.muted),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noticedText,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(hintText: '例如：午餐後散步，下午比較有精神'),
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _legend(ChallengeItem item) {
    if (item.kind == ItemKind.weeklyAmount) {
      final today = _store.entryOn(item, _date).amount;
      final progress = _store.progress(item);
      return today > 0 && item.quickAdds.isNotEmpty
          ? '今天 $today ${item.unit}'
          : '本週 ${progressText(item, progress)}';
    }
    return itemTarget(item, _store.profile);
  }

  Widget _weeklySection() {
    final weeklyDone = [_review, _plan, _photo].where((item) => _store.progress(item).doneNow).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelBox(
          onTap: () => setState(() => _weeklyOpen = !_weeklyOpen),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const PixelTag('WEEKLY'),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('每週回顧・計畫・照片', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              PixelText('$weeklyDone/3', dot: 2),
              Icon(_weeklyOpen ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (_weeklyOpen) ...[
          const SizedBox(height: 10),
          const Text('建議週末寫，一週寫一次就好', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
          const SizedBox(height: 12),
          Text('${_review.emoji} ${_review.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          for (var i = 0; i < _review.prompts.length; i++) ...[
            const SizedBox(height: 10),
            Text('${i + 1}. ${_review.prompts[i]}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: _reviewTexts[i], minLines: 2, maxLines: 4),
          ],
          const SizedBox(height: 18),
          Text('${_plan.emoji} ${_plan.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(_plan.prompts.first, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: _planText,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: '例如：一三五晨跑 40 分鐘、二四做肌力'),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 130,
              height: 128,
              child: _ItemKey(
                item: _photo,
                on: _store.entryOn(_photo, _date).isDone,
                legend: '這週留下照片了',
                onTap: () => _tapKey(_photo),
              ),
            ),
          ),
        ],
      ],
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
