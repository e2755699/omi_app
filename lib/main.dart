import 'package:flutter/material.dart';

import 'app.dart';
import 'data/challenge_store.dart';
import 'data/home_widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ChallengeStore.load();
  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(OmiApp(store: store, navigatorKey: navigatorKey));
  await HomeWidgetBridge(store, navigatorKey).start();
}
