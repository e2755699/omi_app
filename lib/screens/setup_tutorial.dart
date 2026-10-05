import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/challenge.dart';
import '../models/profile.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/guide_bubble.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/player_card.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';
import 'title_screen.dart';

const _avatars = ['😀', '😎', '🦊', '🐻', '🐱', '🐼', '🦁', '🐸', '🐧', '🦄', '🐯', '🐶'];

const _pillarIntro = {
  Pillar.move: '每週有氧 150 分鐘＋肌力 2 次',
  Pillar.nourish: '0 酒精＋飲食習慣 3 選 2',
  Pillar.learn: '每天閱讀 20 分鐘',
  Pillar.recover: '睡足 8 小時、作息固定',
  Pillar.reflect: '每天記錄，每週回顧',
};

/// [_Step.intro] 是 STEP 0 的標題畫面（介紹 Omi），後面才是 STEP 1–8。
enum _Step { intro, welcome, player, move, nourish, learn, recover, reflect, ready }

/// 設定教學：嚮導一步一步介紹規則，邊介紹邊完成個人設定，最後產生自己的儀表板。
/// 第一次打開 App 會看到；之後可以從首頁右上角「重新設定」再走一次。
class SetupTutorial extends StatefulWidget {
  const SetupTutorial({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<SetupTutorial> createState() => _SetupTutorialState();
}

class _SetupTutorialState extends State<SetupTutorial> {
  late final Profile _initial = widget.store.profile;
  // 已經設定過（從首頁「重新設定」進來）就跳過標題畫面。
  late var _step = widget.store.isSetUp ? _Step.welcome : _Step.intro;
  late final _name = TextEditingController(text: widget.store.isSetUp ? _initial.name : '');
  late final _weight = TextEditingController(text: _formatWeight(_initial.weightKg));
  late String _avatar = _initial.avatar;
  late Set<String> _nourish = {..._initial.nourishChoice};
  late int _bedtime = _initial.bedtime ?? 23 * 60;
  late int _wakeTime = _initial.wakeTime ?? 7 * 60;
  bool _saving = false;

  ChallengeStore get _store => widget.store;
  Challenge get _challenge => _store.challenge;

  static String _formatWeight(double? kg) {
    if (kg == null) return '';
    return kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
  }

  bool get _needsWeight => _nourish.contains('protein') || _nourish.contains('water');

  double? get _weightKg {
    final kg = double.tryParse(_weight.text.trim());
    return kg != null && kg >= 20 && kg <= 300 ? kg : null;
  }

  Profile get _draft => Profile(
    name: _name.text.trim(),
    avatar: _avatar,
    weightKg: _weightKg,
    nourishChoice: _nourish,
    bedtime: _bedtime,
    wakeTime: _wakeTime,
  );

  bool get _canContinue => switch (_step) {
    _Step.player => _name.text.trim().isNotEmpty,
    _Step.nourish => _nourish.length == 2 && (!_needsWeight || _weightKg != null),
    _ => true,
  };

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _toggleNourish(String id) {
    setState(() {
      if (_nourish.contains(id)) {
        _nourish.remove(id);
      } else if (_nourish.length < 2) {
        _nourish.add(id);
      } else {
        // 已經選了兩項：換掉比較早選的那一項。
        _nourish = {_nourish.last, id};
      }
    });
  }

  Future<void> _pickTime({required bool bedtime}) async {
    final current = bedtime ? _bedtime : _wakeTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: bedtime ? '幾點上床睡覺？' : '幾點起床？',
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (bedtime) {
        _bedtime = minutes;
      } else {
        _wakeTime = minutes;
      }
    });
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step != _Step.ready) {
      setState(() => _step = _Step.values[_step.index + 1]);
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await _store.finishSetup(_draft);
    // 從首頁「重新設定」進來的要關掉；第一次使用時 App 會自己換到首頁。
    if (navigator.canPop()) navigator.pop();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.values[_step.index - 1]);
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.intro) {
      return TitleScreen(challenge: _challenge, onStart: () => setState(() => _step = _Step.welcome));
    }
    // 標題畫面是 STEP 0，不算在進度裡。
    final index = _step.index - 1;
    final total = _Step.values.length - 1;
    final canClose = Navigator.of(context).canPop();
    final wide = isWideLayout(context);
    final page = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, canClose ? 4 : 20, 6),
          child: Row(
            children: [
              PixelText('STEP ${index + 1}/$total', dot: 2),
              const SizedBox(width: 12),
              Expanded(
                child: PixelProgressBar(value: (index + 1) / total, color: PixelColors.yellow, segments: total),
              ),
              if (canClose)
                IconButton(tooltip: '關閉', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_step),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Row(
            children: [
              if (index > 0) ...[
                Expanded(
                  child: _NavKey(label: '上一步', onTap: _back),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: _NavKey(
                  label: _step == _Step.ready ? '進入我的儀表板' : '下一步',
                  primary: true,
                  onTap: _canContinue && !_saving ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1040 : 560),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 260, child: _StepSidebar(current: index)),
                      const SizedBox(width: 24),
                      Expanded(child: page),
                    ],
                  )
                : page,
          ),
        ),
      ),
    );
  }

  List<Widget> _content() => switch (_step) {
    _Step.intro => const [],
    _Step.welcome => _welcome(),
    _Step.player => _player(),
    _Step.move => _move(),
    _Step.nourish => _nourishStep(),
    _Step.learn => _learn(),
    _Step.recover => _recover(),
    _Step.reflect => _reflect(),
    _Step.ready => _ready(),
  };

  List<Widget> _welcome() => [
    GuideBubble(
      text:
          '嗨！我是你的嚮導 🧭\n接下來 ${_challenge.totalDays} 天'
          '（${formatShortDate(_challenge.start)} → ${formatShortDate(_challenge.end)}），'
          '我們要一起練習 5 種好習慣。我帶你一步一步設定好你的挑戰儀表板！',
    ),
    const SizedBox(height: 28),
    Center(child: PixelText('${_challenge.totalDays} DAYS', dot: 6)),
    const SizedBox(height: 28),
    for (final pillar in Pillar.values)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PixelBox(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Text(pillar.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: Align(alignment: Alignment.centerLeft, child: PixelTag(pillar.tag)),
              ),
              Expanded(
                child: Text(_pillarIntro[pillar]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 12),
    _TipBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每一項挑戰都有一條能量槽 ⚡', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          PixelCellsBar(cells: const [true, true, true, true, false, false, false], color: pillarColor(Pillar.move)),
          const SizedBox(height: 6),
          const Text('做到就充電，一週充滿就是 100%', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
        ],
      ),
    ),
  ];

  List<Widget> _player() => [
    const GuideBubble(text: '先建立你的角色！隊友會在「大家的進度」看到你的名字和頭像，還可以幫你集氣加油 📣'),
    const SizedBox(height: 24),
    TextField(
      controller: _name,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: '你的名字（暱稱也可以）'),
    ),
    const SizedBox(height: 20),
    const Text('選一個頭像', style: TextStyle(fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final avatar in _avatars)
          GestureDetector(
            onTap: () => setState(() => _avatar = avatar),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatar == _avatar ? PixelColors.yellow : PixelColors.paper,
                border: Border.all(color: PixelColors.ink, width: avatar == _avatar ? 4 : 2),
              ),
              child: Text(avatar, style: const TextStyle(fontSize: 24)),
            ),
          ),
      ],
    ),
    const SizedBox(height: 28),
    Center(
      child: Column(
        children: [
          PlayerAvatar(profile: _draft, size: 72),
          const SizedBox(height: 8),
          Text(
            _name.text.trim().isEmpty ? '???' : _name.text.trim(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _move() {
    final aerobic = itemById('aerobic');
    final strength = itemById('strength');
    final firstWeekDays = _challenge.weekOf(_challenge.start).where(_challenge.contains).length;
    int firstWeek(ChallengeItem item) => (item.target * firstWeekDays / 7).ceil();
    return [
      const GuideBubble(text: 'MOVE 是「每週」的目標：週一到週日之間做完就好，哪一天做都可以。'),
      const SizedBox(height: 20),
      _RuleCard(item: aerobic),
      const SizedBox(height: 10),
      _RuleCard(item: strength),
      const SizedBox(height: 16),
      const _TipBox(text: '💡 例如：一、三、五各快走 50 分鐘，二、四做肌力訓練。每天打卡時按一下，能量槽就會一格一格充滿。'),
      const SizedBox(height: 10),
      _TipBox(
        text:
            '📅 第一週只有 $firstWeekDays 天（${formatShortDate(_challenge.start)} 開始），'
            '目標照比例調整：有氧 ${firstWeek(aerobic)} 分鐘、肌力 ${firstWeek(strength)} 次。',
      ),
    ];
  }

  List<Widget> _nourishStep() {
    final locked = _store.nourishLocked;
    return [
      GuideBubble(
        text: locked ? '挑戰已經開始了，你的 3 選 2 要維持原本的選擇喔！體重可以更新。' : 'NOURISH 分兩部分：「0 酒精」是每個人都要做的；另外三項請選兩項，而且整個挑戰都要維持同樣的選擇喔！',
      ),
      const SizedBox(height: 20),
      const Text('每個人都要做', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      _RuleCard(item: itemById('alcohol')),
      const SizedBox(height: 20),
      Row(
        children: [
          const Text('3 選 2', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          PixelText('${_nourish.length}/2', dot: 2),
          const Spacer(),
          if (locked) const Text('🔒 已鎖定', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
      const SizedBox(height: 10),
      for (final option in nourishOptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OptionKey(
            item: option,
            selected: _nourish.contains(option.id),
            onTap: locked ? null : () => _toggleNourish(option.id),
          ),
        ),
      if (_needsWeight) ...[
        const SizedBox(height: 8),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '你的體重', suffixText: 'kg', helperText: '用來算你每天要吃多少蛋白質、喝多少水'),
        ),
        if (_weightKg != null) ...[
          const SizedBox(height: 12),
          _TipBox(
            text: [
              for (final id in ['protein', 'water'])
                if (_nourish.contains(id)) '🎯 ${itemTarget(itemById(id), _draft)}',
            ].join('\n'),
          ),
        ],
      ],
    ];
  }

  List<Widget> _learn() => [
    const GuideBubble(text: 'LEARN 很簡單：每天至少 20 分鐘閱讀，聽有聲書也算！'),
    const SizedBox(height: 20),
    _RuleCard(item: itemById('reading')),
    const SizedBox(height: 16),
    const _TipBox(text: '💡 把書放在床頭，睡前讀 20 分鐘，還能順便幫助放鬆入睡。'),
  ];

  List<Widget> _recover() {
    final window = _draft.sleepWindow!;
    final enough = window >= 8 * 60;
    return [
      const GuideBubble(text: 'RECOVER 是好好睡覺：每天為睡眠留 8 小時，而且固定時間睡、固定時間起（每天差距在 ±60 分鐘內）。先設定你的作息吧！'),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _TimeKey(label: '🌙 上床睡覺', minutes: _bedtime, onTap: () => _pickTime(bedtime: true)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TimeKey(label: '☀️ 起床', minutes: _wakeTime, onTap: () => _pickTime(bedtime: false)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (enough ? PixelColors.green : PixelColors.orange).withValues(alpha: 0.18),
          border: Border.all(color: enough ? PixelColors.green : PixelColors.orange, width: 2),
        ),
        child: Text(
          enough ? '✓ 睡眠機會 ${formatHours(window)} 小時，符合 8 小時的規則' : '⚠ 只有 ${formatHours(window)} 小時，規則是至少 8 小時喔',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 16),
      _RuleCard(item: itemById('sleep'), target: itemTarget(itemById('sleep'), _draft)),
      const SizedBox(height: 10),
      _RuleCard(item: itemById('schedule'), target: itemTarget(itemById('schedule'), _draft)),
    ];
  }

  List<Widget> _reflect() => [
    const GuideBubble(text: '最後是 REFLECT。每天按首頁的「每日打卡」，把今天做到的項目一顆一顆按下去，再寫下一件「今天我注意到的事」。'),
    const SizedBox(height: 20),
    PixelBox(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PixelTag('DAY 1'),
              const SizedBox(width: 8),
              Text(formatDate(_challenge.start), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _MockKey(emoji: '🏃', title: '有氧', on: true, color: Color(0xFFF29F05)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MockKey(emoji: '📖', title: '閱讀', on: true, color: Color(0xFF3A86FF)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MockKey(emoji: '🛏️', title: '睡眠', on: false, color: Color(0xFF8B5CF6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: PixelColors.ink, width: 2),
            ),
            child: const Text(
              '✏️ 今天我注意到的事：\n午餐後散步，下午比較有精神',
              style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const _TipBox(text: '📆 每週末再花 10 分鐘：\n・回答 3 個回顧問題\n・排好下週計畫（尤其是 Move）\n・留下一張代表這週的照片'),
  ];

  List<Widget> _ready() {
    final draft = _draft;
    final items = activeItems(draft);
    final chosen = [for (final id in draft.nourishChoice) itemById(id).title];
    return [
      GuideBubble(
        text: _store.phase == ChallengePhase.notStarted
            ? '設定完成！這是你的專屬儀表板，每一項挑戰都有自己的能量槽。${formatShortDate(_challenge.start)} 開跑，一起加油！'
            : '設定完成！這是你的專屬儀表板，每一項挑戰都有自己的能量槽。現在就去打卡吧！',
      ),
      const SizedBox(height: 20),
      PixelBox(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PlayerAvatar(profile: draft, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'Nourish：0 酒精、${chosen.join('、')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                  ),
                  Text(
                    '作息：${formatClock(draft.bedtime!)} 睡、${formatClock(draft.wakeTime!)} 起',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SectionTitle(tag: 'ENERGY', title: '你的 ${items.length} 項挑戰'),
      const SizedBox(height: 10),
      PixelBox(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(width: 6, height: 22, color: pillarColor(item.pillar)),
                    const SizedBox(width: 8),
                    Text(item.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itemTarget(item, draft),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PixelColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

const _stepLabels = ['歡迎', '建立角色', 'MOVE 運動', 'NOURISH 營養', 'LEARN 學習', 'RECOVER 恢復', 'REFLECT 反思', '完成！'];

/// 寬螢幕左邊的步驟清單：做完的打勾、現在這步加粗框。
class _StepSidebar extends StatelessWidget {
  const _StepSidebar({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 24),
      child: PixelBox(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PixelText('OMI', dot: 4),
            const SizedBox(height: 6),
            const Text(
              '設定你的挑戰',
              style: TextStyle(fontWeight: FontWeight.w800, color: PixelColors.muted),
            ),
            const SizedBox(height: 18),
            for (final (i, label) in _stepLabels.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < current
                            ? PixelColors.yellow
                            : i == current
                            ? PixelColors.paper
                            : PixelColors.sand,
                        border: Border.all(
                          color: i <= current ? PixelColors.ink : PixelColors.muted.withValues(alpha: 0.4),
                          width: i == current ? 3 : 2,
                        ),
                      ),
                      child: i < current ? const PixelText('✓', dot: 2) : PixelText('${i + 1}', dot: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == current ? FontWeight.w900 : FontWeight.w700,
                          color: i <= current ? PixelColors.ink : PixelColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavKey extends StatelessWidget {
  const _NavKey({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Keycap(
        onTap: onTap,
        faceColor: primary ? PixelColors.yellow : const Color(0xFFFFFBF0),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: onTap == null ? PixelColors.muted : PixelColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.item, this.target});

  final ChallengeItem item;
  final String? target;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 6, height: 44, color: pillarColor(item.pillar)),
          const SizedBox(width: 10),
          Text(item.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  item.rule,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: PixelColors.muted,
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(height: 6),
                  Text('🎯 $target', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nourish 3 選 2 的選項，用鍵帽：選了就按下去亮起來。
class _OptionKey extends StatelessWidget {
  const _OptionKey({required this.item, required this.selected, required this.onTap});

  final ChallengeItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Keycap(
        on: selected,
        color: PixelColors.yellow,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(
                      item.rule,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PixelColors.muted),
                    ),
                  ],
                ),
              ),
              if (selected) const PixelText('✓', dot: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeKey extends StatelessWidget {
  const _TimeKey({required this.label, required this.minutes, required this.onTap});

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Keycap(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            PixelText(formatClock(minutes), dot: 3),
          ],
        ),
      ),
    );
  }
}

class _MockKey extends StatelessWidget {
  const _MockKey({required this.emoji, required this.title, required this.on, required this.color});

  final String emoji;
  final String title;
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Keycap(
        on: on,
        color: color,
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w900, color: on ? onColor(color) : PixelColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({this.text, this.child});

  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PixelColors.sand.withValues(alpha: 0.6),
        border: Border.all(color: PixelColors.ink.withValues(alpha: 0.2), width: 2),
      ),
      child: child ?? Text(text!, style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w700)),
    );
  }
}
