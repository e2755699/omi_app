import 'dart:math';

import 'activity_log.dart';
import 'challenge.dart';
import 'profile.dart';
import 'rules.dart';

/// 某個項目「這一週」的能量槽。
class ItemProgress {
  const ItemProgress({
    required this.value,
    required this.target,
    required this.cells,
    required this.doneNow,
  });

  /// 本週累計：天數、分鐘數、次數或回答題數。
  final int value;
  final int target;

  /// 能量槽的每一格：true 亮、false 暗、null 不在挑戰期間。
  final List<bool?> cells;

  /// 這一期（今天或本週）做完了沒。
  final bool doneNow;

  double get energy => target <= 0 ? 0 : (value / target).clamp(0.0, 1.0);
  int get percent => (energy * 100).round();
}

const _amountCells = 10;

/// 算出 [item] 在 [today] 那週的能量。每週目標會依那週在挑戰期間內的天數按比例調整
/// （例如第一週只有 10/9–10/11 三天，有氧目標就是 150 × 3/7 ≈ 65 分鐘）。
ItemProgress progressOf(ChallengeItem item, ActivityLog log, Challenge challenge, DateTime today) {
  final ref = challenge.clamp(today);
  final week = challenge.weekOf(ref);
  final counted = [for (final day in week) challenge.contains(day) && !day.isAfter(today)];
  final daysInWeek = week.where(challenge.contains).length;

  switch (item.kind) {
    case ItemKind.daily:
      final cells = [
        for (var i = 0; i < 7; i++)
          challenge.contains(week[i]) ? counted[i] && log.entryOn(item, week[i]).isDone : null,
      ];
      return ItemProgress(
        value: cells.where((cell) => cell == true).length,
        target: daysInWeek,
        cells: cells,
        doneNow: challenge.contains(today) && log.entryOn(item, today).isDone,
      );
    case ItemKind.weeklyAmount:
      final target = (item.target * daysInWeek / 7).ceil();
      var value = 0;
      for (var i = 0; i < 7; i++) {
        if (counted[i]) value += log.entryOn(item, week[i]).amount;
      }
      final lit = target == 0 ? 0 : (min(value / target, 1.0) * _amountCells).round();
      final litCells = value > 0 ? max(1, lit) : 0;
      return ItemProgress(
        value: value,
        target: target,
        cells: [for (var i = 0; i < _amountCells; i++) i < litCells],
        doneNow: value >= target,
      );
    case ItemKind.weekly:
      final target = max(1, item.prompts.length);
      final value = min(log.entryOn(item, ref).amount, target);
      return ItemProgress(
        value: value,
        target: target,
        cells: [for (var i = 0; i < target; i++) i < value],
        doneNow: value >= target,
      );
  }
}

/// 一個人這一週的整體狀況。
class WeekSummary {
  const WeekSummary({
    required this.energy,
    required this.dailyDone,
    required this.dailyTotal,
    required this.pillarEnergy,
  });

  /// 所有項目能量的平均（0–1）。
  final double energy;

  /// 今天完成幾個每日項目。
  final int dailyDone;
  final int dailyTotal;
  final Map<Pillar, double> pillarEnergy;

  int get percent => (energy * 100).round();
  bool get todayComplete => dailyTotal > 0 && dailyDone == dailyTotal;
}

WeekSummary summarize(List<ChallengeItem> items, ActivityLog log, Challenge challenge, DateTime today) {
  final all = <double>[];
  final byPillar = <Pillar, List<double>>{};
  var dailyDone = 0;
  var dailyTotal = 0;
  for (final item in items) {
    final progress = progressOf(item, log, challenge, today);
    all.add(progress.energy);
    (byPillar[item.pillar] ??= []).add(progress.energy);
    if (item.kind == ItemKind.daily) {
      dailyTotal++;
      if (progress.doneNow) dailyDone++;
    }
  }
  double average(List<double> values) => values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
  return WeekSummary(
    energy: average(all),
    dailyDone: dailyDone,
    dailyTotal: dailyTotal,
    pillarEnergy: {for (final pillar in Pillar.values) pillar: average(byPillar[pillar] ?? const [])},
  );
}

/// 一位參加者（自己或隊友）。
class Player {
  const Player({required this.id, required this.profile, required this.log, this.isMe = false});

  final String id;
  final Profile profile;
  final ActivityLog log;
  final bool isMe;

  List<ChallengeItem> get items => activeItems(profile);

  ItemProgress progress(ChallengeItem item, Challenge challenge, DateTime today) =>
      progressOf(item, log, challenge, today);

  WeekSummary summary(Challenge challenge, DateTime today) => summarize(items, log, challenge, today);

  /// 這天有沒有打卡（任何每天的項目或運動量有紀錄）。
  bool checkedInOn(Challenge challenge, DateTime date) =>
      challenge.contains(date) &&
      items.any((item) => item.kind != ItemKind.weekly && log.entryOn(item, date).isDone);

  /// 連續打卡幾天。今天還沒打卡時，算到昨天為止。
  int checkInStreak(Challenge challenge, DateTime today) {
    var date = challenge.clamp(today);
    if (challenge.contains(today) && !checkedInOn(challenge, date)) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var streak = 0;
    while (checkedInOn(challenge, date)) {
      streak++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return streak;
  }

  /// 達成幾天：到今天為止，每日項目全部完成的天數（首頁主要的數字）。
  int completeDays(Challenge challenge, DateTime today) {
    var count = 0;
    for (var day = 1; day <= challenge.elapsedDays(today); day++) {
      if (dayComplete(challenge, challenge.dateOfDay(day))) count++;
    }
    return count;
  }

  /// 每日項目全部完成的那幾天。
  bool dayComplete(Challenge challenge, DateTime date) =>
      challenge.contains(date) &&
      items.where((item) => item.kind == ItemKind.daily).every((item) => log.entryOn(item, date).isDone);

  /// 最近幾則「今天我注意到的事」，新的在前。
  List<(DateTime, String)> recentNotes(Challenge challenge, DateTime today, {int limit = 5}) {
    final noticed = itemById('noticed');
    final notes = <(DateTime, String)>[];
    for (var day = challenge.elapsedDays(today); day >= 1 && notes.length < limit; day--) {
      final date = challenge.dateOfDay(day);
      final entry = log.entryOn(noticed, date);
      if (entry.notes.isNotEmpty && entry.notes.first.isNotEmpty) notes.add((date, entry.notes.first));
    }
    return notes;
  }
}
