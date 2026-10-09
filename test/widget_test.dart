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

final _profile = Profile(
  name: '阿明',
  startDate: DateTime(2026, 10, 9),
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
    test('10/9 開跑 → 12/31 剛好 84 天、13 個日曆週，第一週只有 3 天', () {
      final challenge = challengeStarting(DateTime(2026, 10, 9));
      expect(challenge.totalDays, 84);
      expect(challenge.end, DateTime(2026, 12, 31));
      expect(challenge.weekNumber(DateTime(2026, 10, 9)), 1);
      expect(challenge.weekNumber(DateTime(2026, 10, 12)), 2);
      expect(challenge.totalWeeks, 13);
      expect(challenge.weekOf(challenge.start).where(challenge.contains).length, 3);
      expect(challenge.weekOf(challenge.end).where(challenge.contains).length, 4);
    });

    test('10/12（週一）開跑是 81 天、12 個完整週；開始日晚於 12/31 就只剩最後一天', () {
      final monday = challengeStarting(DateTime(2026, 10, 12));
      expect(monday.totalDays, 81);
      expect(monday.totalWeeks, 12);
      expect(nextMonday(DateTime(2026, 10, 9)), DateTime(2026, 10, 12));
      expect(nextMonday(DateTime(2026, 10, 12)), DateTime(2026, 10, 19));
      expect(challengeStarting(DateTime(2027, 1, 5)).totalDays, 1);
    });
  });

  group('能量槽', () {
    final challenge = challengeStarting(DateTime(2026, 10, 9));

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

    test('體重算出蛋白質、飲水目標；沒填就顯示規則；Nourish 只算選了的項目；沒有下週計畫', () {
      expect(itemTarget(itemById('water'), _profile), '每天 1800 ml 白開水');
      expect(itemTarget(itemById('protein'), _profile), '每天 72 g 蛋白質');
      expect(itemTarget(itemById('water'), const Profile()), '每天 30 ml/kg 體重');
      expect(itemTarget(itemById('schedule'), _profile), '23:00 睡、07:00 起（±60 分）');
      expect(activeItems(_profile).map((item) => item.id), isNot(contains('protein')));
      expect(activeItems(_profile).map((item) => item.id), isNot(contains('plan')));
      expect(activeItems(_profile), hasLength(11));
      expect(const Profile(nourishChoice: {'produce', 'water', 'protein'}).nourishReady, isTrue);
      expect(const Profile(nourishChoice: {'produce'}).nourishReady, isFalse);
    });

    test('連續記錄天數：今天還沒打卡時算到昨天；達成天數只算每日項目全完成的日子', () {
      final reading = itemById('reading');
      final log = ActivityLog();
      for (final day in [1, 2, 3, 5, 6]) {
        log.set(reading, challenge.dateOfDay(day), const Entry(amount: 1));
      }
      final player = Player(id: 'p', profile: _profile, log: log);
      expect(player.checkInStreak(challenge, challenge.dateOfDay(7)), 2);
      expect(player.checkInStreak(challenge, challenge.dateOfDay(8)), 0);
      expect(player.completeDays(challenge, challenge.dateOfDay(8)), 0);

      for (final item in activeItems(_profile).where((item) => item.kind == ItemKind.daily)) {
        log.set(item, challenge.dateOfDay(2), const Entry(amount: 1, notes: ['x']));
      }
      expect(player.completeDays(challenge, challenge.dateOfDay(8)), 1);
    });
  });

  group('開跑日', () {
    test('開跑日是設定那天；選下週一的話在那之前還沒開始', () async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 10, 9, 9));
      expect(store.challenge.start, DateTime(2026, 10, 9));
      await store.finishSetup(const Profile(name: 'A', nourishChoice: {'produce', 'water'}, bedtime: 0, wakeTime: 480));
      expect(store.challenge.start, DateTime(2026, 10, 9));
      expect(store.phase, ChallengePhase.ongoing);
      expect(store.startLocked, isTrue);

      SharedPreferences.setMockInitialValues({});
      final later = await ChallengeStore.load(clock: () => DateTime(2026, 10, 9, 9));
      await later.finishSetup(Profile(name: 'B', startDate: DateTime(2026, 10, 12), nourishChoice: {'produce', 'water'}));
      expect(later.phase, ChallengePhase.notStarted);
      expect(later.startLocked, isFalse);
      expect(later.challenge.totalDays, 81);
    });

    test('Demo 日期可以換，也可以改回真的今天', () async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6));
      await store.setPreviewDate(DateTime(2026, 11, 7));
      final reloaded = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6));
      expect(reloaded.today, DateTime(2026, 11, 7));
      await reloaded.setPreviewDate(null);
      final again = await ChallengeStore.load(clock: () => DateTime(2026, 10, 6));
      expect(again.today, DateTime(2026, 10, 6));
    });
  });

  group('App', () {
    testWidgets('第一次打開是設定教學，走完產生儀表板', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 10, 9, 9));
      await tester.pumpWidget(OmiApp(store: store));
      // STEP 0 標題畫面有一直在動的動畫，不能用 pumpAndSettle。
      await tester.pump();
      expect(_pixelText('OMI'), findsOneWidget);
      expect(find.text('～ 快樂的 Σίσυφος ～'), findsOneWidget);
      await tester.tap(find.text('開始挑戰'));
      await tester.pumpAndSettle();
      expect(_pixelText('STEP 1/10'), findsOneWidget);
      expect(_pixelText('84 DAYS'), findsOneWidget);

      await _tapText(tester, '下一步');
      // 沒填名字不能往下走。
      await _tapText(tester, '下一步');
      expect(_pixelText('STEP 2/10'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '阿明');
      await tester.pumpAndSettle();
      await _tapText(tester, '下一步');

      // 決定加入：預設從今天開始，也可以選下週一。
      expect(_pixelText('STEP 3/10'), findsOneWidget);
      expect(find.text('從今天開始'), findsOneWidget);
      expect(find.text('從下週一開始'), findsOneWidget);
      await _tapText(tester, '下一步');

      // MOVE：示範鍵帽可以按。
      await _tapText(tester, '有氧');
      expect(find.text('✓有氧'), findsOneWidget);
      await _tapText(tester, '下一步');

      // NOURISH：三選至少二；選了飲水要填體重，兩個目標都會算出來。
      expect(_pixelText('STEP 5/10'), findsOneWidget);
      await _tapText(tester, '下一步');
      expect(_pixelText('STEP 5/10'), findsOneWidget);
      await _tapText(tester, '蔬果');
      await _tapText(tester, '飲水');
      await tester.enterText(find.widgetWithText(TextField, '你的體重'), '60');
      await tester.pumpAndSettle();
      expect(find.textContaining('每天 1800 ml 白開水'), findsOneWidget);
      expect(find.textContaining('每天 72 g 蛋白質（沒選）'), findsOneWidget);
      await _tapText(tester, '下一步');

      // LEARN：要讀的書。
      await tester.enterText(find.byType(TextField), '薛西弗斯的神話');
      await _tapText(tester, '下一步');
      // RECOVER
      await _tapText(tester, '下一步');
      // REFLECT：點例子就填進去。
      expect(_pixelText('STEP 8/10'), findsOneWidget);
      await _tapText(tester, '今天忘記閱讀');
      await _tapText(tester, '下一步');
      // WEEK 1 計畫
      expect(_pixelText('STEP 9/10'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '一三五晨跑');
      await _tapText(tester, '下一步');
      await _tapText(tester, '進入我的儀表板');

      expect(store.isSetUp, isTrue);
      expect(store.profile.name, '阿明');
      expect(store.profile.nourishChoice, {'produce', 'water'});
      expect(store.profile.weightKg, 60);
      expect(store.profile.book, '薛西弗斯的神話');
      expect(store.profile.week1Move, '一三五晨跑');
      expect(store.challenge.start, DateTime(2026, 10, 9));
      expect(store.challenge.totalDays, 84);
      // 教學裡寫的心得直接算今天的紀錄。
      expect(store.entryOn(itemById('noticed'), store.today).notes, ['今天忘記閱讀']);
      expect(find.text('各項挑戰'), findsOneWidget);
      // 教學裡寫了心得，今天就算已經打過卡。
      await _scrollTo(tester, find.text('今天已打卡 · 點我編輯'));
      expect(find.text('今天已打卡 · 點我編輯'), findsOneWidget);
    });

    testWidgets('每日打卡：按鍵帽就是已打卡，Reflect 會存起來', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9));
      await store.finishSetup(_profile);
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();
      expect(_pixelText('30/84'), findsOneWidget);

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

      final reloaded = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 21));
      expect(reloaded.entryOn(itemById('reading'), reloaded.today).isDone, isTrue);

      // 讓 SnackBar 的計時器跑完。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('本週任務：從首頁進去寫回顧三題', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9));
      await store.finishSetup(_profile);
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();

      await _tapText(tester, '本週任務：回顧三題・一張照片');
      expect(find.text('本週任務'), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), '運動都有做');
      await tester.enterText(fields.at(1), '週三加班');
      await tester.enterText(fields.at(2), '提早排有氧');
      await _tapText(tester, '存好了 ✓');

      expect(store.entryOn(itemById('review'), store.today).notes, ['運動都有做', '週三加班', '提早排有氧']);
      expect(find.text('🔍 回顧 3/3 題'), findsOneWidget);
    });

    testWidgets('在隊友卡片上集氣加油或慶祝', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9));
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
