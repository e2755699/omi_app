import 'dart:math';

import 'challenge.dart';
import 'progress.dart';
import 'rules.dart';

/// 某個項目到目前為止的戰績。每天的項目以「天」計，每週的項目以「週」計。
class ItemStat {
  const ItemStat({required this.item, required this.periods, this.amount = 0});

  final ChallengeItem item;

  /// 每一期（天或週）有沒有做到，舊的在前。最後一期還沒做到的話先不算。
  final List<bool> periods;

  /// 累計的數量：有氧分鐘數、肌力次數（其他項目是 0）。
  final int amount;

  /// 做到的天數（或週數）。
  int get done => periods.where((done) => done).length;

  /// 已經算數的天數（或週數）：今天（這週）還沒做完就先不算。
  int get total => periods.length;

  /// 現在連續做到幾天（或幾週）。
  int get streak {
    var streak = 0;
    for (final done in periods.reversed) {
      if (!done) break;
      streak++;
    }
    return streak;
  }

  bool get weeklyPeriod => item.kind != ItemKind.daily;
  String get periodUnit => weeklyPeriod ? '週' : '天';
  double get rate => total == 0 ? 0 : done / total;

  /// 排名用的達成率：次數少的項目往中間拉。
  double get score => (done + 1) / (total + 2);
  int get percent => (rate * 100).round();

  /// 用絕對的數字炫耀，比百分比更有感，例如「0 滴酒 × 30 天」。
  String get bragLine => switch (item.id) {
        'aerobic' => '有氧累計 $amount 分鐘',
        'strength' => '肌力訓練 $amount 次',
        'alcohol' => '0 滴酒 × $done 天',
        'produce' => '$done 天吃滿 5 份蔬果',
        'protein' => '$done 天吃夠蛋白質',
        'water' => '$done 天喝足白開水',
        'reading' => '至少讀了 ${done * 20} 分鐘',
        'sleep' => '$done 晚留滿 8 小時睡眠',
        'schedule' => '$done 天準時睡、準時起',
        'noticed' => '寫下 $done 件注意到的事',
        _ => '$done $periodUnit都有做到',
      };
}

/// 炫耀卡用的戰績，從一位參加者的紀錄算出來。
class BragStats {
  BragStats._({
    required this.player,
    required this.dayNumber,
    required this.totalDays,
    required this.streak,
    required this.bestStreak,
    required this.perfectDays,
    required this.items,
    required this.days,
    required this.cheers,
    required this.teamRank,
    required this.teamSize,
  });

  /// [teammates] 用來排名（可以包含 [player] 自己）。
  factory BragStats.of(
    Player player,
    Challenge challenge,
    DateTime today, {
    int cheers = 0,
    List<Player> teammates = const [],
  }) {
    final elapsed = challenge.elapsedDays(today);
    final items = [for (final item in player.items) _itemStat(item, player, challenge, today)];
    final dailyItems = player.items.where((item) => item.kind == ItemKind.daily).toList();

    final days = <double?>[];
    var perfectDays = 0;
    var bestStreak = 0;
    var run = 0;
    for (var day = 1; day <= challenge.totalDays; day++) {
      final date = challenge.dateOfDay(day);
      if (day > elapsed) {
        days.add(null);
        continue;
      }
      final done = dailyItems.where((item) => player.log.entryOn(item, date).isDone).length;
      final isToday = date == dateOnly(today);
      // 今天還沒開始打卡就先空著，不要算成沒做到。
      days.add(isToday && done == 0 ? null : (dailyItems.isEmpty ? 0 : done / dailyItems.length));
      if (player.dayComplete(challenge, date)) perfectDays++;
      run = player.checkedInOn(challenge, date) ? run + 1 : 0;
      bestStreak = max(bestStreak, run);
    }

    final scores = {
      for (final other in teammates.isEmpty ? [player] : teammates)
        other.id: _overallRate(other, challenge, today),
    };
    final mine = scores[player.id] ?? _overallRate(player, challenge, today);
    final ahead = scores.entries.where((e) => e.key != player.id && e.value > mine).length;

    return BragStats._(
      player: player,
      dayNumber: elapsed,
      totalDays: challenge.totalDays,
      streak: player.checkInStreak(challenge, today),
      bestStreak: bestStreak,
      perfectDays: perfectDays,
      items: items,
      days: days,
      cheers: cheers,
      teamRank: ahead + 1,
      teamSize: max(1, scores.length),
    );
  }

  final Player player;

  /// 挑戰進行到第幾天（0–[totalDays]）。
  final int dayNumber;
  final int totalDays;

  /// 現在連續打卡幾天。
  final int streak;

  /// 最長連續打卡幾天。
  final int bestStreak;

  /// 每日項目全部完成的天數。
  final int perfectDays;
  final List<ItemStat> items;

  /// 每一天每日項目完成的比例（0–1）；還沒到的日子是 null。
  final List<double?> days;

  /// 今天收到的應援。
  final int cheers;

  /// 在隊上的名次（1 起算）與隊伍人數。
  final int teamRank;
  final int teamSize;

  /// 最強的項目：達成率最高，同分比連續，再同分比做到的次數。
  /// 達成率先做平滑（多算一次成功、一次失敗），4/4 週才不會贏過 29/30 天。
  ItemStat get bestItem => items.reduce((best, stat) {
        final byRate = stat.score.compareTo(best.score);
        if (byRate != 0) return byRate > 0 ? stat : best;
        final byStreak = stat.streak.compareTo(best.streak);
        if (byStreak != 0) return byStreak > 0 ? stat : best;
        return stat.done > best.done ? stat : best;
      });

  /// 所有項目達成率的平均。
  double get overall => items.isEmpty ? 0 : items.map((stat) => stat.rate).reduce((a, b) => a + b) / items.length;
  int get overallPercent => (overall * 100).round();

  /// 五大類各自的達成率（該類項目的平均）。
  Map<Pillar, double> get pillarRates => {
        for (final pillar in Pillar.values)
          pillar: _average([
            for (final stat in items)
              if (stat.item.pillar == pillar) stat.rate,
          ]),
      };

  /// 到今天為止，平均每天完成幾成的每日項目。
  double get dailyAverage => _average([for (final day in days) ?day]);

  /// 贏過幾 % 的隊友。
  int get beatPercent => teamSize <= 1 ? 100 : ((teamSize - teamRank) / (teamSize - 1) * 100).round();

  /// 有紀錄可以炫耀了沒。
  bool get hasRecords => days.any((day) => day != null && day > 0) || items.any((stat) => stat.done > 0);
}

double _average(List<double> values) => values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

double _overallRate(Player player, Challenge challenge, DateTime today) =>
    _average([for (final item in player.items) _itemStat(item, player, challenge, today).rate]);

ItemStat _itemStat(ChallengeItem item, Player player, Challenge challenge, DateTime today) {
  final elapsed = challenge.elapsedDays(today);
  if (elapsed == 0) return ItemStat(item: item, periods: const []);

  // 每一期（天或週）有沒有做到，舊的在前。最後一期還沒做到的話先不算。
  final periods = <bool>[];
  var amount = 0;
  if (item.kind == ItemKind.weeklyAmount) {
    for (var day = 1; day <= elapsed; day++) {
      amount += player.log.entryOn(item, challenge.dateOfDay(day)).amount;
    }
  }
  if (item.kind == ItemKind.daily) {
    for (var day = 1; day <= elapsed; day++) {
      periods.add(player.log.entryOn(item, challenge.dateOfDay(day)).isDone);
    }
  } else {
    final last = challenge.clamp(today);
    final start = challenge.start;
    for (var week = 1; week <= challenge.weekNumber(last); week++) {
      // 用那週在挑戰期間內的最後一天來看整週的進度。
      final weekDays = challenge.weekOf(DateTime(start.year, start.month, start.day + 7 * (week - 1)));
      final inChallenge = weekDays.where((day) => challenge.contains(day) && !day.isAfter(last));
      periods.add(progressOf(item, player.log, challenge, inChallenge.last).doneNow);
    }
  }
  if (periods.isNotEmpty && !periods.last) periods.removeLast();
  return ItemStat(item: item, periods: periods, amount: amount);
}

/// 依連續天數給的稱號。
String streakTitle(int days) => switch (days) {
      >= 100 => '薛西弗斯本人',
      >= 50 => '半百傳說',
      >= 30 => '月度鐵人',
      >= 21 => '習慣成形',
      >= 14 => '雙週不斷電',
      >= 7 => '一週全勤',
      >= 3 => '三連起步',
      _ => '推石頭新手',
    };

/// 每個項目做得最好時的稱號。
String itemTitle(ChallengeItem item) => switch (item.id) {
      'aerobic' => '有氧狂戰士',
      'strength' => '鋼鐵肌肉人',
      'alcohol' => '滴酒不沾仙人',
      'produce' => '蔬果大法師',
      'protein' => '蛋白質獵人',
      'water' => '水之呼吸',
      'reading' => '行走的圖書館',
      'sleep' => '睡眠之神',
      'schedule' => '人體鬧鐘',
      'noticed' => '覺察大師',
      'review' => '反省之王',
      'plan' => '人生策展人',
      'photo' => '生活攝影師',
      _ => '自律達人',
    };

/// 依整體達成率給的評價。
String gradeOf(double rate) => switch (rate) {
      >= 0.9 => 'S',
      >= 0.75 => 'A',
      >= 0.6 => 'B',
      >= 0.4 => 'C',
      _ => 'D',
    };
