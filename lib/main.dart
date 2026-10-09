import 'package:flutter/material.dart';

import 'app.dart';
import 'data/challenge_store.dart';
import 'data/account_controller.dart';
import 'data/home_widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final account = await AccountController.initialize();
  final store = await ChallengeStore.load(account: account);
  final navigatorKey = GlobalKey<NavigatorState>();
  var visibleScope = store.dataScope;
  store.addListener(() {
    if (visibleScope == store.dataScope) return;
    visibleScope = store.dataScope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  });
  runApp(OmiApp(store: store, navigatorKey: navigatorKey));
  AppLifecycleListener(onResume: store.reload);
  await HomeWidgetBridge(store, navigatorKey).start();
}
