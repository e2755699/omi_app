import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi_app/app.dart';
import 'package:omi_app/data/challenge_store.dart';
import 'package:omi_app/models/activity_log.dart';
import 'package:omi_app/models/challenge.dart';
import 'package:omi_app/models/profile.dart';
import 'package:omi_app/models/progress.dart';
import 'package:omi_app/models/rules.dart';
import 'package:omi_app/widgets/pixel_text.dart';

const _profile = Profile(
  name: '阿明',
  weightKg: 60,
  nourishChoice: {'produce', 'water'},
  bedtime: 23 * 60,
  wakeTime: 7 * 60,
);

Finder _pixelText(String text) => find.byWidgetPredicate((w) => w is PixelText && w.text == text);

/// 畫面是邊捲邊建的，要先往下捲到看得到才點得到。
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _scrollTo(tester, find.text(text));
  await tester.tap(find.text(text).hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Challenge', () {
    test('10/9 → 1/16 共 100 天、15 週，第一週只有 3 天', () {
      final challenge = defaultChallenge;
      expect(challenge.totalDays, 100);
      expect(challenge.weekNumber(DateTime(2026, 10, 9)), 1);
      expect(challenge.weekNumber(DateTime(2026, 10, 12)), 2);
      expect(challenge.totalWeeks, 15);
      expect(challenge.weekOf(challenge.start).where(challenge.contains).length, 3);
      expect(challenge.weekOf(challenge.end).where(challenge.contains).length, 6);
    });
  });

  group('能量槽', () {
    final challenge = defaultChallenge;

    test('有氧第一週目標照比例：150 × 3/7 → 65 分鐘', () {
      final aerobic = itemById('aerobic');
      final log = ActivityLog()
        ..set(aerobic, DateTime(2026, 10, 9), const Entry(amount: 30))
        ..set(aerobic, DateTime(2026, 10, 10), const Entry(amount: 40));
      final progress = progressOf(aerobic, log, challenge, DateTime(2026, 10, 11));
      expect(progress.target, 65);
      expect(progress.value, 70);
      expect(progress.percent, 100);
    });

    test('每天的項目一格一天，不在挑戰期間的格子是 null', () {
      final reading = itemById('reading');
      final log = ActivityLog()..set(reading, DateTime(2026, 10, 9), const Entry(amount: 1));
      final progress = progressOf(reading, log, challenge, DateTime(2026, 10, 10));
      expect(progress.cells, [null, null, null, null, true, false, false]);
      expect(progress.value, 1);
      expect(progress.target, 3);
      expect(progress.doneNow, isFalse);
    });

    test('每週回顧：回答幾題就亮幾格', () {
      final review = itemById('review');
      final log = ActivityLog()..set(review, DateTime(2026, 11, 7), const Entry(amount: 2, notes: ['a', 'b', '']));
      final progress = progressOf(review, log, challenge, DateTime(2026, 11, 8));
      expect(progress.cells, [true, true, false]);
      expect(progress.doneNow, isFalse);
    });

    test('依設定算出個人目標，Nourish 只算選了的兩項', () {
      expect(itemTarget(itemById('water'), _profile), '每天 1800 ml 白開水');
      expect(itemTarget(itemById('schedule'), _profile), '23:00 睡、07:00 起（±60 分）');
      expect(activeItems(_profile).map((item) => item.id), isNot(contains('protein')));
      expect(activeItems(_profile), hasLength(12));
    });

    test('連續打卡天數：今天還沒打卡時算到昨天', () {
      final reading = itemById('reading');
      final log = ActivityLog();
      for (final day in [1, 2, 3, 5, 6]) {
        log.set(reading, challenge.dateOfDay(day), const Entry(amount: 1));
      }
      final player = Player(id: 'p', profile: _profile, log: log);
      expect(player.checkInStreak(challenge, challenge.dateOfDay(7)), 2);
      expect(player.checkInStreak(challenge, challenge.dateOfDay(8)), 0);
    });
  });

  group('Demo 日期', () {
    test('挑戰還沒開始時預設假裝是第 30 天，可以改回真的今天', () async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6));
      expect(store.today, DateTime(2026, 11, 7));
      await store.setPreviewDate(null);
      final reloaded = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6));
      expect(reloaded.today, DateTime(2026, 10, 6));
    });
  });

  group('App', () {
    testWidgets('第一次打開是設定教學，走完產生儀表板', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6, 9), demoDay: null);
      await tester.pumpWidget(OmiApp(store: store));
      // STEP 0 標題畫面有一直在動的動畫，不能用 pumpAndSettle。
      await tester.pump();
      expect(_pixelText('OMI'), findsOneWidget);
      expect(find.text('～ 快樂的 Σίσυφος ～'), findsOneWidget);
      await tester.tap(find.text('開始挑戰'));
      await tester.pumpAndSettle();
      expect(_pixelText('STEP 1/8'), findsOneWidget);

      await _tapText(tester, '下一步');
      // 沒填名字不能往下走。
      await _tapText(tester, '下一步');
      expect(_pixelText('STEP 2/8'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '阿明');
      await tester.pumpAndSettle();
      await _tapText(tester, '下一步');
      await _tapText(tester, '下一步');

      // NOURISH：3 選 2，選了飲水要填體重。
      expect(_pixelText('STEP 4/8'), findsOneWidget);
      await _tapText(tester, '蔬果');
      await _tapText(tester, '飲水');
      await tester.enterText(find.widgetWithText(TextField, '你的體重'), '60');
      await tester.pumpAndSettle();
      expect(find.text('🎯 每天 1800 ml 白開水'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await _tapText(tester, '下一步');
      }
      await _tapText(tester, '進入我的儀表板');

      expect(store.isSetUp, isTrue);
      expect(store.profile.name, '阿明');
      expect(store.profile.nourishChoice, {'produce', 'water'});
      expect(find.text('各項挑戰'), findsOneWidget);
      await _scrollTo(tester, find.text('10/9 開始打卡'));
      expect(find.text('10/9 開始打卡'), findsOneWidget);
    });

    testWidgets('每日打卡：按鍵帽就是已打卡，Reflect 會存起來', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();
      expect(_pixelText('30/100'), findsOneWidget);

      await _tapText(tester, '每日打卡');
      await _tapText(tester, '閱讀');
      expect(store.entryOn(itemById('reading'), store.today).isDone, isTrue);

      await _scrollTo(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField).first, '午餐後散步');
      await _tapText(tester, '完成打卡 ✓');

      expect(find.text('今天已打卡 · 點我編輯'), findsOneWidget);
      expect(store.entryOn(itemById('noticed'), store.today).notes, ['午餐後散步']);
      // 11/2–11/8 這週，閱讀 1/7 天。
      expect(store.progress(itemById('reading')).value, 1);
      expect(store.progress(itemById('reading')).target, 7);

      final reloaded = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 21), demoDay: null);
      expect(reloaded.entryOn(itemById('reading'), reloaded.today).isDone, isTrue);

      // 讓 SnackBar 的計時器跑完。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('在隊友卡片上集氣加油或慶祝', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();

      final before = store.cheersFor('an');
      final cheer = find.byWidgetPredicate((w) => w is Text && (w.data == '📣 集氣加油' || w.data == '🎉 慶祝'));
      await _scrollTo(tester, cheer);
      await tester.tap(cheer.hitTestable().first);
      await tester.pumpAndSettle();

      expect(store.hasCheered('an'), isTrue);
      expect(store.cheersFor('an'), before + 1);
      expect(find.textContaining('你幫 小安'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
