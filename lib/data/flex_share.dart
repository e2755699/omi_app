import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../models/brag.dart';
import '../widgets/flex/flex_card.dart';

/// 存圖的倍率：限動 360×640 → 1080×1920。用整數倍，像素風的格子才不會糊。
const flexPixelRatio = 3.0;

/// 把畫面上的炫耀卡存成 PNG。
Future<Uint8List?> captureFlexCard(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: flexPixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// 叫出系統的分享選單（IG、Threads、LINE、存到相簿…）。網頁版不支援分享的瀏覽器會改成下載。
Future<ShareResult> shareFlexImage(Uint8List png, {required String fileName, Rect? origin}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: [fileName],
      title: 'Omi 炫耀卡',
      sharePositionOrigin: origin,
    ),
  );
}

/// 給 Discord、LINE 貼的文字版，像 Wordle 的格子：不用圖片也看得出戰績。
String flexShareText(FlexTemplate template, BragStats stats) {
  final header = 'Omi 100 天挑戰 · DAY ${stats.dayNumber}/${stats.totalDays}';
  final lines = switch (template) {
    FlexTemplate.streak => [
        '🔥 $header',
        '連續打卡 ${stats.streak} 天！稱號「${streakTitle(stats.streak)}」',
        '最近 14 天 ${_recent(stats)}',
        '完美日 ${stats.perfectDays} 天 · 最長連續 ${stats.bestStreak} 天',
      ],
    FlexTemplate.mvp => [
        '👑 $header',
        '我的 MVP：${stats.bestItem.item.emoji} ${stats.bestItem.item.title} ${stats.bestItem.percent}%',
        '${stats.bestItem.bragLine} · 連續 ${stats.bestItem.streak} ${stats.bestItem.periodUnit}',
        '稱號「${itemTitle(stats.bestItem.item)}」',
      ],
    FlexTemplate.map => [
        '🗓️ $header',
        ..._grid(stats),
        '🟩完美 🟨過半 🟧有打卡 ⬛沒打卡',
        '完美日 ${stats.perfectDays} 天 · 最長連續 ${stats.bestStreak} 天',
      ],
    FlexTemplate.stats => [
        '📊 $header',
        'LV ${stats.dayNumber}「${flexTitle(FlexTemplate.stats, stats)}」RANK ${gradeOf(stats.overall)}',
        for (final MapEntry(key: pillar, value: rate) in stats.pillarRates.entries)
          '${pillar.emoji} ${pillar.label} ${_bar(rate)} ${(rate * 99).round()}',
      ],
  };
  return [...lines, '#Omi快樂的薛西弗斯'].join('\n');
}

String _square(double? day) => switch (day) {
      null => '⬜',
      >= 1 => '🟩',
      >= 0.5 => '🟨',
      > 0 => '🟧',
      _ => '⬛',
    };

String _recent(BragStats stats) {
  final from = (stats.dayNumber - 14).clamp(0, stats.dayNumber);
  return [for (final day in stats.days.sublist(from, stats.dayNumber)) (day ?? 0) > 0 ? '🟩' : '⬛'].join();
}

/// 一行 10 天，只列到今天那一行。
List<String> _grid(BragStats stats) {
  final rows = (stats.dayNumber / 10).ceil();
  return [
    for (var row = 0; row < rows; row++) [for (var i = row * 10; i < row * 10 + 10; i++) _square(stats.days[i])].join(),
  ];
}

String _bar(double rate) {
  final filled = (rate * 10).round();
  return '▰' * filled + '▱' * (10 - filled);
}
