import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi_app/app.dart';
import 'package:omi_app/data/challenge_store.dart';
import 'package:omi_app/data/wish_bank.dart';
import 'package:omi_app/models/activity_log.dart';
import 'package:omi_app/models/challenge.dart';
import 'package:omi_app/models/profile.dart';
import 'package:omi_app/models/rules.dart';
import 'package:omi_app/models/stars.dart';
import 'package:omi_app/screens/wish_shop_screen.dart';
import 'package:omi_app/widgets/keycap.dart';
import 'package:omi_app/widgets/pixel_sprite.dart';
import 'package:omi_app/widgets/pixel_text.dart';
import 'package:omi_app/widgets/pixel_ui.dart';
import 'package:omi_app/widgets/star_counter.dart';

const _profile = Profile(
  name: '阿明',
  weightKg: 60,
  nourishChoice: {'produce', 'water'},
  bedtime: 23 * 60,
  wakeTime: 7 * 60,
);

final _challenge = defaultChallenge;
final _items = activeItems(_profile);
final _daily = [for (final item in _items) if (item.kind == ItemKind.daily) item];

DateTime _day(int day) => _challenge.dateOfDay(day);

void _completeDay(ActivityLog log, DateTime date) {
  for (final item in _daily) {
    log.set(item, date, const Entry(amount: 1));
  }
}

StarLedger _stars(ActivityLog log, DateTime today) =>
    computeStars(log: log, items: _items, challenge: _challenge, today: today);

Finder _pixelText(String text) => find.byWidgetPredicate((w) => w is PixelText && w.text == text);

/// 某個願望卡片上的「兌換」鍵帽。
Finder _redeemKey(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(PixelBox)).first,
      matching: find.widgetWithText(Keycap, '兌換'),
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('星星規則', () {
    test('沒有紀錄、或挑戰還沒開始，就沒有星星', () {
      final log = ActivityLog();
      expect(_stars(log, _day(30)).total, 0);
      _completeDay(log, _day(1));
      expect(_stars(log, DateTime(2026, 10, 1)).events, isEmpty);
    });

    test('全勤日：每日項目全部完成才 +1', () {
      final log = ActivityLog();
      _completeDay(log, _day(1));
      // 第 2 天少了 0 酒精。
      for (final item in _daily.where((item) => item.id != 'alcohol')) {
        log.set(item, _day(2), const Entry(amount: 1));
      }
      final ledger = _stars(log, _day(30));
      expect(ledger.events, hasLength(1));
      expect(ledger.events.single.rule, StarRule.perfectDay);
      expect(ledger.events.single.date, DateTime(2026, 10, 9));
      expect(ledger.total, 1);
    });

    test('只算到今天：未來的紀錄不算', () {
      final log = ActivityLog();
      _completeDay(log, _day(31));
      expect(_stars(log, _day(30)).total, 0);
      expect(_stars(log, DateTime(2026, 11, 8, 21)).total, 1);
    });

    test('連續打卡每滿 7 天 +5，中斷就重新算', () {
      final strength = itemById('strength');
      final log = ActivityLog();
      for (var day = 1; day <= 14; day++) {
        log.set(strength, _day(day), const Entry(amount: 1));
      }
      expect(
        [for (final e in _stars(log, _day(30)).events) (e.date, e.reason, e.stars)],
        [(_day(7), '連續打卡 7 天', 5), (_day(14), '連續打卡 14 天', 5)],
      );

      // 第 10 天沒打卡：第 7 天拿一次，接下來要到第 17 天才又滿 7 天。
      log.set(strength, _day(10), Entry.empty);
      for (var day = 15; day <= 17; day++) {
        log.set(strength, _day(day), const Entry(amount: 1));
      }
      expect([for (final e in _stars(log, _day(30)).events) e.date], [_day(7), _day(17)]);
    });

    test('能量滿格：MOVE 一週內充到 100%，記在充滿的那天', () {
      final aerobic = itemById('aerobic');
      final strength = itemById('strength');
      final log = ActivityLog()
        ..set(aerobic, DateTime(2026, 10, 12), const Entry(amount: 60))
        ..set(strength, DateTime(2026, 10, 13), const Entry(amount: 1))
        ..set(aerobic, DateTime(2026, 10, 14), const Entry(amount: 60))
        ..set(strength, DateTime(2026, 10, 15), const Entry(amount: 1))
        ..set(aerobic, DateTime(2026, 10, 16), const Entry(amount: 30));

      expect(_stars(log, DateTime(2026, 10, 15)).total, 0);
      final ledger = _stars(log, DateTime(2026, 10, 16));
      expect(ledger.events.single.rule, StarRule.fullPillar);
      expect(ledger.events.single.pillar, Pillar.move);
      expect(ledger.events.single.date, DateTime(2026, 10, 16));
      expect(ledger.events.single.reason, '第 2 週 MOVE 能量 100%');
      // 之後的日子看，同一週也只算一次。
      expect(_stars(log, _day(30)).total, 3);
    });

    test('第一週只有 3 天，滿格的目標照比例（有氧 65 分、肌力 1 次）', () {
      final log = ActivityLog()
        ..set(itemById('aerobic'), DateTime(2026, 10, 10), const Entry(amount: 65))
        ..set(itemById('strength'), DateTime(2026, 10, 11), const Entry(amount: 1));
      final ledger = _stars(log, _day(30));
      expect(ledger.events.single.reason, '第 1 週 MOVE 能量 100%');
      expect(ledger.events.single.date, DateTime(2026, 10, 11));
    });

    test('一整週全做到：全勤 7 天＋連續 7 天＋四類滿格，同一天依規則排序', () {
      final log = ActivityLog();
      for (var day = 4; day <= 10; day++) {
        _completeDay(log, _day(day));
      }
      log
        ..set(itemById('review'), DateTime(2026, 10, 17), const Entry(amount: 3, notes: ['a', 'b', 'c']))
        ..set(itemById('plan'), DateTime(2026, 10, 17), const Entry(amount: 1, notes: ['d']))
        ..set(itemById('photo'), DateTime(2026, 10, 18), const Entry(amount: 1));
      final ledger = _stars(log, _day(30));
      expect(ledger.countOf(StarRule.perfectDay), 7);
      expect(ledger.countOf(StarRule.streak), 1);
      expect(
        [for (final e in ledger.events) if (e.rule == StarRule.fullPillar) e.pillar],
        [Pillar.nourish, Pillar.learn, Pillar.recover, Pillar.reflect],
      );
      expect(ledger.total, 7 + 5 + 4 * 3);
      final lastDay = [for (final e in ledger.events) if (e.date == DateTime(2026, 10, 18)) e.rule];
      expect(lastDay, [StarRule.perfectDay, ...List.filled(4, StarRule.fullPillar), StarRule.streak]);
    });

    test('前 10 天全勤：10 + 5 + 第 1、2 週 NOURISH／LEARN／RECOVER 滿格 18 = 33', () {
      final log = ActivityLog();
      for (var day = 1; day <= 10; day++) {
        _completeDay(log, _day(day));
      }
      final ledger = _stars(log, _day(30));
      expect(ledger.countOf(StarRule.perfectDay), 10);
      expect(ledger.countOf(StarRule.streak), 1);
      expect(ledger.countOf(StarRule.fullPillar), 6);
      expect(ledger.total, 33);
      expect(maxStarsPerWeek, 27);
    });

    test('像素圖每一列一樣寬', () {
      for (final sprite in [pigSprite, starSprite]) {
        expect(sprite.map((row) => row.length).toSet(), hasLength(1));
      }
    });
  });

  group('願望撲滿', () {
    test('第一次打開放 3 個範例願望，只放一次', () async {
      final bank = await WishBank.load();
      expect(bank.wishes.map((w) => (w.emoji, w.title, w.price)), [
        ('👜', '想買的包包', 30),
        ('🍣', '犒賞自己一頓大餐', 20),
        ('💆', '去按摩放鬆', 15),
      ]);
      await bank.removeWish('bag');
      final reloaded = await WishBank.load();
      expect(reloaded.wishes.map((w) => w.id), ['feast', 'massage']);
    });

    test('餘額 = 賺到的 − 花掉的；星星不夠不能兌換', () async {
      final bank = await WishBank.load();
      final feast = bank.wishes.firstWhere((w) => w.id == 'feast');
      expect(bank.balance(12), 12);
      expect(bank.canRedeem(feast, 12), isFalse);
      expect(await bank.redeem(feast, earned: 12, date: DateTime(2026, 11, 7)), isFalse);
      expect(bank.redemptions, isEmpty);

      expect(await bank.redeem(feast, earned: 25, date: DateTime(2026, 11, 7, 20)), isTrue);
      expect(bank.spent, 20);
      expect(bank.balance(25), 5);
      expect(bank.canRedeem(feast, 25), isFalse);
      expect(bank.timesRedeemed('feast'), 1);

      final reloaded = await WishBank.load();
      expect(reloaded.balance(25), 5);
      final redemption = reloaded.redemptions.single;
      expect((redemption.wishId, redemption.date, redemption.stars), ('feast', DateTime(2026, 11, 7), 20));
      // 刪掉願望，兌換紀錄還在、花掉的星星也不會跑回來。
      await reloaded.removeWish('feast');
      expect(reloaded.redemptions.single.title, '犒賞自己一頓大餐');
      expect(reloaded.balance(25), 5);
    });

    test('自己許的願望會存起來；Demo 加碼算進餘額，可以重設', () async {
      final bank = await WishBank.load();
      final wish = await bank.addWish(emoji: '🎧', title: ' 演唱會門票 ', price: 0);
      expect(wish.title, '演唱會門票');
      expect(wish.price, 1);
      final second = await bank.addWish(emoji: '👟', title: '新跑鞋', price: 18);
      expect(second.id, isNot(wish.id));
      await bank.addDemoBonus(20);
      expect(bank.balance(0), 20);

      final reloaded = await WishBank.load();
      expect(reloaded.wishes.map((w) => w.title), ['想買的包包', '犒賞自己一頓大餐', '去按摩放鬆', '演唱會門票', '新跑鞋']);
      expect(reloaded.demoBonus, 20);

      await reloaded.resetDemo();
      expect(reloaded.wishes, hasLength(3));
      expect(reloaded.balance(0), 0);
      expect((await WishBank.load()).wishes, hasLength(3));
    });
  });

  group('願望商城畫面', () {
    testWidgets('首頁星星數 → 撲滿：兌換大餐、許一個新願望', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      for (var day = 1; day <= 10; day++) {
        for (final item in _daily) {
          await store.toggle(item, _day(day));
        }
      }
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(StarCounter), matching: _pixelText('33')), findsOneWidget);

      await tester.tap(find.byType(StarCounter));
      await tester.pumpAndSettle();
      expect(find.byType(WishShopScreen), findsOneWidget);
      expect(_pixelText('33'), findsOneWidget);
      expect(find.text('想買的包包'), findsOneWidget);

      // 兌換大餐：確認 → 慶祝。
      await tester.tap(_redeemKey('犒賞自己一頓大餐'));
      await tester.pumpAndSettle();
      expect(find.text('確定要兌換嗎？'), findsOneWidget);
      await tester.tap(find.text('兌換！'));
      await tester.pumpAndSettle();
      expect(_pixelText('GET!'), findsOneWidget);
      await tester.tap(find.text('好耶！'));
      await tester.pumpAndSettle();

      expect(_pixelText('13'), findsOneWidget);
      expect(find.text('已兌換 ×1'), findsOneWidget);
      // 剩 13 顆，30 顆的包包換不了。
      expect(tester.widget<Keycap>(_redeemKey('想買的包包')).onTap, isNull);
      expect(tester.widget<Keycap>(_redeemKey('去按摩放鬆')).onTap, isNull);

      // 許願：選圖示、寫名字、調價格。
      await tester.tap(find.text('＋ 許願'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎧'));
      await tester.enterText(find.byType(TextField), '演唱會門票');
      await tester.tap(find.text('+5'));
      await tester.pumpAndSettle();
      expect(_pixelText('15'), findsWidgets);
      await tester.ensureVisible(find.text('放進願望商城'));
      await tester.tap(find.text('放進願望商城'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('演唱會門票'));
      expect(find.text('還差 2 顆星'), findsWidgets);
      expect(tester.widget<Keycap>(_redeemKey('演唱會門票')).onTap, isNull);

      final bank = await WishBank.load();
      expect(bank.wishes.last.title, '演唱會門票');
      expect(bank.wishes.last.emoji, '🎧');
      expect(bank.wishes.last.price, 15);
      expect(bank.redemptions.single.title, '犒賞自己一頓大餐');
      expect(bank.redemptions.single.date, DateTime(2026, 11, 7));

      // 回首頁，星星數扣掉花掉的。
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(StarCounter), matching: _pixelText('13')), findsOneWidget);
    });

    testWidgets('沒有星星時兌換鍵是灰的，Demo 加碼後就能換', (tester) async {
      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await tester.pumpWidget(MaterialApp(home: WishShopScreen(store: store)));
      await tester.pumpAndSettle();

      expect(_pixelText('0'), findsOneWidget);
      expect(find.text('賺到 0 顆 · 已兌換 0 顆'), findsOneWidget);
      expect(tester.widget<Keycap>(_redeemKey('去按摩放鬆')).onTap, isNull);

      await tester.tap(find.byTooltip('Demo 工具'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撲滿裡先放 20 顆星（Demo）'));
      await tester.pumpAndSettle();

      expect(find.text('賺到 0 顆＋Demo 20 顆 · 已兌換 0 顆'), findsOneWidget);
      expect(tester.widget<Keycap>(_redeemKey('去按摩放鬆')).onTap, isNotNull);
      expect(tester.widget<Keycap>(_redeemKey('想買的包包')).onTap, isNull);
    });
  });
}
