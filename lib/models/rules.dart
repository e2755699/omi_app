import 'profile.dart';

/// 規則的五大類。
enum Pillar {
  move('MOVE', '運動', '🏃'),
  nourish('NOURISH', '營養', '🥗'),
  learn('LEARN', '學習', '📖'),
  recover('RECOVER', '恢復', '😴'),
  reflect('REFLECT', '反思', '✏️');

  const Pillar(this.tag, this.label, this.emoji);

  final String tag;
  final String label;
  final String emoji;
}

enum ItemKind {
  /// 每天做到就打勾（有 prompts 的要寫一句話）。
  daily,

  /// 每週累計數量，例如有氧分鐘數、肌力次數。
  weeklyAmount,

  /// 每週做一次，例如每週回顧（有 prompts 的要回答問題）。
  weekly,
}

class ChallengeItem {
  const ChallengeItem({
    required this.id,
    required this.pillar,
    required this.kind,
    required this.emoji,
    required this.title,
    required this.shortTitle,
    required this.rule,
    required this.goal,
    this.target = 1,
    this.unit = '',
    this.step = 1,
    this.quickAmount = 1,
    this.quickAdds = const [],
    this.prompts = const [],
    this.nourishOption = false,
  });

  final String id;
  final Pillar pillar;
  final ItemKind kind;
  final String emoji;
  final String title;

  /// 桌面小工具鍵帽上的短名字。
  final String shortTitle;

  /// 規則原文。
  final String rule;

  /// 卡片上的簡短目標。
  final String goal;

  /// [ItemKind.weeklyAmount] 的每週目標。
  final int target;
  final String unit;

  /// 每按一次 +／− 調整多少。
  final int step;

  /// 從桌面小工具按一下記多少（例如有氧一次記 30 分鐘）。
  final int quickAmount;

  /// 快速加上的常用數量。
  final List<int> quickAdds;

  /// 要寫字的項目：每一格的題目。
  final List<String> prompts;

  /// Nourish 3 選 2 的選項。
  final bool nourishOption;

  bool get needsWriting => prompts.isNotEmpty;
}

/// 「The Rules」投影片上的所有項目。
const challengeItems = <ChallengeItem>[
  ChallengeItem(
    id: 'aerobic',
    pillar: Pillar.move,
    kind: ItemKind.weeklyAmount,
    emoji: '🏃',
    title: '有氧運動',
    shortTitle: '有氧',
    rule: '每週完成至少 150 分鐘中等或高強度的有氧活動',
    goal: '每週 150 分鐘',
    target: 150,
    unit: '分鐘',
    step: 10,
    quickAmount: 30,
    quickAdds: [20, 30, 45, 60],
  ),
  ChallengeItem(
    id: 'strength',
    pillar: Pillar.move,
    kind: ItemKind.weeklyAmount,
    emoji: '🏋️',
    title: '肌力訓練',
    shortTitle: '肌力',
    rule: '每週完成至少 2 次肌力訓練',
    goal: '每週 2 次',
    target: 2,
    unit: '次',
  ),
  ChallengeItem(
    id: 'alcohol',
    pillar: Pillar.nourish,
    kind: ItemKind.daily,
    emoji: '🚫',
    title: '0 酒精',
    shortTitle: '0 酒精',
    rule: '全程不飲酒',
    goal: '全程不飲酒',
  ),
  ChallengeItem(
    id: 'produce',
    pillar: Pillar.nourish,
    kind: ItemKind.daily,
    emoji: '🥦',
    title: '蔬果',
    shortTitle: '蔬果',
    rule: '每天至少 5 份蔬果，其中至少 3 份為蔬菜',
    goal: '每天 5 份，3 份是蔬菜',
    nourishOption: true,
  ),
  ChallengeItem(
    id: 'protein',
    pillar: Pillar.nourish,
    kind: ItemKind.daily,
    emoji: '🍳',
    title: '蛋白質',
    shortTitle: '蛋白質',
    rule: '每天至少 1.2 g/kg 體重',
    goal: '每天 1.2 g/kg 體重',
    nourishOption: true,
  ),
  ChallengeItem(
    id: 'water',
    pillar: Pillar.nourish,
    kind: ItemKind.daily,
    emoji: '💧',
    title: '飲水',
    shortTitle: '飲水',
    rule: '每天至少 30 ml/kg 體重的白開水',
    goal: '每天 30 ml/kg 體重',
    nourishOption: true,
  ),
  ChallengeItem(
    id: 'reading',
    pillar: Pillar.learn,
    kind: ItemKind.daily,
    emoji: '📖',
    title: '閱讀',
    shortTitle: '閱讀',
    rule: '每天至少 20 分鐘閱讀書籍或聆聽有聲書',
    goal: '每天 20 分鐘',
  ),
  ChallengeItem(
    id: 'sleep',
    pillar: Pillar.recover,
    kind: ItemKind.daily,
    emoji: '🛏️',
    title: '睡眠機會',
    shortTitle: '睡眠',
    rule: '每天為睡眠保留至少 8 小時',
    goal: '留 8 小時給睡眠',
  ),
  ChallengeItem(
    id: 'schedule',
    pillar: Pillar.recover,
    kind: ItemKind.daily,
    emoji: '⏰',
    title: '規律作息',
    shortTitle: '作息',
    rule: '設定固定的睡眠時間，每天各維持在 ±60 分鐘範圍內',
    goal: '固定時間睡、固定時間起',
  ),
  ChallengeItem(
    id: 'noticed',
    pillar: Pillar.reflect,
    kind: ItemKind.daily,
    emoji: '✏️',
    title: '每日微反思',
    shortTitle: '反思',
    rule: '每天記錄挑戰執行，並記下一件「今天我注意到的事」',
    goal: '寫下今天注意到的事',
    prompts: ['今天我注意到的事'],
  ),
  ChallengeItem(
    id: 'review',
    pillar: Pillar.reflect,
    kind: ItemKind.weekly,
    emoji: '🔍',
    title: '每週回顧',
    shortTitle: '回顧',
    rule: '每週回答三個問題：這週什麼做得好，為什麼？什麼遇到困難或阻礙，為什麼？下週要保留、改變什麼？',
    goal: '回答 3 個問題',
    prompts: ['這週什麼做得好？為什麼？', '什麼遇到困難或阻礙？為什麼？', '下週要保留、改變什麼？'],
  ),
  ChallengeItem(
    id: 'plan',
    pillar: Pillar.reflect,
    kind: ItemKind.weekly,
    emoji: '🗓️',
    title: '下週計畫',
    shortTitle: '計畫',
    rule: '提前安排下一週，尤其是每週的 Move 項目',
    goal: '排好下週的 Move',
    prompts: ['下週怎麼安排？（尤其是 Move）'],
  ),
  ChallengeItem(
    id: 'photo',
    pillar: Pillar.reflect,
    kind: ItemKind.weekly,
    emoji: '📷',
    title: '每週一張照片',
    shortTitle: '照片',
    rule: '每週留下一張代表這週生活的照片',
    goal: '留一張這週的照片',
  ),
];

ChallengeItem itemById(String id) => challengeItems.firstWhere((item) => item.id == id);

/// Nourish 3 選 2 的三個選項。
final nourishOptions = [for (final item in challengeItems) if (item.nourishOption) item];

/// 這個人要做的項目：Nourish 的選項只算選了的兩項。
List<ChallengeItem> activeItems(Profile profile) => [
      for (final item in challengeItems)
        if (!item.nourishOption || profile.nourishChoice.contains(item.id)) item,
    ];

/// 依個人設定算出來的目標，例如體重 60 kg → 每天 72 g 蛋白質。
String itemTarget(ChallengeItem item, Profile profile) {
  final weight = profile.weightKg;
  final bedtime = profile.bedtime;
  final wakeTime = profile.wakeTime;
  return switch (item.id) {
    'protein' when weight != null => '每天 ${(weight * 1.2).round()} g 蛋白質',
    'water' when weight != null => '每天 ${(weight * 30).round()} ml 白開水',
    'sleep' when bedtime != null && wakeTime != null =>
      '${formatClock(bedtime)}–${formatClock(wakeTime)}，${formatHours(profile.sleepWindow!)} 小時',
    'schedule' when bedtime != null && wakeTime != null =>
      '${formatClock(bedtime)} 睡、${formatClock(wakeTime)} 起（±60 分）',
    _ => item.goal,
  };
}
