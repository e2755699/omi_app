import 'dart:math';

import 'challenge.dart';
import 'progress.dart';
import 'rules.dart';

/// 獎章中間的像素圖案。
enum BadgeMotif { check, star, flame, crown, bolt, sprout, book, moon, magnifier, trophy }

/// 獎章的外觀。顏色用 0xAARRGGBB 的整數，模型不用依賴 Flutter。
class BadgeLook {
  const BadgeLook({required this.face, required this.ribbon, required this.motif});

  /// 獎牌本體的顏色。
  final int face;

  /// 緞帶的顏色。
  final int ribbon;
  final BadgeMotif motif;
}

/// 實體獎章可以選的形式。
enum BadgeForm {
  display('擺飾', '🏠', '放在家裡的桌上或書架'),
  patch('魔鬼氈臂章', '🧥', '用魔鬼氈貼在包包或外套'),
  charm('包包吊飾', '🎒', '掛在包包上當吊飾');

  const BadgeForm(this.label, this.emoji, this.hint);

  final String label;
  final String emoji;
  final String hint;
}

/// 算獎章用的統計：只看挑戰期間、而且是 today（含）以前的紀錄。
class BadgeStats {
  const BadgeStats({
    this.checkInDays = 0,
    this.longestStreak = 0,
    this.bestDailyDone = 0,
    this.dailyTotal = 0,
    this.bestMovePercent = 0,
    this.reviewWeeks = 0,
    this.itemDays = const {},
    this.elapsedDays = 0,
    this.totalDays = 100,
    this.finished = false,
  });

  factory BadgeStats.of(Player player, Challenge challenge, DateTime today) {
    final lastDay = challenge.elapsedDays(dateOnly(today));
    final log = player.log;
    final daily = [for (final item in player.items) if (item.kind == ItemKind.daily) item];
    final itemDays = {for (final item in daily) item.id: 0};

    var checkInDays = 0;
    var run = 0;
    var longest = 0;
    var bestDaily = 0;
    for (var day = 1; day <= lastDay; day++) {
      final date = challenge.dateOfDay(day);
      if (player.checkedInOn(challenge, date)) {
        checkInDays++;
        run++;
        longest = max(longest, run);
      } else {
        run = 0;
      }
      var done = 0;
      for (final item in daily) {
        if (!log.entryOn(item, date).isDone) continue;
        done++;
        itemDays[item.id] = itemDays[item.id]! + 1;
      }
      bestDaily = max(bestDaily, done);
    }

    // 一週一週看：MOVE 能量（有氧＋肌力的平均）、每週回顧有沒有寫完。
    final move = [for (final item in player.items) if (item.pillar == Pillar.move) item];
    final review = itemById('review');
    var bestMove = 0;
    var reviewWeeks = 0;
    if (lastDay > 0) {
      final lastDate = challenge.dateOfDay(lastDay);
      for (var monday = weekStart(challenge.start);
          !monday.isAfter(lastDate);
          monday = DateTime(monday.year, monday.month, monday.day + 7)) {
        final sunday = DateTime(monday.year, monday.month, monday.day + 6);
        final asOf = sunday.isAfter(lastDate) ? lastDate : sunday;
        if (move.isNotEmpty) {
          final energy =
              move.map((item) => progressOf(item, log, challenge, asOf).energy).reduce((a, b) => a + b) / move.length;
          // 加一點點避免浮點誤差，例如 0.29 × 100 = 28.999…
          bestMove = max(bestMove, (energy * 100 + 1e-9).floor());
        }
        if (progressOf(review, log, challenge, asOf).doneNow) reviewWeeks++;
      }
    }

    return BadgeStats(
      checkInDays: checkInDays,
      longestStreak: longest,
      bestDailyDone: bestDaily,
      dailyTotal: daily.length,
      bestMovePercent: bestMove,
      reviewWeeks: reviewWeeks,
      itemDays: itemDays,
      elapsedDays: lastDay,
      totalDays: challenge.totalDays,
      finished: lastDay >= challenge.totalDays && player.checkedInOn(challenge, challenge.end),
    );
  }

  /// 有打卡的天數。
  final int checkInDays;

  /// 最長連續打卡天數（中斷了也不會變少）。
  final int longestStreak;

  /// 單日最多完成幾個每日項目。
  final int bestDailyDone;

  /// 每日項目總共有幾個。
  final int dailyTotal;

  /// MOVE 能量最高的那一週是幾 %（0–100）。
  final int bestMovePercent;

  /// 每週回顧 3 題全部寫完的週數。
  final int reviewWeeks;

  /// 每個每日項目做到的天數（項目 id → 天數）。
  final Map<String, int> itemDays;

  /// 挑戰已經進行幾天（0–100）。
  final int elapsedDays;
  final int totalDays;

  /// 走到最後一天，而且最後一天也有打卡。
  final bool finished;

  int daysOf(String itemId) => itemDays[itemId] ?? 0;
}

/// 一個成就（獎章）的定義。
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.howTo,
    required this.unit,
    required this.look,
    required this.measure,
  });

  final String id;
  final String title;

  /// 這個獎章的意義。
  final String description;

  /// 怎麼拿到。
  final String howTo;

  /// 進度的單位，例如「天」「%」。
  final String unit;
  final BadgeLook look;

  /// 從統計算出（目前、目標）。
  final (int, int) Function(BadgeStats stats) measure;

  AchievementStatus evaluate(BadgeStats stats) {
    final (current, target) = measure(stats);
    return AchievementStatus(achievement: this, current: min(max(current, 0), target), target: target);
  }
}

/// 某個人某個獎章目前的狀態。
class AchievementStatus {
  const AchievementStatus({required this.achievement, required this.current, required this.target});

  final Achievement achievement;
  final int current;
  final int target;

  bool get unlocked => current >= target;
  double get ratio => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);

  /// 例：7/30 天、50%。
  String get progressLabel =>
      achievement.unit == '%' ? '$current%' : '$current/$target ${achievement.unit}';
}

/// 全部的獎章，大致照難度排。
final achievements = <Achievement>[
  Achievement(
    id: 'first_checkin',
    title: '第一次打卡',
    description: '萬事起頭難。按下第一顆鍵帽，100 天的冒險就開始了。',
    howTo: '任何一天記錄任一項每日項目或運動',
    unit: '天',
    look: const BadgeLook(face: 0xFFFF8FAB, ribbon: 0xFF3A86FF, motif: BadgeMotif.check),
    measure: (s) => (s.checkInDays, 1),
  ),
  Achievement(
    id: 'perfect_day',
    title: '完美的一天',
    description: '一天之內把每日項目全部做到，所有鍵帽一起亮起來。',
    howTo: '同一天完成所有每日項目（包含「今天我注意到的事」）',
    unit: '項',
    look: const BadgeLook(face: 0xFF4CC9F0, ribbon: 0xFFFFCC00, motif: BadgeMotif.star),
    measure: (s) => (s.bestDailyDone, max(1, s.dailyTotal)),
  ),
  Achievement(
    id: 'streak_7',
    title: '連續打卡 7 天',
    description: '整整一週沒有中斷，習慣正在成形。',
    howTo: '連續 7 天都有打卡（中斷會重算，但最佳紀錄會留著）',
    unit: '天',
    look: const BadgeLook(face: 0xFFFF7A3D, ribbon: 0xFFFFCC00, motif: BadgeMotif.flame),
    measure: (s) => (s.longestStreak, 7),
  ),
  Achievement(
    id: 'streak_30',
    title: '連續打卡 30 天',
    description: '一個月不間斷，這已經不是挑戰，是你的生活方式。',
    howTo: '連續 30 天都有打卡',
    unit: '天',
    look: const BadgeLook(face: 0xFFB8222A, ribbon: 0xFF1A1A1A, motif: BadgeMotif.crown),
    measure: (s) => (s.longestStreak, 30),
  ),
  Achievement(
    id: 'move_week',
    title: 'MOVE 滿格週',
    description: '有氧 150 分鐘＋肌力 2 次，同一週全部達標。',
    howTo: '同一週的有氧和肌力能量都衝到 100%',
    unit: '%',
    look: const BadgeLook(face: 0xFFF29F05, ribbon: 0xFF3A86FF, motif: BadgeMotif.bolt),
    measure: (s) => (s.bestMovePercent, 100),
  ),
  Achievement(
    id: 'sober_30',
    title: '清醒 30 天',
    description: '累積 30 天 0 酒精，身體和睡眠都會感謝你。',
    howTo: '「0 酒精」累積打勾 30 天',
    unit: '天',
    look: const BadgeLook(face: 0xFF3FA34D, ribbon: 0xFFFFCC00, motif: BadgeMotif.sprout),
    measure: (s) => (s.daysOf('alcohol'), 30),
  ),
  Achievement(
    id: 'reading_30',
    title: '閱讀 30 天',
    description: '每天 20 分鐘，累積起來就是好幾本書。',
    howTo: '「閱讀」累積打勾 30 天',
    unit: '天',
    look: const BadgeLook(face: 0xFF3A86FF, ribbon: 0xFFFF8FAB, motif: BadgeMotif.book),
    measure: (s) => (s.daysOf('reading'), 30),
  ),
  Achievement(
    id: 'sleep_21',
    title: '好眠 21 天',
    description: '給睡眠 8 小時的機會，21 天養成好眠的習慣。',
    howTo: '「睡眠機會」累積打勾 21 天',
    unit: '天',
    look: const BadgeLook(face: 0xFF8B5CF6, ribbon: 0xFF1A1A1A, motif: BadgeMotif.moon),
    measure: (s) => (s.daysOf('sleep'), 21),
  ),
  Achievement(
    id: 'review_first',
    title: '第一次每週回顧',
    description: '停下來想想這週的好與難，是進步最快的方法。',
    howTo: '把每週回顧的 3 個問題都寫完',
    unit: '週',
    look: const BadgeLook(face: 0xFFE4572E, ribbon: 0xFF4CC9F0, motif: BadgeMotif.magnifier),
    measure: (s) => (s.reviewWeeks, 1),
  ),
  Achievement(
    id: 'finish_100',
    title: '完成 100 天',
    description: '從第 1 天走到第 100 天，這是完賽者才有的獎章。',
    howTo: '撐到挑戰最後一天，而且最後一天也有打卡',
    unit: '天',
    look: const BadgeLook(face: 0xFFFFCC00, ribbon: 0xFFE4572E, motif: BadgeMotif.trophy),
    // 還沒完賽前最多顯示到 99，避免進度條滿了卻沒解鎖。
    measure: (s) => (s.finished ? s.totalDays : min(s.elapsedDays, s.totalDays - 1), s.totalDays),
  ),
];

Achievement achievementById(String id) => achievements.firstWhere((a) => a.id == id);

/// 算出 [player] 到 [today] 為止每個獎章的狀態，順序和 [achievements] 一樣。
List<AchievementStatus> evaluateAchievements(Player player, Challenge challenge, DateTime today) {
  final stats = BadgeStats.of(player, challenge, today);
  return [for (final achievement in achievements) achievement.evaluate(stats)];
}
