import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/brag.dart';
import '../../models/rules.dart';
import '../energy_tile.dart';
import '../pixel_text.dart';
import '../pixel_ui.dart';
import '../player_card.dart';
import '../section_title.dart';
import '../sisyphus_scene.dart';
import 'flex_card.dart';
import 'pixel_bits.dart';

const _ray = Color(0xFF26231C);
const _dim = Color(0xFFB8AC90);

/// 還沒到的日子。要跟背景的放射線分得出來。
const _cellOff = Color(0xFF211F1A);

/// 風格一：8-bit 街機的破關畫面。黑底、放射線、閃爍的像素星星、超大像素數字。
class PixelFlexCard extends StatefulWidget {
  const PixelFlexCard({
    super.key,
    required this.template,
    required this.format,
    required this.stats,
    this.animate = true,
  });

  final FlexTemplate template;
  final FlexFormat format;
  final BragStats stats;
  final bool animate;

  @override
  State<PixelFlexCard> createState() => _PixelFlexCardState();
}

class _PixelFlexCardState extends State<PixelFlexCard> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PixelFlexCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!widget.animate) {
      _clock.value = 0;
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        // 不動的時候固定顯示「亮」的那一格，存出來的圖才有字。
        final blink = !widget.animate || (t * 6).floor().isEven;
        final hero = _Hero(template: widget.template, stats: widget.stats, blink: blink, compact: widget.format != FlexFormat.story);
        return switch (widget.format) {
          FlexFormat.story => _StoryLayout(stats: widget.stats, template: widget.template, t: t, hero: hero),
          FlexFormat.post => _PostLayout(stats: widget.stats, template: widget.template, t: t, hero: hero),
          FlexFormat.sticker => _StickerLayout(stats: widget.stats, template: widget.template, hero: hero),
        };
      },
    );
  }
}

/// 限動：上面留給 IG 的進度條、下面留給回覆列，重點放中間。
class _StoryLayout extends StatelessWidget {
  const _StoryLayout({required this.stats, required this.template, required this.t, required this.hero});

  final BragStats stats;
  final FlexTemplate template;
  final double t;
  final Widget hero;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _Backdrop(t: t, center: const Offset(180, 250))),
        const Positioned(left: 0, right: 0, bottom: 0, child: SisyphusScene(height: 84)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(stats: stats),
              const SizedBox(height: 16),
              Expanded(child: hero),
              const SizedBox(height: 14),
              _PlayerStrip(stats: stats, template: template),
              // 留給下面的薛西弗斯（頭上的愛心會往上冒）。
              const SizedBox(height: 108),
            ],
          ),
        ),
        const Positioned(right: 12, bottom: 8, child: PixelText('#OMI100', dot: 2)),
      ],
    );
  }
}

class _PostLayout extends StatelessWidget {
  const _PostLayout({required this.stats, required this.template, required this.t, required this.hero});

  final BragStats stats;
  final FlexTemplate template;
  final double t;
  final Widget hero;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _Backdrop(t: t, center: const Offset(180, 190))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(stats: stats),
              const SizedBox(height: 10),
              Expanded(child: hero),
              const SizedBox(height: 10),
              _PlayerStrip(stats: stats, template: template),
            ],
          ),
        ),
      ],
    );
  }
}

/// 透明貼紙：只有一個像素對話框，貼在自己的照片上。
class _StickerLayout extends StatelessWidget {
  const _StickerLayout({required this.stats, required this.template, required this.hero});

  final BragStats stats;
  final FlexTemplate template;
  final Widget hero;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 10),
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: PixelColors.ink,
          shape: PixelBorder(width: 4, color: PixelColors.yellow),
          shadows: [BoxShadow(color: PixelColors.orange, offset: Offset(6, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(stats: stats, label: false),
              const SizedBox(height: 8),
              Expanded(child: hero),
              const SizedBox(height: 8),
              _PlayerStrip(stats: stats, template: template, small: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.stats, this.label = true});

  final BragStats stats;

  /// 窄的貼紙放不下「100 天挑戰」，只留 OMI 和天數。
  final bool label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PixelText('OMI', dot: 4, color: PixelColors.yellow),
        const SizedBox(width: 8),
        Expanded(
          child: label
              ? const Text(
                  '100 天挑戰',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(color: PixelColors.paper, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                )
              : const SizedBox(),
        ),
        PixelTag('DAY ${stats.dayNumber}/${stats.totalDays}'),
      ],
    );
  }
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({required this.stats, required this.template, this.small = false});

  final BragStats stats;
  final FlexTemplate template;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final profile = stats.player.profile;
    // 名次只在好看的時候秀（前半段），不然秀評價就好。
    final brag = stats.teamSize > 1 && stats.beatPercent >= 50
        ? '贏過 ${stats.beatPercent}% 隊友'
        : '總達成率 ${stats.overallPercent}%';
    return Row(
      children: [
        PlayerAvatar(profile: profile, size: small ? 32 : 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: PixelColors.paper, fontSize: small ? 14 : 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                brag,
                maxLines: 1,
                style: const TextStyle(color: _dim, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        // 能力值那張卡中間已經有 RANK 了。
        if (template != FlexTemplate.stats)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
            decoration: BoxDecoration(color: PixelColors.orange, border: Border.all(color: PixelColors.yellow, width: 2)),
            child: PixelText('RANK ${gradeOf(stats.overall)}', dot: 2),
          ),
      ],
    );
  }
}

/// 卡片中間的主角：依 [template] 炫耀不同的東西。
class _Hero extends StatelessWidget {
  const _Hero({required this.template, required this.stats, required this.blink, required this.compact});

  final FlexTemplate template;
  final BragStats stats;
  final bool blink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (template) {
      FlexTemplate.streak => _StreakHero(stats: stats, blink: blink, compact: compact),
      FlexTemplate.mvp => _MvpHero(stats: stats, blink: blink, compact: compact),
      FlexTemplate.map => _MapHero(stats: stats, blink: blink, compact: compact),
      FlexTemplate.stats => _StatsHero(stats: stats, compact: compact),
    };
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.stats, required this.blink, required this.compact});

  final BragStats stats;
  final bool blink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final record = stats.streak > 0 && stats.streak >= stats.bestStreak;
    // 最近 14 天有沒有打卡。
    final recent = stats.days.sublist(math.max(0, stats.dayNumber - 14), stats.dayNumber);
    return Column(
      children: [
        Opacity(
          opacity: blink ? 1 : 0,
          child: PixelText(record ? 'NEW RECORD!' : 'COMBO!', dot: compact ? 3 : 4, color: PixelColors.orange),
        ),
        SizedBox(height: compact ? 6 : 12),
        Expanded(
          flex: 3,
          child: FittedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const PixelSprite(flameSprite, unit: 6),
                const SizedBox(width: 12),
                ShadowPixelText('${stats.streak}', dot: 18),
                const SizedBox(width: 12),
                const PixelSprite(flameSprite, unit: 6),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        const PixelText('DAY STREAK', dot: 3, color: PixelColors.paper),
        SizedBox(height: compact ? 8 : 14),
        Text(
          '連續打卡 ${stats.streak} 天',
          style: TextStyle(color: PixelColors.paper, fontSize: compact ? 20 : 26, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        SizedBox(height: compact ? 8 : 12),
        _TitleBadge(text: '🏆 ${streakTitle(stats.streak)}'),
        if (!compact) ...[
          const Spacer(),
          Row(
            children: [
              const PixelText('LAST 14 DAYS', dot: 2, color: _dim),
              const Spacer(),
              PixelText('${recent.where((day) => (day ?? 0) > 0).length}/${recent.length}', dot: 2, color: _dim),
            ],
          ),
          const SizedBox(height: 6),
          PixelCellsBar(
            cells: [for (final day in recent) (day ?? 0) > 0],
            color: PixelColors.orange,
            emptyColor: PixelColors.night,
            frameColor: Colors.black,
            height: 18,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatChip(tag: 'BEST', value: '${stats.bestStreak}', label: '最長連續')),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(tag: 'PERFECT', value: '${stats.perfectDays}', label: '完美日')),
              const SizedBox(width: 8),
              Expanded(child: _StatChip(tag: 'CHEER', value: '${stats.cheers}', label: '今天的應援')),
            ],
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _MvpHero extends StatelessWidget {
  const _MvpHero({required this.stats, required this.blink, required this.compact});

  final BragStats stats;
  final bool blink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final best = stats.bestItem;
    final color = pillarColor(best.item.pillar);
    final recent = best.periods.sublist(math.max(0, best.periods.length - 14));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: blink ? 1 : 0.35, child: const PixelText('★', dot: 3, color: PixelColors.yellow)),
            const SizedBox(width: 10),
            ShadowPixelText('MVP', dot: compact ? 5 : 7, color: PixelColors.orange, shadow: pixelRed),
            const SizedBox(width: 10),
            Opacity(opacity: blink ? 1 : 0.35, child: const PixelText('★', dot: 3, color: PixelColors.yellow)),
          ],
        ),
        SizedBox(height: compact ? 6 : 10),
        Expanded(
          child: FittedBox(
            child: Column(
              children: [
                const PixelSprite(crownSprite, unit: 4),
                const SizedBox(height: 4),
                Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: color,
                    shape: const PixelBorder(width: 4, color: PixelColors.paper),
                    shadows: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
                  ),
                  child: Text(best.item.emoji, style: const TextStyle(fontSize: 58)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 12),
        Text(
          best.item.title,
          style: TextStyle(color: PixelColors.paper, fontSize: compact ? 20 : 26, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        _TitleBadge(text: '👑 ${itemTitle(best.item)}'),
        SizedBox(height: compact ? 10 : 12),
        ShadowPixelText('${best.percent}%', dot: compact ? 5 : 8),
        const SizedBox(height: 6),
        Text(
          '${best.bragLine} · 連續 ${best.streak} ${best.periodUnit}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: PixelColors.paper, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        if (!compact && recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          PixelCellsBar(cells: recent, color: color, emptyColor: PixelColors.night, frameColor: Colors.black, height: 16),
        ],
      ],
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({required this.stats, required this.blink, required this.compact});

  final BragStats stats;
  final bool blink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final checked = stats.days.where((day) => (day ?? 0) > 0).length;
    return Column(
      children: [
        Row(
          children: [
            const PixelText('100 DAY MAP', dot: 3, color: PixelColors.yellow),
            const Spacer(),
            Text('百日戰績', style: TextStyle(color: PixelColors.paper, fontSize: compact ? 14 : 16, fontWeight: FontWeight.w900)),
          ],
        ),
        SizedBox(height: compact ? 8 : 14),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _DayGrid(days: stats.days, today: stats.dayNumber, blink: blink),
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: PixelColors.yellow, label: '完美'),
            SizedBox(width: 12),
            _Legend(color: PixelColors.orange, label: '過半'),
            SizedBox(width: 12),
            _Legend(color: Color(0xFF8A5A12), label: '有打卡'),
            SizedBox(width: 12),
            _Legend(color: PixelColors.night, label: '沒打卡'),
          ],
        ),
        SizedBox(height: compact ? 8 : 14),
        Row(
          children: [
            Expanded(child: _StatChip(tag: 'PERFECT', value: '${stats.perfectDays}', label: '完美日')),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(tag: 'CHECK-IN', value: '$checked/${stats.dayNumber}', label: '打卡天數')),
            if (!compact) ...[
              const SizedBox(width: 8),
              Expanded(child: _StatChip(tag: 'BEST', value: '${stats.bestStreak}', label: '最長連續')),
            ],
          ],
        ),
      ],
    );
  }
}

/// 10×10 的百日格子，像 GitHub 的綠格子。
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days, required this.today, required this.blink});

  final List<double?> days;
  final int today;
  final bool blink;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DayGridPainter(days: days, today: today, blink: blink));
  }
}

class _DayGridPainter extends CustomPainter {
  _DayGridPainter({required this.days, required this.today, required this.blink});

  final List<double?> days;
  final int today;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 10;
    final rows = (days.length / columns).ceil();
    final gap = size.width * 0.012;
    final cell = (size.width - gap * (columns - 1)) / columns;
    final paint = Paint()..isAntiAlias = false;
    // 黑底，格子才不會跟背景的放射線混在一起。
    canvas.drawRect(Offset.zero & size, paint..color = Colors.black);
    for (var i = 0; i < days.length; i++) {
      final x = (i % columns) * (cell + gap);
      final y = (i ~/ columns) * (cell + gap);
      if (y + cell > size.height + 0.5 || i ~/ columns >= rows) break;
      final value = days[i];
      final day = i + 1;
      paint.color = switch (value) {
        null when day == today => blink ? PixelColors.paper : PixelColors.night,
        null => _cellOff,
        >= 1 => PixelColors.yellow,
        >= 0.5 => PixelColors.orange,
        > 0 => const Color(0xFF8A5A12),
        _ => PixelColors.night,
      };
      canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      // 完美日加一個亮點，像像素寶石。
      if ((value ?? 0) >= 1) {
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(x + cell * 0.18, y + cell * 0.18, cell * 0.2, cell * 0.2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DayGridPainter old) => old.days != days || old.today != today || old.blink != blink;
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.stats, required this.compact});

  final BragStats stats;
  final bool compact;

  static const _abbr = {
    Pillar.move: 'STR',
    Pillar.nourish: 'VIT',
    Pillar.learn: 'INT',
    Pillar.recover: 'REC',
    Pillar.reflect: 'WIS',
  };

  @override
  Widget build(BuildContext context) {
    final rates = stats.pillarRates;
    final grade = gradeOf(stats.overall);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const PixelTag('STATUS'),
            const Spacer(),
            PixelText('LV ${stats.dayNumber}', dot: 3, color: PixelColors.yellow),
          ],
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          flexTitle(FlexTemplate.stats, stats),
          textAlign: TextAlign.center,
          style: TextStyle(color: PixelColors.paper, fontSize: compact ? 22 : 28, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        SizedBox(height: compact ? 8 : 14),
        // 經典 RPG 的狀態視窗：黑底、白色缺角框。
        DecoratedBox(
          decoration: const ShapeDecoration(color: Colors.black, shape: PixelBorder(width: 3, color: PixelColors.paper)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, compact ? 8 : 12, 12, compact ? 8 : 12),
            child: Column(
              children: [
                for (final pillar in Pillar.values) ...[
                  if (pillar != Pillar.values.first) SizedBox(height: compact ? 6 : 10),
                  Row(
                    children: [
                      SizedBox(width: 48, child: PixelText(_abbr[pillar]!, dot: 2.5, color: pillarColor(pillar))),
                      SizedBox(
                        width: 30,
                        child: Text(
                          pillar.label,
                          style: const TextStyle(color: PixelColors.paper, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: PixelProgressBar(
                          value: rates[pillar] ?? 0,
                          color: pillarColor(pillar),
                          segments: 10,
                          height: compact ? 12 : 16,
                          emptyColor: PixelColors.night,
                          frameColor: PixelColors.night,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: PixelText('${((rates[pillar] ?? 0) * 99).round()}', dot: 2.5, color: PixelColors.paper),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PixelText('RANK', dot: 3, color: PixelColors.paper),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: PixelColors.yellow, border: Border.all(color: PixelColors.orange, width: 3)),
              child: PixelText(grade, dot: compact ? 5 : 7),
            ),
            const SizedBox(width: 12),
            Text(
              '總達成率\n${stats.overallPercent}%',
              style: const TextStyle(color: PixelColors.paper, fontSize: 13, height: 1.3, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      decoration: const ShapeDecoration(
        color: PixelColors.yellow,
        shape: PixelBorder(width: 3, color: PixelColors.ink),
        shadows: [BoxShadow(color: PixelColors.orange, offset: Offset(4, 4))],
      ),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.tag, required this.value, required this.label});

  final String tag;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: const ShapeDecoration(color: Colors.black, shape: PixelBorder(width: 2, color: PixelColors.night)),
      child: Column(
        children: [
          PixelText(tag, dot: 1.5, color: _dim),
          const SizedBox(height: 5),
          FittedBox(child: PixelText(value, dot: 3.5, color: PixelColors.yellow)),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, style: const TextStyle(color: PixelColors.paper, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _dim, fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// 背景：黑底＋慢慢轉的放射線＋閃爍的像素星星＋掃描線。
class _Backdrop extends CustomPainter {
  _Backdrop({required this.t, required this.center});

  final double t;
  final Offset center;

  static const _rays = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, paint..color = PixelColors.ink);

    // 放射線（漫畫的集中線），整圈慢慢轉。
    final reach = size.longestSide * 1.5;
    final step = 2 * math.pi / _rays;
    final spin = t * step * 2;
    paint.color = _ray;
    for (var i = 0; i < _rays; i += 2) {
      final a = i * step + spin;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + reach * math.cos(a), center.dy + reach * math.sin(a))
          ..lineTo(center.dx + reach * math.cos(a + step), center.dy + reach * math.sin(a + step))
          ..close(),
        paint,
      );
    }

    // 像素星星：位置固定，輪流閃。
    final random = math.Random(7);
    const unit = 3.0;
    for (var i = 0; i < 26; i++) {
      final x = (random.nextDouble() * size.width / unit).floorToDouble() * unit;
      final y = (random.nextDouble() * size.height * 0.85 / unit).floorToDouble() * unit;
      final color = [PixelColors.yellow, PixelColors.paper, PixelColors.orange][i % 3];
      final phase = (t * 3 + i * 0.37) % 1;
      if (phase > 0.75) continue;
      paint.color = color;
      final big = i % 4 == 0 && phase < 0.4;
      canvas.drawRect(Rect.fromLTWH(x, y, unit, unit), paint);
      if (big || i % 4 != 0) {
        canvas.drawRect(Rect.fromLTWH(x - unit, y, unit, unit), paint);
        canvas.drawRect(Rect.fromLTWH(x + unit, y, unit, unit), paint);
        canvas.drawRect(Rect.fromLTWH(x, y - unit, unit, unit), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + unit, unit, unit), paint);
      }
    }

    // CRT 掃描線。
    paint.color = Colors.black.withValues(alpha: 0.22);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_Backdrop old) => old.t != t || old.center != center;
}
