/// 挑戰的期間設定與日期工具。
class Challenge {
  Challenge({required this.title, required DateTime start, required DateTime end})
      : start = dateOnly(start),
        end = dateOnly(end);

  final String title;
  final DateTime start;

  /// 最後一天（含）。
  final DateTime end;

  int get totalDays => daysBetween(start, end) + 1;

  /// 第幾天（從 1 開始）。開始前會小於 1，結束後會大於 [totalDays]。
  int dayNumber(DateTime date) => daysBetween(start, date) + 1;

  DateTime dateOfDay(int day) => DateTime(start.year, start.month, start.day + day - 1);

  ChallengePhase phaseOn(DateTime date) {
    final day = dayNumber(date);
    if (day < 1) return ChallengePhase.notStarted;
    if (day > totalDays) return ChallengePhase.finished;
    return ChallengePhase.ongoing;
  }

  bool contains(DateTime date) => phaseOn(date) == ChallengePhase.ongoing;

  /// 到 [date] 為止已經開始了幾天（含當天），介於 0 到 [totalDays]。
  int elapsedDays(DateTime date) => dayNumber(date).clamp(0, totalDays);

  /// 把日期限制在挑戰期間內：開始前當作第一天、結束後當作最後一天。
  DateTime clamp(DateTime date) {
    final day = dateOnly(date);
    if (day.isBefore(start)) return start;
    if (day.isAfter(end)) return end;
    return day;
  }

  /// 第幾週（週一到週日算一週，10/9 所在的那週是第 1 週）。
  int weekNumber(DateTime date) => daysBetween(weekStart(start), weekStart(date)) ~/ 7 + 1;

  int get totalWeeks => weekNumber(end);

  /// [date] 所在那一週，週一到週日的 7 天。
  List<DateTime> weekOf(DateTime date) {
    final monday = weekStart(date);
    return [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
  }
}

enum ChallengePhase { notStarted, ongoing, finished }

/// 結束日固定 12/31（擁有者決定）；開跑日是每個人開始用 App 的那天。
final challengeEnd = DateTime(2026, 12, 31);

/// 主辦（Mindy、Jimmy）的第一輪 Day 1：還沒設定時先用這天介紹，剛好 84 天。
final officialStart = DateTime(2026, 10, 9);

/// 從 [start] 到 12/31 的挑戰；開始日晚於 12/31 就只剩最後一天。
Challenge challengeStarting(DateTime start) {
  final first = dateOnly(start).isAfter(challengeEnd) ? challengeEnd : dateOnly(start);
  final days = daysBetween(first, challengeEnd) + 1;
  return Challenge(title: '$days 天挑戰', start: first, end: challengeEnd);
}

/// [d] 之後的下一個週一（[d] 本身是週一也算下一週）。
DateTime nextMonday(DateTime d) => DateTime(d.year, d.month, d.day + (8 - d.weekday));

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] 所在那一週的週一。
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// 兩個日期相差幾天。用 UTC 計算，避免日光節約時間造成誤差。
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

String dateKey(DateTime d) => '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}';

DateTime parseDateKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// 例：五
String weekdayLabel(DateTime d) => _weekdays[d.weekday - 1];

/// 例：10/9（五）
String formatDate(DateTime d) => '${d.month}/${d.day}（${weekdayLabel(d)}）';

/// 例：10/9
String formatShortDate(DateTime d) => '${d.month}/${d.day}';

String _twoDigits(int n) => n.toString().padLeft(2, '0');
