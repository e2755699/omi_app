import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_log.dart';
import '../models/challenge.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/rules.dart';
import 'account_controller.dart';
import 'photo_store.dart';
import 'sync/cloud_repository.dart';
import 'sync/cloud_workspace.dart';
import 'sync/local_sync_database.dart';

/// 自己的資料存在本機；登入與雲端同步獨立於本機打卡。
class ChallengeStore extends ChangeNotifier {
  ChallengeStore._(this._prefs, this._clock, this.account);

  static Future<ChallengeStore> load({DateTime Function()? clock, AccountController? account}) async {
    final store = ChallengeStore._(
      await SharedPreferences.getInstance(),
      clock ?? DateTime.now,
      account ?? AccountController.local(),
    );
    store._restore();
    store.account.addListener(store._accountChanged);
    await store._restoreCloud();
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
  final DateTime Function() _clock;
  final AccountController account;
  CloudWorkspace? cloud;
  String? _cloudUser;
  int _generation = 0;
  bool get isCloud => cloud != null;
  String get dataScope => cloud?.scope ?? 'local';
  void _accountChanged() {
    if (account.userId == _cloudUser) return;
    _generation++;
    cloud?.dispose();
    cloud = null;
    _cloudUser = account.userId;
    notifyListeners();
    unawaited(_restoreCloud());
  }

  Future<void> _restoreCloud() async {
    final uid = account.userId;
    _cloudUser = uid;
    if (uid == null || !isSetUp) return;
    final group = _prefs.getString('cloud.group.$uid');
    if (group == null) return;
    try {
      await openGroup(group);
    } catch (_) {
      /* 本機資料仍可開啟；帳號頁可重新選群組。 */
    }
  }

  Future<void> openGroup(String groupId, {bool importGuest = false}) async {
    final uid = account.userId;
    final client = account.client;
    if (uid == null || client == null) return;
    final generation = ++_generation;
    final local = await LocalSyncDatabase.open();
    final remote = CloudRepository(client, userId: uid, groupId: groupId);
    final scope = '$uid/$groupId';
    Json metadata;
    try {
      metadata = await remote.group();
      if (metadata['timezone'] != 'Asia/Taipei') throw StateError('第一版支援台北時區群組');
      await local.merge(scope, await remote.fetchOwn());
      await local.saveWorkspace(scope, metadata);
    } catch (_) {
      final cached = await local.workspace(scope);
      if (cached == null || importGuest) rethrow;
      metadata = cached;
    }
    if (generation != _generation || account.userId != uid) return;
    final workspace = CloudWorkspace(local: local, remote: remote, group: metadata);
    await workspace.readLocal();
    if (generation != _generation || account.userId != uid) {
      workspace.dispose();
      return;
    }
    cloud?.dispose();
    cloud = workspace;
    workspace.addListener(notifyListeners);
    await _prefs.setString('cloud.group.$uid', groupId);
    // 背景小工具不持有登入狀態；雲端模式先要求開啟 App，避免寫到訪客紀錄。
    await _prefs.setBool('cloud.widgetOpenApp', true);
    notifyListeners();
    if (importGuest) await workspace.importGuest(_profile, _log);
    unawaited(workspace.refresh());
  }

  Future<void> useLocal() async {
    _generation++;
    cloud?.dispose();
    cloud = null;
    if (account.userId != null) await _prefs.remove('cloud.group.${account.userId}');
    await _prefs.setBool('cloud.widgetOpenApp', false);
    notifyListeners();
  }

  Future<void> importLocalRecords() async => cloud?.importGuest(_profile, _log);
  Challenge challengeFor(Player player) =>
      cloud?.challengeFor(player.profile) ?? challengeStarting(player.profile.startDate ?? officialStart);

  bool get pendingAccountStep => !isSetUp && (_prefs.getBool('setupPendingAccount') ?? false);
  String get setupNoticedDraft => _prefs.getString('setupNoticedDraft') ?? '';

  /// OAuth 在 Web 會離開頁面，先保存教學內容，回來停在最後一步。
  Future<void> saveSetupDraft(Profile profile, String noticed) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString('setupNoticedDraft', noticed);
    await _prefs.setBool('setupPendingAccount', true);
  }

  bool _setupDone = false;
  Profile _profile = const Profile();
  ActivityLog _log = ActivityLog();

  /// 我今天幫誰加油過，格式是「日期|playerId」。
  final Set<String> _myCheers = {};
  DateTime? _previewDate;

  /// 教學（Setup）走完了沒。
  bool get isSetUp => _setupDone;
  Profile get profile => cloud?.profile ?? _profile;

  /// 這個人的挑戰：從開跑日（開始用 App 那天）到 12/31。還沒設定時用主辦的 10/9。
  Challenge get challenge => cloud?.challengeFor(profile) ?? challengeStarting(_profile.startDate ?? officialStart);

  /// Demo 用：把「今天」換成其他日期，方便看挑戰中、結束後的畫面。
  DateTime? get previewDate => _previewDate;

  DateTime get today => cloud?.today ?? _previewDate ?? dateOnly(_clock());
  ChallengePhase get phase => challenge.phaseOn(today);
  int get weekNumber => challenge.weekNumber(challenge.clamp(today));

  /// Nourish 的三選至少二：擁有者決定不鎖定（2026-10-10），隨時可以在「重新設定」改。
  bool get nourishLocked => false;

  /// 開跑日過了（或就是今天）就不能再改。
  bool get startLocked => profile.startDate != null && !today.isBefore(profile.startDate!);

  Player get me => Player(id: cloud?.remote.userId ?? 'me', profile: profile, log: cloud?.log ?? _log, isMe: true);

  /// 本機模式只有本人；真實群組資料接好前不回傳示範隊友。
  List<Player> get players => [me, ...?cloud?.peers];

  Player? playerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  List<ChallengeItem> get items => activeItems(profile);
  ItemProgress progress(ChallengeItem item) => progressOf(item, cloud?.log ?? _log, challenge, today);
  WeekSummary get summary => summarize(items, cloud?.log ?? _log, challenge, today);
  Entry entryOn(ChallengeItem item, DateTime date) => (cloud?.log ?? _log).entryOn(item, date);
  bool dayComplete(DateTime date) => me.dayComplete(challenge, date);

  /// 只能記錄挑戰期間、而且不是未來的日子。
  bool canLogOn(DateTime date) => challenge.contains(date) && !date.isAfter(today);

  Future<void> finishSetup(Profile profile) async {
    if (cloud != null) {
      await cloud!.saveProfile(profile);
      return;
    }
    _profile = Profile(
      name: profile.name.trim().isEmpty ? Profile.defaultName : profile.name.trim(),
      avatar: profile.avatar,
      startDate: startLocked ? _profile.startDate : (profile.startDate ?? today),
      weightKg: profile.weightKg,
      nourishChoice: nourishLocked ? _profile.nourishChoice : profile.nourishChoice,
      bedtime: profile.bedtime,
      wakeTime: profile.wakeTime,
      book: profile.book.trim(),
      week1Move: profile.week1Move.trim(),
      week1Obstacle: profile.week1Obstacle.trim(),
    );
    _setupDone = true;
    notifyListeners();
    await _prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
    await _prefs.setBool(_setupKey, true);
    await _prefs.remove('setupPendingAccount');
    await _prefs.remove('setupNoticedDraft');
  }

  /// 打勾的項目（每天的）：切換 [date] 那一期。
  Future<void> toggle(ChallengeItem item, DateTime date) async {
    if (!canLogOn(date)) return;
    if (cloud != null) {
      await cloud!.toggle(item, date);
      return;
    }
    final done = _log.entryOn(item, date).isDone;
    _log.set(item, date, done ? Entry.empty : const Entry(amount: 1));
    await _saveLog();
  }

  /// 累計的項目（有氧分鐘、肌力次數）：設定 [date] 那天的數量。
  Future<void> setAmount(ChallengeItem item, DateTime date, int amount) async {
    if (!canLogOn(date)) return;
    if (cloud != null) {
      await cloud!.toggle(item, date, amount: amount.clamp(0, item.id == 'aerobic' ? 1440 : 100));
      return;
    }
    _log.set(item, date, Entry(amount: max(0, amount)));
    await _saveLog();
  }

  /// 桌面小工具上的鍵帽：按一下今天就打卡，再按一下取消。
  /// 累計的項目一次記 [ChallengeItem.quickAmount]（例如有氧 30 分鐘）。
  Future<void> quickToggle(ChallengeItem item) async {
    if (item.kind == ItemKind.weeklyAmount) {
      final done = entryOn(item, today).isDone;
      await setAmount(item, today, done ? 0 : item.quickAmount);
    } else {
      await toggle(item, today);
    }
  }

  /// 寫字的項目：今天注意到的事、每週回顧。
  Future<void> saveNotes(ChallengeItem item, DateTime date, List<String> notes) async {
    if (!canLogOn(date)) return;
    if (cloud != null) {
      await cloud!.saveNotes(item, date, notes);
      return;
    }
    final trimmed = [for (final note in notes) note.trim()];
    if (listEquals(trimmed, _log.entryOn(item, date).notes)) return;
    _log.set(item, date, Entry(amount: trimmed.where((note) => note.isNotEmpty).length, notes: trimmed));
    await _saveLog();
  }

  /// 每週照片：[ref] 是 [PhotoStore] 給的檔案路徑或 data URL；傳 null 就是拿掉。
  Future<void> setPhoto(DateTime date, String? ref) async {
    final photo = itemById('photo');
    if (!canLogOn(date)) return;
    if (cloud != null) {
      await cloud!.setPhoto(date, ref);
      return;
    }
    final old = _log.entryOn(photo, date).notes.firstOrNull;
    _log.set(photo, date, ref == null ? Entry.empty : Entry(amount: 1, notes: [ref]));
    await _saveLog();
    if (old != null && old != ref) await PhotoStore.delete(old);
  }

  /// 某一週的照片參照（沒有就 null）。
  String? photoOn(DateTime date) {
    final entry = entryOn(itemById('photo'), date);
    return entry.isDone ? entry.notes.firstOrNull : null;
  }

  /// 我今天幫 [playerId] 加油（或慶祝）過了沒。
  bool hasCheered(String playerId) =>
      cloud?.cheers.any(
        (c) => c['from_user_id'] == me.id && c['to_user_id'] == playerId && c['cheer_date'] == dateKey(today),
      ) ??
      false;

  /// 幫隊友加油：今天還沒完成的是「集氣」，已經完成的是「慶祝」。一天一次。
  Future<void> cheer(String playerId) async {
    final workspace = cloud;
    final player = playerById(playerId);
    if (workspace == null || player == null || player.isMe) return;
    await workspace.remote.cheer(playerId, player.dayComplete(challengeFor(player), today));
    await workspace.refresh();
  }

  /// 群組同步接好前不顯示示範加油。
  int cheersFor(String playerId) {
    return cloud?.cheers.where((c) => c['to_user_id'] == playerId && c['cheer_date'] == dateKey(today)).length ?? 0;
  }

  /// 傳 null 就是用真正的今天。
  Future<void> setPreviewDate(DateTime? date) async {
    _previewDate = date == null ? null : dateOnly(date);
    notifyListeners();
    await _prefs.setString(_previewDateKey, date == null ? _realToday : dateKey(date));
  }

  /// 開發用：清掉所有資料，從教學重新開始。
  Future<void> resetAll() async {
    await useLocal();
    _setupDone = false;
    _profile = const Profile();
    _log = ActivityLog();
    _myCheers.clear();
    notifyListeners();
    await _prefs.remove(_setupKey);
    await _prefs.remove(_profileKey);
    await _prefs.remove(_logKey);
    await _prefs.remove(_cheersKey);
    await _prefs.remove('setupPendingAccount');
    await _prefs.remove('setupNoticedDraft');
  }

  /// 重新讀一次本機資料：桌面小工具會在背景直接打卡，回到 App 時要同步。
  Future<void> reload() async {
    if (cloud != null) {
      await cloud!.readLocal();
      await cloud!.refresh();
      return;
    }
    await _prefs.reload();
    _myCheers.clear();
    _restore();
    notifyListeners();
  }

  Future<void> _saveLog() async {
    notifyListeners();
    await _prefs.setString(_logKey, jsonEncode(_log.toJson()));
  }

  void _restore() {
    try {
      _setupDone = _prefs.getBool(_setupKey) ?? false;
      final profile = _prefs.getString(_profileKey);
      if (profile != null) _profile = Profile.fromJson(jsonDecode(profile) as Map<String, dynamic>);
      final log = _prefs.getString(_logKey);
      if (log != null) _log = ActivityLog.fromJson(jsonDecode(log) as Map<String, dynamic>);
      _myCheers.addAll(_prefs.getStringList(_cheersKey) ?? const []);

      final preview = _prefs.getString(_previewDateKey);
      if (preview != null && preview != _realToday) _previewDate = parseDateKey(preview);
    } on FormatException {
      // 本機資料壞掉時就從頭開始，不要讓 App 打不開。
    }
  }

  @override
  void dispose() {
    _generation++;
    account.removeListener(_accountChanged);
    cloud?.dispose();
    super.dispose();
  }
}
