import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/challenge_store.dart';
import 'screens/home_screen.dart';
import 'screens/setup_tutorial.dart';
import 'widgets/pixel_ui.dart';

const _zhTW = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW');

class OmiApp extends StatelessWidget {
  const OmiApp({super.key, required this.store, this.navigatorKey});

  final ChallengeStore store;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: store.challenge.title,
      debugShowCheckedModeBanner: false,
      theme: _buildPixelTheme(),
      locale: _zhTW,
      supportedLocales: const [_zhTW, Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // 還沒走完設定教學就先看教學，走完才進首頁。
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.isSetUp ? HomeScreen(store: store) : SetupTutorial(store: store),
      ),
    );
  }
}

/// 像素風主題：方角、粗黑框，色系參考「電扶梯走左邊」網站。
ThemeData _buildPixelTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: PixelColors.ink,
    onPrimary: PixelColors.yellow,
    primaryContainer: PixelColors.yellow,
    onPrimaryContainer: PixelColors.ink,
    secondary: PixelColors.yellow,
    onSecondary: PixelColors.ink,
    tertiary: PixelColors.orange,
    onTertiary: PixelColors.ink,
    error: Color(0xFFC62828),
    onError: Colors.white,
    surface: PixelColors.paper,
    onSurface: PixelColors.ink,
    onSurfaceVariant: PixelColors.muted,
    surfaceContainerHighest: PixelColors.sand,
    outline: PixelColors.ink,
    outlineVariant: PixelColors.sand,
  );
  const inkSide = BorderSide(color: PixelColors.ink, width: 3);
  const square = RoundedRectangleBorder();
  const inkBox = RoundedRectangleBorder(side: inkSide);
  const fieldBorder = OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: inkSide);

  final base = ThemeData(colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: PixelColors.background,
    textTheme: base.textTheme.apply(bodyColor: PixelColors.ink, displayColor: PixelColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: PixelColors.ink,
      foregroundColor: PixelColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PixelColors.paper,
      surfaceTintColor: Colors.transparent,
      shape: Border(top: inkSide),
      showDragHandle: true,
      dragHandleColor: PixelColors.ink,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: PixelColors.orange, width: 3),
      ),
      floatingLabelStyle: TextStyle(color: PixelColors.ink, fontWeight: FontWeight.w800),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PixelColors.ink,
      contentTextStyle: TextStyle(color: PixelColors.yellow, fontWeight: FontWeight.w800),
      shape: square,
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: PixelColors.paper, shape: inkBox),
    dialogTheme: const DialogThemeData(backgroundColor: PixelColors.paper, shape: inkBox),
    datePickerTheme: const DatePickerThemeData(backgroundColor: PixelColors.paper, shape: inkBox),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: PixelColors.paper,
      shape: inkBox,
      hourMinuteShape: square,
      dayPeriodShape: square,
      dialHandColor: PixelColors.ink,
      dialBackgroundColor: PixelColors.sand,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: PixelColors.ink),
      textStyle: TextStyle(color: PixelColors.yellow),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PixelColors.ink,
        shape: square,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: square)),
  );
}
