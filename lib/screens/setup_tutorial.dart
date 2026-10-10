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
import 'account_screen.dart';

const _avatars = ['😀', '😎', '🦊', '🐻', '🐱', '🐼', '🦁', '🐸', '🐧', '🦄', '🐯', '🐶'];

const _pillarIntro = {
  Pillar.move: '每週有氧 150 分鐘＋肌力 2 次',
  Pillar.nourish: '0 酒精＋飲食習慣三選至少二',
  Pillar.learn: '每天閱讀 20 分鐘',
  Pillar.recover: '睡足 8 小時、作息固定',
  Pillar.reflect: '每天記錄，每週回顧',
};

/// Jimmy 給的每日心得例子：教學裡可以點一下直接填進去。
const _noticedExamples = ['今天忘記閱讀', '太忙了沒有跑步', '感冒所以喝很多水', '早上運動比較簡單'];

/// [_Step.intro] 是 STEP 0 的標題畫面，最後一步可登入找夥伴，或先自己走。
enum _Step { intro, welcome, player, start, move, nourish, learn, recover, reflect, plan, ready, account }

/// 設定教學：嚮導一步一步介紹規則，邊介紹邊完成個人設定，最後產生自己的儀表板。
/// 步驟照 Mindy 的「Omi Challenge Setup」表：決定加入 → 設定 → Week 1 計畫。
/// 第一次打開 App 會看到；之後可以從首頁右上角「重新設定」再走一次。
class SetupTutorial extends StatefulWidget {
  const SetupTutorial({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<SetupTutorial> createState() => _SetupTutorialState();
}

class _SetupTutorialState extends State<SetupTutorial> {
  late final String _scope;
  @override
  void initState() {
    super.initState();
    _scope = widget.store.dataScope;
  }
  late final Profile _initial = widget.store.profile;
  // 已經設定過（從首頁「重新設定」進來）就跳過標題畫面。
  late var _step = widget.store.pendingAccountStep
      ? _Step.account
      : widget.store.isSetUp
      ? _Step.welcome
      : _Step.intro;
  late final _name = TextEditingController(
    text: widget.store.isSetUp || widget.store.pendingAccountStep ? _initial.name : '',
  );
  late final _weight = TextEditingController(text: _formatWeight(_initial.weightKg));
  late final _book = TextEditingController(text: _initial.book);
  late final _week1Move = TextEditingController(text: _initial.week1Move);
  late final _week1Obstacle = TextEditingController(text: _initial.week1Obstacle);
  late final _noticed = TextEditingController(text: widget.store.setupNoticedDraft);
  late String _avatar = _initial.avatar;
  late DateTime _startDate = _initial.startDate ?? _store.today;
  late final Set<String> _nourish = {..._initial.nourishChoice};
  late int _bedtime = _initial.bedtime ?? 23 * 60;
  late int _wakeTime = _initial.wakeTime ?? 7 * 60;
  bool _saving = false;

  ChallengeStore get _store => widget.store;

  /// 照現在選的開跑日算出來的挑戰。
  Challenge get _challenge => challengeStarting(_startDate);

  static String _formatWeight(double? kg) {
    if (kg == null) return '';
    return kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
  }

  double? get _weightKg {
    final kg = double.tryParse(_weight.text.trim());
    return kg != null && kg >= 20 && kg <= 300 ? kg : null;
  }

  /// 選了蛋白質或飲水就需要體重，才算得出目標。
  bool get _needsWeight => _nourish.contains('protein') || _nourish.contains('water');

  Profile get _draft => Profile(
    name: _name.text.trim(),
    avatar: _avatar,
    startDate: _startDate,
    weightKg: _weightKg,
    nourishChoice: _nourish,
    bedtime: _bedtime,
    wakeTime: _wakeTime,
    book: _book.text,
    week1Move: _week1Move.text,
    week1Obstacle: _week1Obstacle.text,
  );

  bool get _canContinue => switch (_step) {
    _Step.player => _name.text.trim().isNotEmpty,
    _Step.nourish => _nourish.length >= 2 && (!_needsWeight || _weightKg != null),
    _ => true,
  };

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _book.dispose();
    _week1Move.dispose();
    _week1Obstacle.dispose();
    _noticed.dispose();
    super.dispose();
  }

  void _toggleNourish(String id) {
    setState(() {
      if (!_nourish.remove(id)) _nourish.add(id);
    });
  }

  Future<void> _pickTime({required bool bedtime}) async {
    final current = bedtime ? _bedtime : _wakeTime;
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (_) => _PixelTimeSheet(title: bedtime ? '🌙 幾點上床睡覺？' : '☀️ 幾點起床？', minutes: current),
    );
    if (picked == null) return;
    setState(() {
      if (bedtime) {
        _bedtime = picked;
      } else {
        _wakeTime = picked;
      }
    });
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step != _Step.account) {
      setState(() => _step = _Step.values[_step.index + 1]);
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final noticed = _noticed.text.trim();
    try {
      if (_scope != _store.dataScope) throw StateError('帳號或群組已切換');
      await _store.finishSetup(_draft);
      // 教學裡寫的那句心得，開跑日是今天的話就直接算今天的紀錄。
      if (_scope == _store.dataScope && noticed.isNotEmpty && _store.canLogOn(_store.today)) {
        await _store.saveNotes(itemById('noticed'), _store.today, [noticed]);
      }
      // 從首頁「重新設定」進來的要關掉；第一次使用時 App 會自己換到首頁。
      if (navigator.canPop()) navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('設定還沒存好，請再試一次。')));
    }
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
                  child: KeycapButton(label: '上一步', onTap: _back),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ListenableBuilder(
                  listenable: _store.account,
                  builder: (context, _) => KeycapButton(
                    label: switch (_step) {
                      _Step.account when _store.isCloud => '儲存群組設定',
                      _Step.account when _store.account.isSignedIn => '出發吧！',
                      _Step.account => '我先自己走',
                      _ => '下一步',
                    },
                    primary: true,
                    onTap: _canContinue && !_saving ? _next : null,
                  ),
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
    _Step.start => _start(),
    _Step.move => _move(),
    _Step.nourish => _nourishStep(),
    _Step.learn => _learn(),
    _Step.recover => _recover(),
    _Step.reflect => _reflect(),
    _Step.plan => _plan(),
    _Step.ready => _ready(),
    _Step.account => [
      AccountPanel(account: _store.account, beforeSignIn: () => _store.saveSetupDraft(_draft, _noticed.text)),
    ],
  };

  List<Widget> _welcome() => [
    GuideBubble(
      text:
          '嗨！我是你的嚮導 🧭\n接下來到 ${formatShortDate(challengeEnd)} 為止'
          '（從今天開始算是 ${_challenge.totalDays} 天），'
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

  /// DAY 1 – DECIDE：決定加入，選開跑日。
  List<Widget> _start() {
    final today = _store.today;
    final monday = nextMonday(today);
    final locked = _store.startLocked;
    Widget option(DateTime date, String title, String subtitle) {
      final challenge = challengeStarting(date);
      final selected = _startDate == date;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 86,
          child: Keycap(
            on: selected,
            color: PixelColors.yellow,
            onTap: locked ? null : () => setState(() => _startDate = date),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        Text(
                          '$subtitle · 到 ${formatShortDate(challenge.end)} 共 ${challenge.totalDays} 天',
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
        ),
      );
    }

    return [
      GuideBubble(
        text: locked
            ? '你的挑戰已經從 ${formatDate(_startDate)} 開跑了，結束日是 ${formatShortDate(challengeEnd)}。'
            : '決定加入 The Omi Challenge！結束日大家都一樣是 ${formatShortDate(challengeEnd)}；'
                  '開跑日你自己選：今天就開始，或是從下週一開始，讓每一週都是完整的週一到週日。',
      ),
      const SizedBox(height: 20),
      option(today, '從今天開始', formatDate(today)),
      if (!monday.isAfter(challengeEnd)) option(monday, '從下週一開始', formatDate(monday)),
      const SizedBox(height: 8),
      const _TipBox(text: '📣 別忘了也到 Discord 留言「我要參加」，讓大家知道你加入了！'),
    ];
  }

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
      const Text('打卡就是按鍵帽，先試按看看 👇', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Row(
        children: [
          Expanded(
            child: _MockKey(emoji: '🏃', title: '有氧', color: Color(0xFFF29F05)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _MockKey(emoji: '🏋️', title: '肌力', color: Color(0xFFF29F05)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _MockKey(emoji: '📖', title: '閱讀', color: Color(0xFF3A86FF)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const _TipBox(text: '💡 例如：一、三、五各快走 50 分鐘，二、四做肌力訓練。每天打卡時按一下，能量槽就會一格一格充滿。'),
      if (firstWeekDays < 7) ...[
        const SizedBox(height: 10),
        _TipBox(
          text:
              '📅 第一週只有 $firstWeekDays 天（${formatShortDate(_challenge.start)} 開始），'
              '目標照比例調整：有氧 ${firstWeek(aerobic)} 分鐘、肌力 ${firstWeek(strength)} 次。',
        ),
      ],
    ];
  }

  List<Widget> _nourishStep() {
    return [
      const GuideBubble(text: 'NOURISH 分兩部分：「0 酒精」是每個人都要做的；另外三項請至少選兩項（三項全選也可以），而且整個挑戰都要維持同樣的選擇喔！'),
      const SizedBox(height: 20),
      const Text('每個人都要做', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      _RuleCard(item: itemById('alcohol')),
      const SizedBox(height: 20),
      Row(
        children: [
          const Text('三選至少二', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          PixelText('${_nourish.length}/3', dot: 2),
        ],
      ),
      const SizedBox(height: 10),
      for (final option in nourishOptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OptionKey(
            item: option,
            selected: _nourish.contains(option.id),
            onTap: () => _toggleNourish(option.id),
          ),
        ),
      const SizedBox(height: 8),
      TextField(
        controller: _weight,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: '你的體重', suffixText: 'kg', helperText: '用來算你每天要吃多少蛋白質、喝多少水，之後可以改'),
      ),
      const SizedBox(height: 12),
      _TipBox(
        text: _weightKg == null
            ? '💡 蛋白質和飲水的目標是「每公斤體重」算的：例如 60 kg，蛋白質一天 72 g、白開水一天 1800 ml。填體重就幫你算好。'
            : [
                for (final id in ['protein', 'water'])
                  '${_nourish.contains(id) ? '🎯' : '　'} ${itemTarget(itemById(id), _draft)}'
                      '${_nourish.contains(id) ? '' : '（沒選）'}',
              ].join('\n'),
      ),
    ];
  }

  List<Widget> _learn() => [
    const GuideBubble(text: 'LEARN 很簡單：每天至少 20 分鐘閱讀，聽有聲書也算！先決定要讀哪一本吧。'),
    const SizedBox(height: 20),
    _RuleCard(item: itemById('reading')),
    const SizedBox(height: 16),
    TextField(
      controller: _book,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: '我要讀的書（之後可以換）', hintText: '例如：薛西弗斯的神話'),
    ),
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

  /// REFLECT：照 Jimmy 的定義，每天一句心得、每週三題。教學裡先練習寫一句。
  List<Widget> _reflect() {
    final review = itemById('review');
    return [
      const GuideBubble(text: 'REFLECT 分每日和每週。每天打完卡寫一句就好，沒做到的也寫；每週日回答三個問題。先練習寫一句！'),
      const SizedBox(height: 20),
      const SectionTitle(tag: 'DAILY', title: '今天我注意到的事'),
      const SizedBox(height: 10),
      TextField(
        controller: _noticed,
        minLines: 2,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: '一句話就好，例如：午餐後散步，下午比較有精神'),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final example in _noticedExamples)
            _ExampleChip(
              text: example,
              selected: _noticed.text.trim() == example,
              onTap: () => setState(() => _noticed.text = example),
            ),
        ],
      ),
      const SizedBox(height: 22),
      SectionTitle(tag: 'WEEKLY', title: '每週回顧 ${review.emoji}'),
      const SizedBox(height: 6),
      const Text('每週日花 10 分鐘回答三題，第三題就是下週的計畫。只有自己看得到。', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
      const SizedBox(height: 10),
      PixelBox(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, prompt) in review.prompts.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${i + 1}. $prompt', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    ];
  }

  /// MY WEEK 1 PLAN（Mindy 的 Setup 表）＋每週照片的介紹。
  List<Widget> _plan() => [
    const GuideBubble(text: '開跑前先排好第一週：Move 打算怎麼做？最可能卡住你的是什麼？先想好，開始之後就不用每天重新決定。'),
    const SizedBox(height: 20),
    const SectionTitle(tag: 'WEEK 1', title: '我的第一週計畫'),
    const SizedBox(height: 12),
    TextField(
      controller: _week1Move,
      minLines: 2,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: '本週要做哪些有氧＆肌力項目',
        hintText: '例如：一三五晨跑 40 分鐘、二四做肌力',
        alignLabelWithHint: true,
      ),
    ),
    const SizedBox(height: 14),
    TextField(
      controller: _week1Obstacle,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: '這週最可能遇到的阻礙',
        hintText: '例如：週三要加班，可能沒時間讀書',
        alignLabelWithHint: true,
      ),
    ),
    const SizedBox(height: 22),
    const SectionTitle(tag: 'PHOTO', title: '📷 每週一張照片'),
    const SizedBox(height: 6),
    const Text(
      '每週在「本週任務」留一張代表這週生活的照片，不用證明什麼：常去的地方、一頓飯、床邊的書都可以。走完挑戰，照片牆就是這幾週的縮影。',
      style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600, color: PixelColors.muted),
    ),
    const SizedBox(height: 12),
    const _PhotoPreview(),
  ];

  List<Widget> _ready() {
    final draft = _draft;
    final items = activeItems(draft);
    final chosen = [for (final id in draft.nourishChoice) itemById(id).title];
    final challenge = _challenge;
    final notStarted = challenge.phaseOn(_store.today) == ChallengePhase.notStarted;
    return [
      GuideBubble(
        text: notStarted
            ? '設定完成！這是你的專屬儀表板，每一項挑戰都有自己的能量槽。${formatShortDate(challenge.start)} 開跑，一起加油！'
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
                  _summaryLine(
                    '開跑：${formatDate(challenge.start)} → ${formatShortDate(challenge.end)}，${challenge.totalDays} 天',
                  ),
                  _summaryLine('Nourish：0 酒精、${chosen.join('、')}'),
                  _summaryLine('作息：${formatClock(draft.bedtime!)} 睡、${formatClock(draft.wakeTime!)} 起'),
                  if (draft.book.trim().isNotEmpty) _summaryLine('讀：${draft.book.trim()}'),
                  if (draft.week1Move.trim().isNotEmpty) _summaryLine('Week 1：${draft.week1Move.trim()}'),
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

  Widget _summaryLine(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
  );
}

const _stepLabels = [
  '歡迎',
  '建立角色',
  '決定加入',
  'MOVE 運動',
  'NOURISH 營養',
  'LEARN 學習',
  'RECOVER 恢復',
  'REFLECT 反思',
  'WEEK 1 計畫',
  '完成！',
  '找夥伴，或先自己走',
];

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

/// Nourish 三選至少二的選項，用鍵帽：選了就按下去亮起來。
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

/// 像素風的時間選擇：用鍵帽加減小時和分鐘，不是鬧鐘。
class _PixelTimeSheet extends StatefulWidget {
  const _PixelTimeSheet({required this.title, required this.minutes});

  final String title;
  final int minutes;

  @override
  State<_PixelTimeSheet> createState() => _PixelTimeSheetState();
}

class _PixelTimeSheetState extends State<_PixelTimeSheet> {
  late int _minutes = widget.minutes;

  void _add(int delta) => setState(() => _minutes = (_minutes + delta + 24 * 60) % (24 * 60));

  Widget _key(String label, VoidCallback onTap) => SizedBox(
    width: 64,
    height: 56,
    child: Keycap(
      onTap: onTap,
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Center(child: PixelText(formatClock(_minutes), dot: 7)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _key('−1 時', () => _add(-60)),
              const SizedBox(width: 8),
              _key('+1 時', () => _add(60)),
              const SizedBox(width: 20),
              _key('−15 分', () => _add(-15)),
              const SizedBox(width: 8),
              _key('+15 分', () => _add(15)),
            ],
          ),
          const SizedBox(height: 20),
          KeycapButton(primary: true, label: '好了', onTap: () => Navigator.of(context).pop(_minutes)),
        ],
      ),
    );
  }
}

/// 教學裡的示範鍵帽：真的可以按，按一下亮、再按一下暗。
class _MockKey extends StatefulWidget {
  const _MockKey({required this.emoji, required this.title, required this.color});

  final String emoji;
  final String title;
  final Color color;

  @override
  State<_MockKey> createState() => _MockKeyState();
}

class _MockKeyState extends State<_MockKey> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Keycap(
        on: _on,
        color: widget.color,
        onTap: () => setState(() => _on = !_on),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 20)),
            Text(
              '${_on ? '✓' : ''}${widget.title}',
              style: TextStyle(fontWeight: FontWeight.w900, color: _on ? onColor(widget.color) : PixelColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// 教學裡的照片示意：一個空的像素相框＋相簿／拍照兩顆鍵帽（按了只是示範）。
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: Container(
            decoration: const ShapeDecoration(color: PixelColors.sand, shape: PixelBorder()),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelText('WEEK 1', dot: 3, color: PixelColors.muted),
                  SizedBox(height: 6),
                  Text(
                    '這週的一張照片會放在這裡',
                    style: TextStyle(fontWeight: FontWeight.w800, color: PixelColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        KeycapButton(label: '📷 選照片', onTap: () {}),
      ],
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? PixelColors.yellow : PixelColors.paper,
          border: Border.all(color: PixelColors.ink, width: 2),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
