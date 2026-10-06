import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/brag.dart';
import '../../models/rules.dart';
import '../energy_tile.dart';
import '../pixel_text.dart';
import '../pixel_ui.dart';
import 'flex_card.dart';
import 'holo_flex_card.dart';
import 'pixel_bits.dart';

/// 連續打卡到這幾天時跳出慶祝畫面。
const streakMilestones = [3, 7, 14, 21, 30, 50, 100];

bool isStreakMilestone(int streak) => streakMilestones.contains(streak);

/// 全螢幕慶祝連續打卡的里程碑，最後翻開一張閃卡。按「炫耀一下」會回傳 true。
Future<bool?> showMilestoneCelebration(BuildContext context, BragStats stats) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) => MilestoneCelebration(stats: stats),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class MilestoneCelebration extends StatefulWidget {
  const MilestoneCelebration({super.key, required this.stats});

  final BragStats stats;

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  late final Animation<double> _pop = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.45, curve: Curves.elasticOut),
  );
  late final Animation<double> _flip = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.4, 0.9, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final rarity = rarityOf(FlexTemplate.streak, stats);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xE61A1A1A)),
          AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => CustomPaint(painter: _Confetti(t: _loop.value)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _loop,
                      builder: (context, child) => Opacity(opacity: (_loop.value * 6).floor().isEven ? 1 : 0.2, child: child),
                      child: const PixelText('MILESTONE!', dot: 4, color: PixelColors.orange),
                    ),
                    const SizedBox(height: 18),
                    ScaleTransition(
                      scale: _pop,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const PixelSprite(flameSprite, unit: 6),
                          const SizedBox(width: 12),
                          ShadowPixelText('${stats.streak}', dot: 14),
                          const SizedBox(width: 12),
                          const PixelSprite(flameSprite, unit: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const PixelText('DAY STREAK', dot: 3, color: PixelColors.paper),
                    const SizedBox(height: 14),
                    Text(
                      '連續打卡 ${stats.streak} 天！',
                      style: const TextStyle(color: PixelColors.paper, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '解鎖稱號「${streakTitle(stats.streak)}」',
                      style: const TextStyle(color: PixelColors.yellow, fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 20),
                    // 像抽卡一樣把卡片翻過來。
                    AnimatedBuilder(
                      animation: _flip,
                      builder: (context, _) {
                        final angle = (1 - _flip.value) * math.pi;
                        final showBack = angle > math.pi / 2;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..rotateY(angle),
                          child: SizedBox(
                            width: 160,
                            height: 224,
                            child: showBack
                                ? _CardBack(rarity: rarity)
                                : FittedBox(
                                    child: FlexCard(
                                      style: FlexStyle.holo,
                                      template: FlexTemplate.streak,
                                      format: FlexFormat.sticker,
                                      stats: stats,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '獲得一張 ${rarity.label} 自律卡',
                      style: TextStyle(color: rarityGlow(rarity), fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PixelBox(
                          color: PixelColors.yellow,
                          onTap: () => Navigator.of(context).pop(true),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: const Text('🔥 炫耀一下', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 12),
                        PixelBox(
                          onTap: () => Navigator.of(context).pop(false),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: const Text('繼續推石頭', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final glow = rarityGlow(rarity);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1659), Color(0xFF0A0818)],
        ),
        border: Border.all(color: glow, width: 4),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: 24)],
      ),
      alignment: Alignment.center,
      child: Text('✦', style: TextStyle(color: glow, fontSize: 64)),
    );
  }
}

/// 掉下來的像素彩紙。
class _Confetti extends CustomPainter {
  _Confetti({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(5);
    final paint = Paint()..isAntiAlias = false;
    final colors = [PixelColors.yellow, PixelColors.orange, for (final pillar in Pillar.values) pillarColor(pillar)];
    for (var i = 0; i < 70; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.8;
      final start = random.nextDouble();
      final y = ((start + t * speed) % 1.1 - 0.05) * size.height;
      final wobble = math.sin((t * speed + start) * 2 * math.pi * 2) * 8;
      final cell = random.nextBool() ? 6.0 : 8.0;
      paint.color = colors[i % colors.length];
      canvas.drawRect(Rect.fromLTWH((x + wobble).roundToDouble(), y.roundToDouble(), cell, cell), paint);
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}
