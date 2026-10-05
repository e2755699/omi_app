import 'activity_log.dart';
import 'challenge.dart';
import 'progress.dart';
import 'rules.dart';

/// 怎麼賺星星。數字故意定得很簡單，方便討論時調整。
enum StarRule {
  perfectDay(1, '全勤日', '當天的每日項目全部打勾'),
  fullPillar(3, '能量滿格', '某一類（MOVE、NOURISH…）一週內充到 100%，每週每類一次'),
  streak(5, '連續打卡', '每連續打卡 7 天（第 7、14、21… 天）');

  const StarRule(this.stars, this.title, this.description);

  final int stars;
  final String title;
  final String description;
}

/// 全部做到的話，一週最多賺幾顆星（給定價時參考）。
int get maxStarsPerWeek =>
    7 * StarRule.perfectDay.stars + StarRule.streak.stars + Pillar.values.length * StarRule.fullPillar.stars;

/// 撲滿裡的一筆：哪天、為什麼、幾顆星。
class StarEvent {
  const StarEvent({required this.date, required this.rule, required this.reason, this.pillar});

  final DateTime date;
  final StarRule rule;

  /// 例：每日項目全部完成、第 2 週 MOVE 能量 100%、連續打卡 14 天。
  final String reason;

  /// [StarRule.fullPillar] 是哪一類。
  final Pillar? pillar;

  int get stars => rule.stars;
}

/// 星星明細，依日期由舊到新。
class StarLedger {
  const StarLedger(this.events);

  static const empty = StarLedger([]);

  final List<StarEvent> events;

  int get total => events.fold(0, (sum, event) => sum + event.stars);

  int countOf(StarRule rule) => events.where((event) => event.rule == rule).length;
}

/// 從打卡紀錄算出賺到的星星：只算挑戰期間、到 [today]（含）為止的日子。
/// 同樣的紀錄一定算出同樣的結果；取消打卡的話星星也會跟著收回。
StarLedger computeStars({
  required ActivityLog log,
  required List<ChallengeItem> items,
  required Challenge challenge,
  required DateTime today,
}) {
  final lastDay = challenge.elapsedDays(dateOnly(today));
  if (lastDay == 0) return StarLedger.empty;

  final events = <StarEvent>[];
  final daily = [for (final item in items) if (item.kind == ItemKind.daily) item];

  // 全勤日、連續打卡（打卡的定義跟 Player.checkedInOn 一樣）。
  var run = 0;
  for (var day = 1; day <= lastDay; day++) {
    final date = challenge.dateOfDay(day);
    if (daily.isNotEmpty && daily.every((item) => log.entryOn(item, date).isDone)) {
      events.add(StarEvent(date: date, rule: StarRule.perfectDay, reason: '每日項目全部完成'));
    }
    final checkedIn = items.any((item) => item.kind != ItemKind.weekly && log.entryOn(item, date).isDone);
    run = checkedIn ? run + 1 : 0;
    if (run > 0 && run % 7 == 0) {
      events.add(StarEvent(date: date, rule: StarRule.streak, reason: '連續打卡 $run 天'));
    }
  }

  // 能量滿格：每週每一類，記在第一次充到 100% 的那天。
  final last = challenge.dateOfDay(lastDay);
  for (var monday = weekStart(challenge.start);
      !monday.isAfter(last);
      monday = DateTime(monday.year, monday.month, monday.day + 7)) {
    final days = [
      for (final date in challenge.weekOf(monday))
        if (challenge.contains(date) && !date.isAfter(last)) date,
    ];
    for (final pillar in Pillar.values) {
      final pillarItems = [for (final item in items) if (item.pillar == pillar) item];
      if (pillarItems.isEmpty) continue;
      for (final date in days) {
        if (pillarItems.every((item) => progressOf(item, log, challenge, date).energy >= 1)) {
          events.add(StarEvent(
            date: date,
            rule: StarRule.fullPillar,
            pillar: pillar,
            reason: '第 ${challenge.weekNumber(date)} 週 ${pillar.tag} 能量 100%',
          ));
          break;
        }
      }
    }
  }

  events.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byRule = a.rule.index.compareTo(b.rule.index);
    if (byRule != 0) return byRule;
    return (a.pillar?.index ?? 0).compareTo(b.pillar?.index ?? 0);
  });
  return StarLedger(List.unmodifiable(events));
}

/// 某位參加者到 [today] 為止的星星明細。
StarLedger starLedgerOf(Player player, Challenge challenge, DateTime today) =>
    computeStars(log: player.log, items: player.items, challenge: challenge, today: today);
