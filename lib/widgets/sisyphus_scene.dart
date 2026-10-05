import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 一格像素的大小（邏輯像素）。
const _unit = 4.0;

const _skin = Color(0xFFF2C094);
const _stone = Color(0xFF8C8C8C);
const _stoneLight = Color(0xFFBDBDBD);
const _heart = Color(0xFFE4572E);

/// 快樂的薛西弗斯：像素小人一步一步把大石頭推上山，頭上冒愛心。
class SisyphusScene extends StatefulWidget {
  const SisyphusScene({super.key, this.height = 150});

  final double height;

  @override
  State<SisyphusScene> createState() => _SisyphusSceneState();
}

class _SisyphusSceneState extends State<SisyphusScene> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '一個像素小人開心地把大石頭推上山',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => CustomPaint(
            painter: _ScenePainter(
              step: (_clock.value * 4).floor() % 2,
              beat: (_clock.value * 2).floor() % 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 推石頭的兩個動作（腳交替），每個字元一格：h 皮膚、k 黑、c 衣服。
const _frames = [
  [
    '.....hhhh..',
    '.....hhkh..',
    '.....hhhh..',
    '.....hkkh..',
    '....ccc....',
    '...ccccchhh',
    '..cccc.....',
    '..ccc......',
    '.cccc......',
    '.kk.kk.....',
    '.k...k.....',
    'k.....k....',
    'k......k...',
    'kk.....kk..',
  ],
  [
    '.....hhhh..',
    '.....hhkh..',
    '.....hhhh..',
    '.....hkkh..',
    '....ccc....',
    '...ccccchhh',
    '..cccc.....',
    '..ccc......',
    '.cccc......',
    '..kkk......',
    '..k.k......',
    '.k...k.....',
    '.k....k....',
    'kk....kk...',
  ],
];

const _heartShape = ['.#.#.', '#####', '.###.', '..#..'];

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.step, required this.beat});

  final int step;
  final int beat;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = (size.width / _unit).floor();
    final rows = (size.height / _unit).floor();
    final paint = Paint()..isAntiAlias = false;

    void cell(int x, int y, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x * _unit, y * _unit, _unit, _unit), paint);
    }

    // 山坡：從左下往右上，一階一階。
    int surface(int x) => rows - 3 - (x / cols * rows * 0.55).floor();

    // 太陽
    final sunX = (cols * 0.14).floor();
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        if (dx * dx + dy * dy <= 16) cell(sunX + dx, 7 + dy, PixelColors.yellow);
      }
    }

    for (var x = 0; x < cols; x++) {
      final top = surface(x);
      paint.color = PixelColors.sand;
      canvas.drawRect(Rect.fromLTWH(x * _unit, top * _unit, _unit, (rows - top) * _unit), paint);
      final previous = x == 0 ? top : surface(x - 1);
      for (var y = math.min(top, previous); y <= math.max(top, previous); y++) {
        cell(x, y, PixelColors.ink);
      }
    }

    // 山頂的旗子
    final flagX = cols - 6;
    final flagY = surface(flagX);
    for (var y = flagY - 10; y < flagY; y++) {
      cell(flagX, y, PixelColors.ink);
    }
    for (var y = flagY - 10; y < flagY - 7; y++) {
      for (var x = flagX + 1; x < flagX + 5; x++) {
        cell(x, y, PixelColors.orange);
      }
    }

    // 薛西弗斯
    final frame = _frames[step];
    final heroX = (cols * 0.36).floor();
    final heroTop = surface(heroX + 4) - frame.length;
    for (var y = 0; y < frame.length; y++) {
      for (var x = 0; x < frame[y].length; x++) {
        final color = switch (frame[y][x]) {
          'h' => _skin,
          'k' => PixelColors.ink,
          'c' => PixelColors.orange,
          _ => null,
        };
        if (color != null) cell(heroX + x, heroTop + y, color);
      }
    }

    // 大石頭：就在手的前面，跟著步伐微微晃動。
    const radius = 7;
    final stoneX = heroX + frame.first.length + radius;
    final stoneY = surface(stoneX) - radius - beat;
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance > radius + 0.3) continue;
        final Color color;
        if (distance > radius - 1) {
          color = PixelColors.ink;
        } else if (dx >= -4 && dx <= -2 && dy >= -4 && dy <= -3) {
          color = _stoneLight;
        } else {
          color = _stone;
        }
        cell(stoneX + dx, stoneY + dy, color);
      }
    }

    // 快樂：頭上冒愛心。
    final heartY = heroTop - 6 - beat;
    for (var y = 0; y < _heartShape.length; y++) {
      for (var x = 0; x < _heartShape[y].length; x++) {
        if (_heartShape[y][x] == '#') cell(heroX + 4 + x, heartY + y, _heart);
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.step != step || old.beat != beat;
}
