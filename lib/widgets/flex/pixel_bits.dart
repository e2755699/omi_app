import 'package:flutter/material.dart';

import '../pixel_text.dart';
import '../pixel_ui.dart';

const pixelRed = Color(0xFFE4572E);

/// 有硬陰影的大像素字：像街機的分數。
class ShadowPixelText extends StatelessWidget {
  const ShadowPixelText(
    this.text, {
    super.key,
    required this.dot,
    this.color = PixelColors.yellow,
    this.shadow = PixelColors.orange,
  });

  final String text;
  final double dot;
  final Color color;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    final offset = (dot / 2).ceilToDouble();
    return Padding(
      padding: EdgeInsets.only(right: offset, bottom: offset),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: offset, top: offset, child: PixelText(text, dot: dot, color: shadow)),
          PixelText(text, dot: dot, color: color),
        ],
      ),
    );
  }
}

/// 一張小像素圖：每個字元一格，'.' 是透明；k 黑、y 黃、o 橘、r 紅、w 白。
class PixelSprite extends StatelessWidget {
  const PixelSprite(this.rows, {super.key, this.unit = 4});

  final List<String> rows;
  final double unit;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(rows.first.length * unit, rows.length * unit),
      painter: _SpritePainter(rows, unit),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.rows, this.unit);

  final List<String> rows;
  final double unit;

  static const _palette = {
    'k': PixelColors.ink,
    'y': PixelColors.yellow,
    'o': PixelColors.orange,
    'r': pixelRed,
    'w': Colors.white,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final color = _palette[rows[y][x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x * unit, y * unit, unit, unit), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.rows != rows || old.unit != unit;
}

const flameSprite = [
  '...r....',
  '...rr...',
  '..rrr.r.',
  '.rrorrr.',
  '.rooorr.',
  'rrooyorr',
  'rooyyoor',
  'rooyyyor',
  '.royyyr.',
  '..rrrr..',
];

const crownSprite = [
  'y....y....y',
  'yy..yyy..yy',
  'yyy.yyy.yyy',
  'yyyyyyyyyyy',
  'yyrryyyrryy',
  'yyyyyyyyyyy',
  'ooooooooooo',
];
