import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omi_app/app.dart';
import 'package:omi_app/data/challenge_store.dart';
import 'package:omi_app/data/flex_share.dart';
import 'package:omi_app/models/activity_log.dart';
import 'package:omi_app/models/brag.dart';
import 'package:omi_app/models/challenge.dart';
import 'package:omi_app/models/profile.dart';
import 'package:omi_app/models/progress.dart';
import 'package:omi_app/models/rules.dart';
import 'package:omi_app/screens/flex_studio_screen.dart';
import 'package:omi_app/widgets/flex/flex_card.dart';

const _profile = Profile(
  name: '阿明',
  weightKg: 60,
  nourishChoice: {'produce', 'water'},
  bedtime: 23 * 60,
  wakeTime: 7 * 60,
);

final _challenge = defaultChallenge;
DateTime _day(int n) => _challenge.dateOfDay(n);

/// 第 1–5 天每日項目全做完、第 6 天全沒做、第 7–8 天只有閱讀；第一週有氧 70 分鐘。
Player _player() {
  final log = ActivityLog();
  final daily = activeItems(_profile).where((item) => item.kind == ItemKind.daily).toList();
  for (var day = 1; day <= 5; day++) {
    for (final item in daily) {
      log.set(item, _day(day), const Entry(amount: 1));
    }
  }
  for (final day in [7, 8]) {
    log.set(itemById('reading'), _day(day), const Entry(amount: 1));
  }
  log.set(itemById('aerobic'), _day(1), const Entry(amount: 70));
  return Player(id: 'me', profile: _profile, log: log, isMe: true);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('炫耀卡戰績', () {
    final stats = BragStats.of(_player(), _challenge, _day(8));

    test('連續、最長連續、完美日', () {
      expect(stats.dayNumber, 8);
      expect(stats.streak, 2);
      expect(stats.bestStreak, 5);
      expect(stats.perfectDays, 5);
    });

    test('每天完成的比例，還沒到的日子是 null', () {
      expect(stats.days.take(5), everyElement(1.0));
      expect(stats.days[5], 0);
      expect(stats.days[7], closeTo(1 / 7, 1e-9));
      expect(stats.days.skip(8), everyElement(isNull));
    });

    test('項目戰績：今天還沒做的不算，有氧以週計並累計分鐘', () {
      ItemStat of(String id) => stats.items.firstWhere((stat) => stat.item.id == id);
      expect(of('reading').done, 7);
      expect(of('reading').total, 8);
      expect(of('reading').streak, 2);
      // 第 8 天還沒戒酒打勾：只算到第 7 天。
      expect(of('alcohol').total, 7);
      expect(of('alcohol').streak, 0);
      expect(of('alcohol').bragLine, '0 滴酒 × 5 天');
      // 第 2 週還沒做滿，只算第 1 週。
      expect(of('aerobic').periods, [true]);
      expect(of('aerobic').bragLine, '有氧累計 70 分鐘');
      expect(stats.bestItem.item.id, 'reading');
    });

    test('只做了 1 週的項目不會贏過做了很多天的項目', () {
      // 有氧 1/1 週 = 100%，但閱讀 7/8 天比較有說服力。
      expect(stats.bestItem.item.id, isNot('aerobic'));
    });

    test('隊上排名', () {
      final lazy = Player(id: 'lazy', profile: _profile, log: ActivityLog());
      final ranked = BragStats.of(_player(), _challenge, _day(8), teammates: [_player(), lazy]);
      expect(ranked.teamRank, 1);
      expect(ranked.teamSize, 2);
      expect(ranked.beatPercent, 100);
      expect(BragStats.of(lazy, _challenge, _day(8), teammates: [_player(), lazy]).teamRank, 2);
    });

    test('挑戰開始前沒有紀錄', () {
      final before = BragStats.of(_player(), _challenge, DateTime(2026, 10, 1));
      expect(before.dayNumber, 0);
      expect(before.hasRecords, isFalse);
      expect(before.days, everyElement(isNull));
    });

    test('稀有度：連續越久越稀有', () {
      expect(rarityOf(FlexTemplate.streak, stats), Rarity.n);
      expect(streakTitle(30), '月度鐵人');
      expect(streakTitle(100), '薛西弗斯本人');
    });

    test('文字版：百日格子一行 10 天，只列到今天那行', () {
      final text = flexShareText(FlexTemplate.map, stats);
      expect(text, contains('🟩🟩🟩🟩🟩⬛🟧🟧⬜⬜'));
      // 只有一行格子（圖例那行不算）。
      expect(text.split('\n').where((line) => line.startsWith('🟩') && !line.contains('完美')).length, 1);
      expect(flexShareText(FlexTemplate.streak, stats), contains('連續打卡 2 天'));
    });
  });

  group('炫耀卡畫面', () {
    testWidgets('所有風格、主題、尺寸都畫得出來，不會跑版', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stats = BragStats.of(_player(), _challenge, _day(8));
      for (final style in FlexStyle.values) {
        for (final template in FlexTemplate.values) {
          for (final format in FlexFormat.values) {
            await tester.pumpWidget(
              MaterialApp(
                home: Center(
                  child: FlexCard(style: style, template: template, format: format, stats: stats, animate: false),
                ),
              ),
            );
            await tester.pump();
            expect(tester.takeException(), isNull, reason: '$style $template $format');
            expect(tester.getSize(find.byType(FlexCard)), format.size);
          }
        }
      }
    });

    testWidgets('限動存成圖片是 1080×1920 的 PNG', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: FlexCard(
                style: FlexStyle.pixel,
                template: FlexTemplate.streak,
                format: FlexFormat.story,
                stats: BragStats.of(_player(), _challenge, _day(8)),
                animate: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await tester.runAsync(() => captureFlexCard(boundary));
      // PNG 的 IHDR：第 16–23 個位元組是寬、高。
      final header = ByteData.sublistView(png!);
      expect(header.getUint32(16), 1080);
      expect(header.getUint32(20), 1920);
    });

    testWidgets('從右上角 🧪 進 Demo Lab，再打開炫耀卡工作室', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final store = await ChallengeStore.load(clock: () => DateTime(2026, 11, 7, 9), demoDay: null);
      await store.finishSetup(_profile);
      await tester.pumpWidget(OmiApp(store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🧪 Demo Lab 專區（炫耀卡）'));
      // 卡片一直在動，不能 pumpAndSettle。
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('炫耀卡 SHOW OFF'), findsOneWidget);
      expect(find.byType(FlexCard), findsNWidgets(2));

      await tester.tap(find.text('SSR 閃卡').first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FlexStudioScreen), findsOneWidget);
      // 自己還沒打卡：預設拿示範隊友的戰績。
      expect(find.textContaining('先用示範隊友'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 離開畫面，讓動畫的計時器停掉。
      await tester.pumpWidget(const SizedBox());
    });
  });
}
