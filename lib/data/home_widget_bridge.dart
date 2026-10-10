import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';
import '../models/rules.dart';
import '../screens/daily_record_screen.dart';
import 'challenge_store.dart';

const _provider = 'com.omi.omi_app.CheerWidgetProvider';
const _iosWidget = 'CheerWidget';
const _appGroup = 'group.com.jacklope.omiApp';

/// 桌面小工具最多放幾顆鍵帽（CheerWidgetProvider.kt 裡也是 8 個）。
const _maxKeys = 8;

/// iOS 的小工具資料放在 App Group；Android 不需要。
Future<void> _setUpAppGroup() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  await HomeWidget.setAppGroupId(_appGroup);
}

/// 小工具上的鍵帽被按下時，在背景的 isolate 執行：直接幫今天打卡，再更新小工具。
@pragma('vm:entry-point')
Future<void> homeWidgetInteraction(Uri? uri) async {
  if (uri?.host != 'toggle') return;
  await _setUpAppGroup();
  final id = uri!.queryParameters['item'];
  final item = challengeItems.where((item) => item.id == id).firstOrNull;
  if (item == null) return;

  // 背景和 App 是不同的 isolate，先重新讀本機資料，才不會蓋掉 App 裡的紀錄。
  await (await SharedPreferences.getInstance()).reload();
  if ((await SharedPreferences.getInstance()).getBool('cloud.widgetOpenApp') ?? false) return;
  final store = await ChallengeStore.load();
  if (!store.isSetUp || store.phase != ChallengePhase.ongoing) return;
  await store.quickToggle(item);
  await syncHomeWidget(store);
}

/// 把最新的狀態寫給桌面小工具（CheerWidgetProvider.kt）。
Future<void> syncHomeWidget(ChallengeStore store) async {
  final challenge = store.challenge;
  final phase = store.phase;
  final summary = store.summary;
  final cheers = store.cheersFor(store.me.id);
  final enabled = store.isSetUp && !store.isCloud && phase == ChallengePhase.ongoing;
  await (await SharedPreferences.getInstance()).setBool('cloud.widgetOpenApp', store.isCloud);
  final keys = [
    for (final item in store.items)
      if (item.pillar != Pillar.reflect) item,
  ].take(_maxKeys).toList();
  final done = keys.where((item) => store.entryOn(item, store.today).isDone).length;

  final data = <String, String>{
    'day_text': switch (phase) {
      ChallengePhase.notStarted => 'D-${daysBetween(store.today, challenge.start)}',
      ChallengePhase.ongoing => 'DAY ${challenge.dayNumber(store.today)}/${challenge.totalDays}',
      ChallengePhase.finished => 'CLEAR!',
    },
    'cheers_text': !enabled || cheers == 0
        ? ''
        : summary.todayComplete
        ? '🎉 $cheers 人幫你慶祝'
        : '📣 $cheers 人幫你加油',
    'keys_enabled': enabled ? '1' : '0',
    'message_text': store.isCloud
        ? '打開 App 記錄與同步群組'
        : !store.isSetUp
        ? '打開 App 完成設定'
        : phase == ChallengePhase.notStarted
        ? '${formatShortDate(challenge.start)} 開始打卡，準備好了嗎？'
        : '挑戰完成 🎉 辛苦了！',
    'footer_text': enabled ? '今天 $done/${keys.length} 項 · ✏️ 寫 Reflect ›' : '打開 App ›',
    'key_count': '${keys.length}',
    for (final (i, item) in keys.indexed) ...{
      'key_${i}_id': item.id,
      'key_${i}_pillar': item.pillar.name,
      'key_${i}_on': store.entryOn(item, store.today).isDone ? '1' : '0',
      'key_${i}_label': '${item.emoji}\n${store.entryOn(item, store.today).isDone ? '✓' : ''}${item.shortTitle}',
    },
  };

  try {
    await _setUpAppGroup();
    for (final MapEntry(:key, :value) in data.entries) {
      await HomeWidget.saveWidgetData<String>(key, value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _provider, iOSName: _iosWidget);
  } on PlatformException catch (error) {
    debugPrint('更新桌面小工具失敗：$error');
  }
}

/// App 這邊：資料一變就更新小工具；回到 App 時讀回小工具在背景打的卡；
/// 從小工具的「寫 Reflect」點進來就打開每日打卡。
class HomeWidgetBridge {
  HomeWidgetBridge(this.store, this.navigatorKey);

  final ChallengeStore store;
  final GlobalKey<NavigatorState> navigatorKey;
  Timer? _debounce;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start() async {
    if (!supported) return;
    await _setUpAppGroup();
    await HomeWidget.registerInteractivityCallback(homeWidgetInteraction);
    store.addListener(_scheduleSync);
    // 會自己掛在 WidgetsBinding 上，整個 App 期間都有效。
    HomeWidget.widgetClicked.listen(_open);
    await syncHomeWidget(store);
    _open(await HomeWidget.initiallyLaunchedFromHomeWidget());
  }

  /// 請桌面程式把小工具加上去。不支援的話回傳 false。
  static Future<bool> requestPin() async {
    // iOS 無法用程式把小工具加到桌面。
    if (!supported || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(qualifiedAndroidName: _provider);
      return true;
    } on PlatformException {
      return false;
    }
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => syncHomeWidget(store));
  }

  void _open(Uri? uri) {
    if (uri?.host != 'checkin') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null || !store.isSetUp || store.phase != ChallengePhase.ongoing) return;
      navigator
        ..popUntil((route) => route.isFirst)
        ..push(MaterialPageRoute<void>(builder: (_) => DailyRecordScreen(store: store)));
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
