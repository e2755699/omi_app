import 'package:flutter/material.dart';

import '../../models/brag.dart';
import 'holo_flex_card.dart';
import 'pixel_flex_card.dart';

/// 炫耀卡的風格。
enum FlexStyle {
  pixel('像素街機', '8-bit 破關畫面'),
  holo('SSR 閃卡', '抽卡遊戲的金光閃卡');

  const FlexStyle(this.label, this.caption);

  final String label;
  final String caption;
}

/// 要炫耀什麼。
enum FlexTemplate {
  streak('連續打卡', '🔥'),
  mvp('最強項目', '👑'),
  map('百日戰績', '🗓️'),
  stats('能力值', '📊');

  const FlexTemplate(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// 圖片的尺寸：邏輯像素，存成圖片時放大 3 倍（限動是 1080×1920）。
enum FlexFormat {
  story('限動 9:16', Size(360, 640)),
  post('貼文 4:5', Size(360, 450)),
  sticker('透明貼紙', Size(300, 420));

  const FlexFormat(this.label, this.size);

  final String label;
  final Size size;
}

/// 稀有度：數字越亮眼，卡片越稀有。
enum Rarity { n, r, sr, ssr, ur }

extension RarityLabel on Rarity {
  String get label => name.toUpperCase();
}

/// 這張卡片在炫耀的數字有多稀有。
Rarity rarityOf(FlexTemplate template, BragStats stats) {
  Rarity byStreak(int days) => switch (days) {
        >= 30 => Rarity.ur,
        >= 14 => Rarity.ssr,
        >= 7 => Rarity.sr,
        >= 3 => Rarity.r,
        _ => Rarity.n,
      };
  Rarity byRate(double rate) => switch (rate) {
        >= 0.9 => Rarity.ur,
        >= 0.75 => Rarity.ssr,
        >= 0.6 => Rarity.sr,
        >= 0.4 => Rarity.r,
        _ => Rarity.n,
      };
  return switch (template) {
    FlexTemplate.streak => byStreak(stats.streak),
    FlexTemplate.mvp => byRate(stats.bestItem.score),
    FlexTemplate.map => byRate(stats.dailyAverage),
    FlexTemplate.stats => byRate(stats.overall),
  };
}

/// 卡片上的稱號。
String flexTitle(FlexTemplate template, BragStats stats) => switch (template) {
      FlexTemplate.streak => streakTitle(stats.streak),
      FlexTemplate.mvp => itemTitle(stats.bestItem.item),
      FlexTemplate.map => stats.perfectDays >= stats.dayNumber * 0.6 ? '完美主義者' : '百日修行者',
      FlexTemplate.stats => switch (gradeOf(stats.overall)) {
          'S' => '自律魔王',
          'A' => '自律勇者',
          'B' => '自律戰士',
          _ => '自律見習生',
        },
    };

/// 依 [style] 畫出一張炫耀卡。大小固定是 [FlexFormat.size]，外面用 [FittedBox] 縮放。
class FlexCard extends StatelessWidget {
  const FlexCard({
    super.key,
    required this.style,
    required this.template,
    required this.format,
    required this.stats,
    this.animate = true,
  });

  final FlexStyle style;
  final FlexTemplate template;
  final FlexFormat format;
  final BragStats stats;

  /// 預覽時讓星星閃、文字跳；測試或截圖時可以關掉。
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final size = format.size;
    // 背景的放射線畫得比卡片大，要裁掉，不然會蓋到外面的畫面。
    return ClipRect(
      child: SizedBox(
        width: size.width,
        height: size.height,
        // 卡片裡的字固定大小，不跟著系統字級放大，存出來的圖才不會跑版。
        child: MediaQuery.withNoTextScaling(
          child: switch (style) {
            FlexStyle.pixel => PixelFlexCard(template: template, format: format, stats: stats, animate: animate),
            FlexStyle.holo => HoloFlexCard(template: template, format: format, stats: stats, animate: animate),
          },
        ),
      ),
    );
  }
}
