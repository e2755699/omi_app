import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievements.dart';
import '../models/challenge.dart';

final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 一個實體獎章的申請。Demo 只記款式和日期，不收地址等個人資料。
class BadgeClaim {
  const BadgeClaim({required this.form, required this.requestedOn});

  final BadgeForm form;
  final DateTime requestedOn;

  Map<String, Object?> toJson() => {'form': form.name, 'on': dateKey(requestedOn)};

  /// 資料不完整就回傳 null。
  static BadgeClaim? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final form = BadgeForm.values.asNameMap()[json['form']];
    final on = json['on'];
    if (form == null || on is! String || !_datePattern.hasMatch(on)) return null;
    return BadgeClaim(form: form, requestedOn: parseDateKey(on));
  }
}

/// 實體獎章的申請狀態，存在手機本機（key 都以 `badges.` 開頭）。
/// 打開獎章頁時才讀，不在 App 啟動時載入。
class BadgeClaims extends ChangeNotifier {
  BadgeClaims._(this._prefs);

  static Future<BadgeClaims> load() async {
    final claims = BadgeClaims._(await SharedPreferences.getInstance());
    claims._restore();
    return claims;
  }

  static const storageKey = 'badges.claims.v1';

  final SharedPreferences _prefs;
  final Map<String, BadgeClaim> _claims = {};

  BadgeClaim? claimOf(String achievementId) => _claims[achievementId];

  /// 申請了幾個。
  int get count => _claims.length;

  /// 申請實體獎章：只有解鎖的獎章可以申請，每個獎章申請一次。成功回傳 true。
  Future<bool> request(AchievementStatus status, BadgeForm form, DateTime date) async {
    final id = status.achievement.id;
    if (!status.unlocked || _claims.containsKey(id)) return false;
    _claims[id] = BadgeClaim(form: form, requestedOn: dateOnly(date));
    notifyListeners();
    await _save();
    return true;
  }

  /// Demo 用：取消申請，可以重新選款式。
  Future<void> cancel(String achievementId) async {
    if (_claims.remove(achievementId) == null) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _prefs.setString(
        storageKey,
        jsonEncode({for (final MapEntry(:key, :value) in _claims.entries) key: value.toJson()}),
      );

  void _restore() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;
      for (final MapEntry(:key, :value) in json.entries) {
        final claim = BadgeClaim.fromJson(value);
        if (claim != null) _claims[key] = claim;
      }
    } on FormatException {
      // 本機資料壞掉就當作沒申請過。
    }
  }
}
