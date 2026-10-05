import 'challenge.dart';
import 'rules.dart';

/// 某個項目在某一期（某天或某週）的紀錄。
class Entry {
  const Entry({this.amount = 0, this.notes = const []});

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        amount: json['a'] as int? ?? 0,
        notes: (json['n'] as List<dynamic>? ?? const []).cast<String>(),
      );

  static const empty = Entry();

  /// 打勾是 1；累計項目是分鐘數或次數；寫字的項目是回答了幾題。
  final int amount;
  final List<String> notes;

  bool get isDone => amount > 0;
  bool get isEmpty => amount == 0 && notes.every((note) => note.isEmpty);

  Map<String, Object?> toJson() => {'a': amount, if (notes.isNotEmpty) 'n': notes};
}

/// 一個人所有的紀錄。每天的項目用日期當 key，每週的項目用那週的週一（前面加 W）。
class ActivityLog {
  ActivityLog();

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final log = ActivityLog();
    for (final MapEntry(key: period, value: items) in json.entries) {
      log._entries[period] = {
        for (final MapEntry(key: id, value: entry) in (items as Map<String, dynamic>).entries)
          id: Entry.fromJson(entry as Map<String, dynamic>),
      };
    }
    return log;
  }

  final Map<String, Map<String, Entry>> _entries = {};

  static String _periodKey(ChallengeItem item, DateTime date) =>
      item.kind == ItemKind.weekly ? 'W${dateKey(weekStart(date))}' : dateKey(date);

  Entry entryOn(ChallengeItem item, DateTime date) =>
      _entries[_periodKey(item, date)]?[item.id] ?? Entry.empty;

  void set(ChallengeItem item, DateTime date, Entry entry) {
    final key = _periodKey(item, date);
    if (entry.isEmpty) {
      _entries[key]?.remove(item.id);
      if (_entries[key]?.isEmpty ?? false) _entries.remove(key);
    } else {
      (_entries[key] ??= {})[item.id] = entry;
    }
  }

  Map<String, Object?> toJson() => {
        for (final MapEntry(key: period, value: items) in _entries.entries)
          period: {for (final MapEntry(key: id, value: entry) in items.entries) id: entry.toJson()},
      };
}
