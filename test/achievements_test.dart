import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi_app/app.dart';
import 'package:omi_app/data/badge_claims.dart';
import 'package:omi_app/data/challenge_store.dart';
import 'package:omi_app/models/achievements.dart';
import 'package:omi_app/models/activity_log.dart';
import 'package:omi_app/models/challenge.dart';
import 'package:omi_app/models/profile.dart';
import 'package:omi_app/models/progress.dart';
import 'package:omi_app/models/rules.dart';
import 'package:omi_app/screens/badge_detail_sheet.dart';
import 'package:omi_app/screens/badges_screen.dart';
import 'package:omi_app/widgets/badge_medal.dart';
import 'package:omi_app/widgets/pixel_text.dart';

const _profile = Profile(
  name: '阿明',
  weightKg: 60,
  nourishChoice: {'produce', 'water'},
  bedtime: 23 * 60,
  wakeTime: 7 * 60,
);

final _challenge = defaultChallenge;

Player _player(ActivityLog log) => Player(id: 'me', profile: _profile, log: log, isMe: true);

AchievementStatus _status(ActivityLog log, String id, {required int day}) =>
    evaluateAchievements(_player(log), _challenge, _challenge.dateOfDay(day))
        .firstWhere((status) => status.achievement.id == id);

/// 在挑戰的第 [days] 天把 [itemId] 打勾。
ActivityLog _logDays(String itemId, Iterable<int> days, [ActivityLog? log]) {
  final item = itemById(itemId);
  final result = log ?? ActivityLog();
  for (final day in days) {
    result.set(item, _challenge.dateOfDay(day), const Entry(amount: 1));
  }
  return result;
}

Iterable<int> _range(int from, int to) => [for (var day = from; day <= to; day++) day];

Finder _pixelText(String text) => find.byWidgetPredicate((w) => w is PixelText && w.text == text);

/// 首頁是邊捲邊建的，要先往下捲到看得到才點得到。
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

/// 捲到看得到再點（底部面板裡也可以用）。
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.hitTestable().first);
  await tester.pumpAndSettle();
}

/// 從首頁的「我的獎章」打開獎章牆。
Future<void> _openBadges(WidgetTester tester, ChallengeStore store) async {
  await tester.pumpWidget(OmiApp(store: store));
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.text('我的獎章'));
  await tester.tap(find.text('我的獎章').hitTestable().first);
  await tester.pumpAndSettle();
  expect(find.byType(BadgesScreen), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('獎章規則', () {
    test('共 10 個獎章，id 不重複', () {
      expect(achievements, hasLength(10));
      expect(achievements.map((a) => a.id).toSet(), hasLength(10));
      expect(achievementById('streak_7').title, '連續打卡 7 天');
    });

    test('沒有紀錄：全部沒解鎖，完成 100 天顯示已經過了幾天', () {
      final statuses = evaluateAchievements(_player(ActivityLog()), _challenge, _challenge.dateOfDay(30));
      expect(statuses.where((s) => s.unlocked), isEmpty);
      final finish = statuses.firstWhere((s) => s.achievement.id == 'finish_100');
      expect(finish.current, 30);
      expect(finish.target, 100);
      expect(finish.progressLabel, '30/100 天');
    });

    test('挑戰開始前什麼都不算', () {
      final log = _logDays('reading', [1]);
      final statuses = evaluateAchievements(_player(log), _challenge, DateTime(2026, 10, 1));
      expect(statuses.where((s) => s.unlocked), isEmpty);
      expect(statuses.every((s) => s.current == 0), isTrue);
    });

    test('第一次打卡：記錄任何一項就解鎖', () {
      final log = _logDays('reading', [3]);
      expect(_status(log, 'first_checkin', day: 2).unlocked, isFalse);
      expect(_status(log, 'first_checkin', day: 3).unlocked, isTrue);

      // 運動量也算打卡。
      final aerobic = ActivityLog()..set(itemById('aerobic'), _challenge.dateOfDay(1), const Entry(amount: 30));
      expect(_status(aerobic, 'first_checkin', day: 1).unlocked, isTrue);
    });

    test('連續打卡：中斷之後最佳紀錄還在，還沒到的日子不算', () {
      final log = _logDays('reading', [..._range(1, 7), 9, 10, 11]);
      final streak7 = _status(log, 'streak_7', day: 20);
      expect(streak7.unlocked, isTrue);
      expect(_player(log).checkInStreak(_challenge, _challenge.dateOfDay(20)), 0);
      expect(_status(log, 'streak_30', day: 20).progressLabel, '7/30 天');

      // 第 5 天時只連續了 5 天。
      final early = _status(log, 'streak_7', day: 5);
      expect(early.unlocked, isFalse);
      expect(early.current, 5);
    });

    test('連續打卡 30 天', () {
      final log = _logDays('sleep', _range(1, 30));
      expect(_status(log, 'streak_30', day: 29).unlocked, isFalse);
      expect(_status(log, 'streak_30', day: 30).unlocked, isTrue);
    });

    test('完美的一天：同一天完成所有每日項目', () {
      final log = ActivityLog();
      final daily = [for (final item in activeItems(_profile)) if (item.kind == ItemKind.daily) item];
      expect(daily, hasLength(7));
      for (final item in daily.skip(1)) {
        log.set(item, _challenge.dateOfDay(2), const Entry(amount: 1));
      }
      final almost = _status(log, 'perfect_day', day: 10);
      expect(almost.unlocked, isFalse);
      expect(almost.progressLabel, '6/7 項');

      log.set(daily.first, _challenge.dateOfDay(2), const Entry(amount: 1));
      expect(_status(log, 'perfect_day', day: 10).unlocked, isTrue);
    });

    test('MOVE 滿格週：同一週有氧和肌力都達標，週中達標也算', () {
      final aerobic = itemById('aerobic');
      final strength = itemById('strength');
      // 第 2 週是 10/12–10/18，7 天都在挑戰期間：有氧 150 分鐘、肌力 2 次。
      final log = ActivityLog()..set(aerobic, DateTime(2026, 10, 12), const Entry(amount: 150));
      final half = evaluateAchievements(_player(log), _challenge, DateTime(2026, 10, 25))
          .firstWhere((s) => s.achievement.id == 'move_week');
      expect(half.current, 50);
      expect(half.progressLabel, '50%');
      expect(half.unlocked, isFalse);

      log
        ..set(strength, DateTime(2026, 10, 13), const Entry(amount: 1))
        ..set(strength, DateTime(2026, 10, 14), const Entry(amount: 1));
      final full = evaluateAchievements(_player(log), _challenge, DateTime(2026, 10, 14))
          .firstWhere((s) => s.achievement.id == 'move_week');
      expect(full.unlocked, isTrue);
    });

    test('每週回顧：3 題都寫完才算', () {
      final review = itemById('review');
      final log = ActivityLog()..set(review, DateTime(2026, 10, 17), const Entry(amount: 2, notes: ['a', 'b', '']));
      expect(_status(log, 'review_first', day: 20).unlocked, isFalse);

      log.set(review, DateTime(2026, 10, 17), const Entry(amount: 3, notes: ['a', 'b', 'c']));
      expect(_status(log, 'review_first', day: 20).unlocked, isTrue);
      // 那一週還沒到的時候不算。
      expect(_status(log, 'review_first', day: 3).unlocked, isFalse);
    });

    test('累積天數：0 酒精、閱讀 30 天，好眠 21 天（不用連續）', () {
      final odd = [for (var day = 1; day <= 60; day += 2) day];
      final log = _logDays('alcohol', odd);
      _logDays('reading', odd, log);
      _logDays('sleep', odd.take(21), log);

      expect(_status(log, 'sober_30', day: 58).progressLabel, '29/30 天');
      expect(_status(log, 'sober_30', day: 59).unlocked, isTrue);
      expect(_status(log, 'reading_30', day: 59).unlocked, isTrue);
      expect(_status(log, 'sleep_21', day: 59).unlocked, isTrue);
      expect(_status(log, 'streak_7', day: 59).unlocked, isFalse);
    });

    test('完成 100 天：最後一天也打卡才解鎖，之前進度最多 99', () {
      final log = _logDays('reading', [1]);
      final notYet = _status(log, 'finish_100', day: 100);
      expect(notYet.unlocked, isFalse);
      expect(notYet.current, 99);

      _logDays('reading', [100], log);
      expect(_status(log, 'finish_100', day: 100).unlocked, isTrue);
      // 挑戰結束之後還是解鎖的。
      final after = evaluateAchievements(_player(log), _challenge, DateTime(2027, 2, 1));
      expect(after.firstWhere((s) => s.achievement.id == 'finish_100').unlocked, isTrue);
    });

    test('同樣的資料算兩次結果一樣', () {
      final log = _logDays('reading', _range(1, 12));
      _logDays('alcohol', _range(3, 20), log);
      List<(String, int, bool)> snapshot() => [
            for (final s in evaluateAchievements(_player(log), _challenge, _challenge.dateOfDay(25)))
              (s.achievement.id, s.current, s.unlocked),
          ];
      expect(snapshot(), snapshot());
    });
  });

  group('獎章圖案', () {
    test('每個獎章都是 20×15 格；沒解鎖的看不到本體的顏色', () {
      for (final achievement in achievements) {
        final look = achievement.look;
        final unlocked = medalPixels(look);
        final locked = medalPixels(look, locked: true);
        expect(unlocked, hasLength(BadgeMedal.rows));
        expect(unlocked.every((row) => row.length == BadgeMedal.columns), isTrue);
        expect(unlocked.expand((row) => row), contains(Color(look.face)));
        expect(locked.expand((row) => row), isNot(contains(Color(look.face))));
      }
    });
  });

  group('實體獎章申請', () {
    test('只有解鎖的獎章可以申請，狀態存在 badges. 開頭的 key', () async {
      final claims = await BadgeClaims.load();
      final locked = AchievementStatus(achievement: achievementById('streak_30'), current: 3, target: 30);
      expect(await claims.request(locked, BadgeForm.charm, DateTime(2026, 11, 7)), isFalse);
      expect(claims.count, 0);

      final unlocked = AchievementStatus(achievement: achievementById('first_checkin'), current: 1, target: 1);
      expect(await claims.request(unlocked, BadgeForm.charm, DateTime(2026, 11, 7, 21)), isTrue);
      // 同一個獎章不能重複申請。
      expect(await claims.request(unlocked, BadgeForm.display, DateTime(2026, 11, 8)), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), everyElement(startsWith('badges.')));

      final reloaded = await BadgeClaims.load();
      expect(reloaded.claimOf('first_checkin')?.form, BadgeForm.charm);
      expect(reloaded.claimOf('first_checkin')?.requestedOn, DateTime(2026, 11, 7));

      await reloaded.cancel('first_checkin');
      expect((await BadgeClaims.load()).claimOf('first_checkin'), isNull);
    });

    test('本機資料壞掉就當作沒申請過', () async {
      SharedPreferences.setMockInitialValues({BadgeClaims.storageKey: '{oops'});
      expect((await BadgeClaims.load()).count, 0);
      SharedPreferences.setMockInitialValues({
        BadgeClaims.storageKey: '{"a":{"form":"nope","on":"2026-11-07"},"b":{"form":"patch","on":"x"}}',
      });
      expect((await BadgeClaims.load()).count, 0);
    });
  });

  group('獎章畫面', () {
    testWidgets('首頁點「我的獎章」→ 解鎖的獎章選款式、領取實體獎章', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await store.toggle(itemById('reading'), store.today);

      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('我的獎章'));
      expect(_pixelText('1/10'), findsOneWidget);
      expect(find.text('下一個：完美的一天 · 1/7 項'), findsOneWidget);
      await tester.tap(find.text('我的獎章').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.byType(BadgesScreen), findsOneWidget);
      expect(_pixelText('1/10'), findsOneWidget);

      await _tapVisible(tester, find.text('第一次打卡'));
      expect(find.byType(BadgeDetailSheet), findsOneWidget);
      expect(find.text('已解鎖！'), findsOneWidget);
      expect(find.text('選一種款式'), findsOneWidget);

      await _tapVisible(tester, find.text('魔鬼氈臂章'));
      expect(find.text('選好了：🧥 魔鬼氈臂章'), findsOneWidget);
      await _tapVisible(tester, find.text('領取實體獎章'));
      expect(find.text('已申請，寄送中（Demo）'), findsOneWidget);
      expect(find.textContaining('款式：🧥 魔鬼氈臂章 · 11/7（六）'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((key) => key.startsWith('badges.')), isNotEmpty);
      final reloaded = await BadgeClaims.load();
      expect(reloaded.claimOf('first_checkin')?.form, BadgeForm.patch);

      // 關掉面板，獎章牆上顯示寄送中。
      Navigator.of(tester.element(find.byType(BadgeDetailSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('📦 寄送中'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('📦 1 個實體獎章寄送中（Demo）'), findsOneWidget);
    });

    testWidgets('還沒解鎖的獎章不能領取', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await _openBadges(tester, store);
      expect(_pixelText('0/10'), findsOneWidget);

      await _tapVisible(tester, find.text('連續打卡 7 天'));
      expect(find.text('還沒解鎖'), findsOneWidget);
      await _tapVisible(tester, find.text('魔鬼氈臂章'));
      await _tapVisible(tester, find.text('🔒 解鎖後才能領取'));
      expect(find.text('已申請，寄送中（Demo）'), findsNothing);
      expect((await BadgeClaims.load()).count, 0);
    });

    testWidgets('可以看隊友的獎章牆，但實體獎章只有本人能領', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await _openBadges(tester, store);

      await _tapVisible(tester, find.text('小安'));
      expect(find.text('小安 的獎章'), findsOneWidget);
      await _tapVisible(tester, find.text('第一次打卡'));
      expect(find.text('這是 小安 的獎章，實體獎章只有本人可以領取。'), findsOneWidget);
      expect(find.text('領取實體獎章'), findsNothing);
    });
  });
}
