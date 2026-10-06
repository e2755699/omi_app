import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/brag.dart';
import '../../models/rules.dart';
import '../energy_tile.dart';
import 'flex_card.dart';

/// 卡面固定用這個大小設計，再依格式縮放。
const _face = Size(300, 420);

/// 稀有度的金屬色：亮、中、暗。
List<Color> rarityColors(Rarity rarity) => switch (rarity) {
      Rarity.n => const [Color(0xFFE0E0E0), Color(0xFFB0B0B0), Color(0xFF6D6D6D)],
      Rarity.r => const [Color(0xFFB3E5FC), Color(0xFF4FC3F7), Color(0xFF0277BD)],
      Rarity.sr => const [Color(0xFFE9D5FF), Color(0xFFB388FF), Color(0xFF6A1B9A)],
      Rarity.ssr => const [Color(0xFFFFF4C2), Color(0xFFFFCC33), Color(0xFFB8860B)],
      Rarity.ur => const [Color(0xFFFF8A9B), Color(0xFFFFD36E), Color(0xFF63E6BE), Color(0xFF74C0FC), Color(0xFFC59BFF)],
    };

Color rarityGlow(Rarity rarity) => switch (rarity) {
      Rarity.n => const Color(0xFFBDBDBD),
      Rarity.r => const Color(0xFF4FC3F7),
      Rarity.sr => const Color(0xFFB388FF),
      Rarity.ssr => const Color(0xFFFFCC33),
      Rarity.ur => const Color(0xFFFF9FF3),
    };

/// 金屬漸層：UR 是彩虹。
Gradient _metal(Rarity rarity) {
  final colors = rarityColors(rarity);
  if (rarity == Rarity.ur) {
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [...colors, colors.first]);
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [colors[0], colors[1], colors[2], colors[1], colors[0]],
    stops: const [0, 0.3, 0.5, 0.75, 1],
  );
}

String _headline(Rarity rarity) => switch (rarity) {
      Rarity.n => 'N 卡也是卡',
      Rarity.r => 'R 卡入手',
      Rarity.sr => 'SR 出貨！',
      Rarity.ssr => 'SSR 出貨！！',
      Rarity.ur => 'UR 降臨！！！',
    };

String _flavor(FlexTemplate template, BragStats stats) => switch (template) {
      FlexTemplate.streak => '石頭推上山第 ${stats.streak} 次，還是笑著。',
      FlexTemplate.mvp => '「${stats.bestItem.item.title}」這一項，沒人推得比我穩。',
      FlexTemplate.map => '一百格，一格一格點亮。',
      FlexTemplate.stats => '每天都比昨天的自己多一點點。',
    };

/// 風格二：抽卡遊戲的 SSR 閃卡。稀有度依戰績決定，金屬框＋彩虹箔＋流光。
class HoloFlexCard extends StatefulWidget {
  const HoloFlexCard({
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
  State<HoloFlexCard> createState() => _HoloFlexCardState();
}

class _HoloFlexCardState extends State<HoloFlexCard> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HoloFlexCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!widget.animate) {
      // 存圖時把流光停在卡片中間偏上，最好看。
      _clock.value = 0.42;
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
    final rarity = rarityOf(widget.template, widget.stats);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        final card = FittedBox(
          child: SizedBox.fromSize(
            size: _face,
            child: _CardFace(template: widget.template, stats: widget.stats, rarity: rarity, t: t),
          ),
        );
        return switch (widget.format) {
          FlexFormat.story => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _Backdrop(t: t, rarity: rarity, center: const Offset(180, 350))),
                // IG 限動上面約 14% 是進度條和頭像，標題從那之下開始。
                Positioned(
                  left: 0,
                  right: 0,
                  top: 84,
                  child: _Headline(rarity: rarity, stats: widget.stats, big: true),
                ),
                Positioned(left: 40, top: 168, width: 280, height: 392, child: card),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 30,
                  child: Text(
                    'OMI～快樂的 Σίσυφος · 100 天挑戰',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          FlexFormat.post => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _Backdrop(t: t, rarity: rarity, center: const Offset(180, 250))),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 16,
                  child: _Headline(rarity: rarity, stats: widget.stats, big: false),
                ),
                Positioned(left: 54, top: 82, width: 252, height: 353, child: card),
              ],
            ),
          // 留邊給卡片的光暈，去背之後才不會被切成一條直線。
          FlexFormat.sticker => Padding(padding: const EdgeInsets.all(16), child: card),
        };
      },
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.rarity, required this.stats, required this.big});

  final Rarity rarity;
  final BragStats stats;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final glow = rarityGlow(rarity);
    return Column(
      children: [
        _GradientText(
          '✦ ${_headline(rarity)} ✦',
          gradient: _metal(rarity),
          style: TextStyle(
            fontSize: big ? 34 : 24,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
            shadows: [Shadow(color: glow, blurRadius: 18)],
          ),
        ),
        SizedBox(height: big ? 6 : 2),
        Text(
          '抽到一張自律卡 · DAY ${stats.dayNumber}/${stats.totalDays}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: big ? 13 : 11, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ],
    );
  }
}

/// 卡面本體（300×420）。
class _CardFace extends StatelessWidget {
  const _CardFace({required this.template, required this.stats, required this.rarity, required this.t});

  final FlexTemplate template;
  final BragStats stats;
  final Rarity rarity;
  final double t;

  @override
  Widget build(BuildContext context) {
    final glow = rarityGlow(rarity);
    final stars = Rarity.values.indexOf(rarity) + 1;
    return DecoratedBox(
      // 外框：稀有度的金屬色＋光暈。
      decoration: BoxDecoration(
        gradient: _metal(rarity),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1659), Color(0xFF120B2E), Color(0xFF0A0818)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _GradientText(
                          rarity.label,
                          gradient: _metal(rarity),
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            shadows: [Shadow(color: glow, blurRadius: 10)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '★' * stars,
                          style: TextStyle(color: rarityColors(rarity)[1], fontSize: 13, letterSpacing: 1),
                        ),
                        const Spacer(),
                        Text(
                          'No.${stats.dayNumber.toString().padLeft(3, '0')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flexTitle(template, stats),
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [Shadow(color: glow, blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _ArtWindow(rarity: rarity, t: t, child: _Art(template: template, stats: stats, rarity: rarity)),
                    ),
                    const SizedBox(height: 8),
                    _StatStrip(template: template, stats: stats, rarity: rarity),
                    const SizedBox(height: 6),
                    Text(
                      _flavor(template, stats),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    _Owner(stats: stats, rarity: rarity),
                  ],
                ),
              ),
              // 彩虹箔＋流光＋閃點，疊在最上面。
              IgnorePointer(child: CustomPaint(painter: _Foil(t: t, rarity: rarity))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtWindow extends StatelessWidget {
  const _ArtWindow({required this.rarity, required this.t, required this.child});

  final Rarity rarity;
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = rarityColors(rarity);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors[1].withValues(alpha: 0.8), width: 2),
        gradient: RadialGradient(
          radius: 0.9,
          colors: [rarityGlow(rarity).withValues(alpha: 0.45), const Color(0xFF1B0F3D), const Color(0xFF0A0818)],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _Rays(t: t, color: Colors.white.withValues(alpha: 0.07), rays: 16)),
            Padding(padding: const EdgeInsets.all(10), child: child),
          ],
        ),
      ),
    );
  }
}

/// 卡圖：依 [template] 不同。
class _Art extends StatelessWidget {
  const _Art({required this.template, required this.stats, required this.rarity});

  final FlexTemplate template;
  final BragStats stats;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final glow = rarityGlow(rarity);
    switch (template) {
      case FlexTemplate.streak:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 26)),
            Flexible(
              child: FittedBox(
                child: _GradientText(
                  '${stats.streak}',
                gradient: _metal(rarity),
                style: TextStyle(
                  fontSize: 112,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                    letterSpacing: -4,
                    shadows: [Shadow(color: glow, blurRadius: 24)],
                  ),
                ),
              ),
            ),
            const Text(
              'DAYS STREAK',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 2),
            Text(
              '連續打卡 ${stats.streak} 天',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        );
      case FlexTemplate.mvp:
        final best = stats.bestItem;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [glow.withValues(alpha: 0.9), glow.withValues(alpha: 0)]),
                  ),
                  child: Text(best.item.emoji, style: const TextStyle(fontSize: 54)),
                ),
              ),
            ),
            Text(
              best.item.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            FittedBox(
              child: _GradientText(
                '${best.percent}%',
                gradient: _metal(rarity),
                style: TextStyle(
                  fontSize: 56,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  shadows: [Shadow(color: glow, blurRadius: 18)],
                ),
              ),
            ),
            Text(
              best.bragLine,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        );
      case FlexTemplate.map:
        return Column(
          children: [
            Row(
              children: [
                const Text('100 DAYS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const Spacer(),
                Text('完美日 ${stats.perfectDays}', style: TextStyle(color: glow, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(painter: _GlowGrid(days: stats.days, rarity: rarity)),
                ),
              ),
            ),
          ],
        );
      case FlexTemplate.stats:
        return Column(
          children: [
            Expanded(child: CustomPaint(painter: _Radar(rates: stats.pillarRates, rarity: rarity), child: const SizedBox.expand())),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('OVR ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                _GradientText(
                  '${(stats.overall * 99).round()}',
                  gradient: _metal(rarity),
                  style: TextStyle(fontSize: 30, height: 1, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, shadows: [Shadow(color: glow, blurRadius: 12)]),
                ),
              ],
            ),
          ],
        );
    }
  }
}

/// 卡片下方三格數值，像球員卡的能力值。
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.template, required this.stats, required this.rarity});

  final FlexTemplate template;
  final BragStats stats;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final checked = stats.days.where((day) => (day ?? 0) > 0).length;
    final best = stats.bestItem;
    final values = switch (template) {
      FlexTemplate.streak => [('最長連續', '${stats.bestStreak}'), ('完美日', '${stats.perfectDays}'), ('達成率', '${stats.overallPercent}%')],
      FlexTemplate.mvp => [('連續', '${best.streak}${best.periodUnit}'), ('做到', '${best.done}/${best.total}'), ('評價', gradeOf(best.rate))],
      FlexTemplate.map => [('打卡', '$checked/${stats.dayNumber}'), ('最長連續', '${stats.bestStreak}'), ('評價', gradeOf(stats.overall))],
      FlexTemplate.stats => [('等級', 'LV${stats.dayNumber}'), ('評價', gradeOf(stats.overall)), ('應援', '${stats.cheers}')],
    };
    final line = rarityColors(rarity)[1].withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          for (final (i, (label, value)) in values.indexed) ...[
            if (i > 0) Container(width: 1, height: 26, color: line),
            Expanded(
              child: Column(
                children: [
                  Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700)),
                  FittedBox(
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.2, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Owner extends StatelessWidget {
  const _Owner({required this.stats, required this.rarity});

  final BragStats stats;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final profile = stats.player.profile;
    final brag = stats.teamSize > 1 && stats.beatPercent >= 50 ? '贏過 ${stats.beatPercent}% 隊友' : 'OMI 100 DAY CHALLENGE';
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: _metal(rarity)),
          child: Text(profile.avatar, style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        Text(brag, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(this.text, {required this.gradient, required this.style});

  final String text;
  final Gradient gradient;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // 光暈（shadows）要畫在漸層字的下面，不然會被 ShaderMask 一起染色。
    final glow = style.shadows;
    return Stack(
      children: [
        if (glow != null) Text(text, style: style.copyWith(color: Colors.transparent)),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white, shadows: const [])),
        ),
      ],
    );
  }
}

/// 彩虹箔：斜斜的彩虹帶＋一道會掃過去的白光＋幾顆閃點。
class _Foil extends CustomPainter {
  _Foil({required this.t, required this.rarity});

  final double t;
  final Rarity rarity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // N 卡沒有箔，R 以上越稀有越閃。
    final strength = switch (rarity) {
      Rarity.n => 0.0,
      Rarity.r => 0.08,
      Rarity.sr => 0.12,
      Rarity.ssr => 0.16,
      Rarity.ur => 0.24,
    };
    if (strength > 0) {
      final shift = t * 2 - 1;
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: Alignment(-1 + shift, -1),
            end: Alignment(0 + shift, 0.4),
            tileMode: TileMode.mirror,
            colors: [
              for (final color in const [
                Color(0xFFFF5F6D),
                Color(0xFFFFC371),
                Color(0xFF47E5BC),
                Color(0xFF4FC3F7),
                Color(0xFFB388FF),
              ])
                color.withValues(alpha: strength),
            ],
          ).createShader(rect),
      );
    }

    // 流光：一道白光從左上掃到右下。
    final p = t * 1.6 - 0.3;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.28), Colors.transparent],
          stops: [(p - 0.12).clamp(0.0, 1.0), p.clamp(0.0, 1.0), (p + 0.12).clamp(0.0, 1.0)],
        ).createShader(rect),
    );

    // 閃點：四角星。
    final random = math.Random(11);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 14; i++) {
      final center = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final pulse = math.sin((t + i / 14) * 2 * math.pi);
      if (pulse < 0.3) continue;
      paint.color = Colors.white.withValues(alpha: 0.4 + 0.5 * pulse);
      _sparkle(canvas, center, 2 + 4 * pulse, paint);
    }
  }

  @override
  bool shouldRepaint(_Foil old) => old.t != t || old.rarity != rarity;
}

void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
  final w = r * 0.28;
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close(),
    paint,
  );
}

/// 放射的光芒。
class _Rays extends CustomPainter {
  _Rays({required this.t, required this.color, required this.rays, this.center});

  final double t;
  final Color color;
  final int rays;
  final Offset? center;

  @override
  void paint(Canvas canvas, Size size) {
    final c = center ?? size.center(Offset.zero);
    final reach = size.longestSide * 1.5;
    final step = 2 * math.pi / rays;
    final spin = t * step * 2;
    final paint = Paint()..color = color;
    for (var i = 0; i < rays; i += 2) {
      final a = i * step + spin;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + reach * math.cos(a), c.dy + reach * math.sin(a))
          ..lineTo(c.dx + reach * math.cos(a + step), c.dy + reach * math.sin(a + step))
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Rays old) => old.t != t || old.color != color;
}

/// 限動和貼文的背景：深紫宇宙＋稀有度的光芒＋散景光點＋閃光。
class _Backdrop extends CustomPainter {
  _Backdrop({required this.t, required this.rarity, required this.center});

  final double t;
  final Rarity rarity;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = rarityGlow(rarity);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((center.dx / size.width) * 2 - 1, (center.dy / size.height) * 2 - 1),
          radius: 1.1,
          colors: [Color.lerp(glow, const Color(0xFF3B1D6E), 0.55)!, const Color(0xFF140A30), const Color(0xFF05040E)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    _Rays(t: t, color: glow.withValues(alpha: 0.09), rays: 28, center: center).paint(canvas, size);

    final random = math.Random(3);
    final bokeh = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final palette = rarityColors(rarity);
    for (var i = 0; i < 16; i++) {
      final offset = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      bokeh.color = palette[i % palette.length].withValues(alpha: 0.18 + random.nextDouble() * 0.2);
      canvas.drawCircle(offset, 6 + random.nextDouble() * 16, bokeh);
    }

    final spark = Paint();
    for (var i = 0; i < 18; i++) {
      final offset = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      final pulse = math.sin((t * 2 + i / 18) * 2 * math.pi);
      if (pulse < 0) continue;
      spark.color = Colors.white.withValues(alpha: 0.3 + 0.6 * pulse);
      _sparkle(canvas, offset, 2 + 5 * pulse, spark);
    }
  }

  @override
  bool shouldRepaint(_Backdrop old) => old.t != t || old.rarity != rarity || old.center != center;
}

/// 百日格子的發光版：完美日是會發光的金點。
class _GlowGrid extends CustomPainter {
  _GlowGrid({required this.days, required this.rarity});

  final List<double?> days;
  final Rarity rarity;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 10;
    final cell = size.width / columns;
    final radius = cell * 0.34;
    final glow = rarityGlow(rarity);
    final gold = rarityColors(Rarity.ssr)[1];
    final paint = Paint();
    final halo = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8);
    for (var i = 0; i < days.length; i++) {
      final center = Offset((i % columns + 0.5) * cell, (i ~/ columns + 0.5) * cell);
      final value = days[i];
      if (value == null) {
        paint
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawCircle(center, radius * 0.7, paint);
        continue;
      }
      paint.style = PaintingStyle.fill;
      if (value >= 1) {
        halo.color = gold.withValues(alpha: 0.8);
        canvas.drawCircle(center, radius * 1.2, halo);
        paint.color = Color.lerp(gold, Colors.white, 0.35)!;
      } else if (value > 0) {
        paint.color = glow.withValues(alpha: 0.35 + 0.5 * value);
      } else {
        paint.color = Colors.white.withValues(alpha: 0.1);
      }
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowGrid old) => old.days != days || old.rarity != rarity;
}

/// 五大類的雷達圖（五角形）。
class _Radar extends CustomPainter {
  _Radar({required this.rates, required this.rarity});

  final Map<Pillar, double> rates;
  final Rarity rarity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(const Offset(0, 4));
    final radius = math.min(size.width, size.height) / 2 - 18;
    final pillars = Pillar.values;
    Offset vertex(int i, double r) {
      final a = -math.pi / 2 + i * 2 * math.pi / pillars.length;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    Path polygon(double Function(int i) r) {
      final path = Path()..moveTo(vertex(0, r(0)).dx, vertex(0, r(0)).dy);
      for (var i = 1; i < pillars.length; i++) {
        final v = vertex(i, r(i));
        path.lineTo(v.dx, v.dy);
      }
      return path..close();
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final ring in [0.33, 0.66, 1.0]) {
      canvas.drawPath(polygon((_) => radius * ring), grid);
    }
    for (var i = 0; i < pillars.length; i++) {
      canvas.drawLine(center, vertex(i, radius), grid);
    }

    final shape = polygon((i) => radius * math.max(0.06, rates[pillars[i]] ?? 0));
    final glow = rarityGlow(rarity);
    canvas.drawPath(
      shape,
      Paint()
        ..color = glow.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(shape, Paint()..color = glow.withValues(alpha: 0.45));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    for (var i = 0; i < pillars.length; i++) {
      final pillar = pillars[i];
      final label = TextPainter(
        text: TextSpan(
          text: '${pillar.emoji}${((rates[pillar] ?? 0) * 99).round()}',
          style: TextStyle(color: pillarColor(pillar), fontSize: 12, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = vertex(i, radius + 12);
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_Radar old) => old.rates != rates || old.rarity != rarity;
}
