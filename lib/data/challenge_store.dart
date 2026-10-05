import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_log.dart';
import '../models/challenge.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/rules.dart';
import 'demo_data.dart';

/// Demo 用的資料層：自己的資料存在手機本機，隊友是示範資料。
class ChallengeStore extends ChangeNotifier {
  ChallengeStore._(this._prefs, this.challenge, this._clock);

  /// [demoDay]：挑戰還沒開始時，Demo 預設假裝已經進行到第幾天（null 就用真正的日期）。
  static Future<ChallengeStore> load({
    Challenge? challenge,
    DateTime Function()? clock,
    int? demoDay = 30,
  }) async {
    final store = ChallengeStore._(
      await SharedPreferences.getInstance(),
      challenge ?? defaultChallenge,
      clock ?? DateTime.now,
    );
    store._restore(demoDay);
    return store;
  }

  static const _setupKey = 'setupDone';
  static const _profileKey = 'profile.v2';
  static const _logKey = 'log.v2';
  static const _cheersKey = 'cheers';
  static const _previewDateKey = 'previewDate';

  /// 存在 [_previewDateKey] 裡，代表使用者選了「用真正的今天」。
  static const _realToday = 'today';

  final SharedPreferences _prefs;
  final Challenge challenge;
  final DateTime Function() _clock;

  bool _setupDone = false;
  Profile _profile = const Profile();
  ActivityLog _log = ActivityLog();

  /// 我今天幫誰加油過，格式是「日期|playerId」。
  final Set<String> _myCheers = {};
  DateTime? _previewDate;

  List<Player>? _teammates;
  DateTime? _teammatesDay;

  /// 教學（Setup）走完了沒。
  bool get isSetUp => _setupDone;
  Profile get profile => _profile;

  /// Demo 用：把「今天」換成其他日期，方便看挑戰中、結束後的畫面。
  DateTime? get previewDate => _previewDate;

  DateTime get today => _previewDate ?? dateOnly(_clock());
  ChallengePhase get phase => challenge.phaseOn(today);
  int get weekNumber => challenge.weekNumber(challenge.clamp(today));

  /// Nourish 的 3 選 2 在挑戰開始後就鎖定。
  bool get nourishLocked => phase != ChallengePhase.notStarted && _profile.nourishReady;

  Player get me => Player(id: 'me', profile: _profile, log: _log, isMe: true);

  /// 所有參加者，自己排第一個。
  List<Player> get players => [me, ..._teammatesOn(today)];

  Player? playerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  List<ChallengeItem> get items => activeItems(_profile);
  ItemProgress progress(ChallengeItem item) => progressOf(item, _log, challenge, today);
  WeekSummary get summary => summarize(items, _log, challenge, today);
  Entry entryOn(ChallengeItem item, DateTime date) => _log.entryOn(item, date);
  bool dayComplete(DateTime date) => me.dayComplete(challenge, date);

  /// 只能記錄挑戰期間、而且不是未來的日子。
  bool canLogOn(DateTime date) => challenge.contains(date) && !date.isAfter(today);

  Future<void> finishSetup(Profile profile) async {
    _profile = Profile(
      name: profile.name.trim().isEmpty ? Profile.defaultName : profile.name.trim(),
      avatar: profile.avatar,
      weightKg: profile.weightKg,
      nourishChoice: nourishLocked ? _profile.nourishChoice : profile.nourishChoice,
      bedtime: profile.bedtime,
      wakeTime: profile.wakeTime,
    );
    _setupDone = true;
    notifyListeners();
    await _prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
    await _prefs.setBool(_setupKey, true);
  }

  /// 打勾的項目（每天的、每週照片）：切換 [date] 那一期。
  Future<void> toggle(ChallengeItem item, DateTime date) async {
    if (!canLogOn(date)) return;
    final done = _log.entryOn(item, date).isDone;
    _log.set(item, date, done ? Entry.empty : const Entry(amount: 1));
    await _saveLog();
  }

  /// 累計的項目（有氧分鐘、肌力次數）：設定 [date] 那天的數量。
  Future<void> setAmount(ChallengeItem item, DateTime date, int amount) async {
    if (!canLogOn(date)) return;
    _log.set(item, date, Entry(amount: max(0, amount)));
    await _saveLog();
  }

  /// 桌面小工具上的鍵帽：按一下今天就打卡，再按一下取消。
  /// 累計的項目一次記 [ChallengeItem.quickAmount]（例如有氧 30 分鐘）。
  Future<void> quickToggle(ChallengeItem item) async {
    if (item.kind == ItemKind.weeklyAmount) {
      final done = _log.entryOn(item, today).isDone;
      await setAmount(item, today, done ? 0 : item.quickAmount);
    } else {
      await toggle(item, today);
    }
  }

  /// 寫字的項目：今天注意到的事、每週回顧、下週計畫。
  Future<void> saveNotes(ChallengeItem item, DateTime date, List<String> notes) async {
    if (!canLogOn(date)) return;
    final trimmed = [for (final note in notes) note.trim()];
    if (listEquals(trimmed, _log.entryOn(item, date).notes)) return;
    _log.set(item, date, Entry(amount: trimmed.where((note) => note.isNotEmpty).length, notes: trimmed));
    await _saveLog();
  }

  String _cheerKey(String playerId) => '${dateKey(today)}|$playerId';

  /// 我今天幫 [playerId] 加油（或慶祝）過了沒。
  bool hasCheered(String playerId) => _myCheers.contains(_cheerKey(playerId));

  /// 幫隊友加油：今天還沒完成的是「集氣」，已經完成的是「慶祝」。一天一次。
  Future<void> cheer(String playerId) async {
    if (phase != ChallengePhase.ongoing || playerId == me.id) return;
    if (!_myCheers.add(_cheerKey(playerId))) return;
    notifyListeners();
    await _prefs.setStringList(_cheersKey, _myCheers.toList());
  }

  /// 今天收到幾個加油（示範隊友給的＋我按的）。
  int cheersFor(String playerId) {
    if (phase != ChallengePhase.ongoing) return 0;
    return demoCheers(playerId, challenge.dayNumber(today)) + (hasCheered(playerId) ? 1 : 0);
  }

  /// 傳 null 就是用真正的今天。
  Future<void> setPreviewDate(DateTime? date) async {
    _previewDate = date == null ? null : dateOnly(date);
    notifyListeners();
    await _prefs.setString(_previewDateKey, date == null ? _realToday : dateKey(date));
  }

  /// 開發用：清掉所有資料，從教學重新開始。
  Future<void> resetAll() async {
    _setupDone = false;
    _profile = const Profile();
    _log = ActivityLog();
    _myCheers.clear();
    notifyListeners();
    await _prefs.remove(_setupKey);
    await _prefs.remove(_profileKey);
    await _prefs.remove(_logKey);
    await _prefs.remove(_cheersKey);
  }

  /// 重新讀一次本機資料：桌面小工具會在背景直接打卡，回到 App 時要同步。
  Future<void> reload() async {
    await _prefs.reload();
    _myCheers.clear();
    _restore(null);
    notifyListeners();
  }

  List<Player> _teammatesOn(DateTime day) {
    if (_teammates == null || _teammatesDay != day) {
      _teammates = buildDemoPlayers(challenge, day);
      _teammatesDay = day;
    }
    return _teammates!;
  }

  Future<void> _saveLog() async {
    notifyListeners();
    await _prefs.setString(_logKey, jsonEncode(_log.toJson()));
  }

  void _restore(int? demoDay) {
    try {
      _setupDone = _prefs.getBool(_setupKey) ?? false;
      final profile = _prefs.getString(_profileKey);
      if (profile != null) _profile = Profile.fromJson(jsonDecode(profile) as Map<String, dynamic>);
      final log = _prefs.getString(_logKey);
      if (log != null) _log = ActivityLog.fromJson(jsonDecode(log) as Map<String, dynamic>);
      _myCheers.addAll(_prefs.getStringList(_cheersKey) ?? const []);

      final preview = _prefs.getString(_previewDateKey);
      if (preview == null) {
        // Demo：挑戰還沒開始的話什麼都不能打卡，所以預設假裝已經進行到第 [demoDay] 天。
        final notStarted = challenge.phaseOn(dateOnly(_clock())) == ChallengePhase.notStarted;
        if (demoDay != null && notStarted) _previewDate = challenge.dateOfDay(demoDay);
      } else if (preview != _realToday) {
        _previewDate = parseDateKey(preview);
      }
    } on FormatException {
      // 本機資料壞掉時就從頭開始，不要讓 App 打不開。
    }
  }
}
