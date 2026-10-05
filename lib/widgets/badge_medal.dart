import 'package:flutter/material.dart';

import '../models/achievements.dart';
import 'pixel_ui.dart';

/// 像素風獎章：上面是緞帶，下面是圓形獎牌，中間是圖案；還沒解鎖時整個是灰的。
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.look, this.locked = false, this.dot = 3});

  /// 獎章本體佔幾格（不含右下一格的硬陰影）。
  static const columns = 15;
  static const rows = 20;

  final BadgeLook look;
  final bool locked;

  /// 每一格的大小（邏輯像素）。整個寬 = 16 × [dot]、高 = 21 × [dot]。
  final double dot;

  static Size sizeFor(double dot) => Size((columns + 1) * dot, (rows + 1) * dot);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: sizeFor(dot),
      painter: _MedalPainter(look, locked, dot),
    );
  }
}

/// 獎章每一格的顏色（null 是透明），[BadgeMedal.rows] 列 × [BadgeMedal.columns] 欄。
List<List<Color?>> medalPixels(BadgeLook look, {bool locked = false}) {
  final palette = locked ? _MedalPalette.locked : _MedalPalette.of(look);
  final grid = [for (var y = 0; y < BadgeMedal.rows; y++) List<Color?>.filled(BadgeMedal.columns, null)];

  // 緞帶：第 4–10 欄，從最上面一路塞到獎牌後面，中間一條白線。
  for (var y = 0; y <= 7; y++) {
    for (var x = 4; x <= 10; x++) {
      grid[y][x] = y == 0 || x == 4 || x == 10
          ? palette.outline
          : x == 7
              ? palette.stripe
              : palette.ribbon;
    }
  }

  // 獎牌：直徑 15 格的圓，圓心在第 7 欄、第 12 列。
  bool inside(int x, int y) => (x - 7) * (x - 7) + (y - 12) * (y - 12) <= 56;
  List<(int, int)> around(int x, int y) => [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)];
  bool edge(int x, int y) => inside(x, y) && around(x, y).any((p) => !inside(p.$1, p.$2));
  bool rim(int x, int y) => inside(x, y) && !edge(x, y) && around(x, y).any((p) => edge(p.$1, p.$2));

  for (var y = 5; y < BadgeMedal.rows; y++) {
    for (var x = 0; x < BadgeMedal.columns; x++) {
      if (!inside(x, y)) continue;
      if (edge(x, y)) {
        grid[y][x] = palette.outline;
      } else if (rim(x, y)) {
        grid[y][x] = palette.rim;
      } else if (x < 7 && y < 12 && around(x, y).any((p) => rim(p.$1, p.$2))) {
        // 左上角一道反光。
        grid[y][x] = palette.shine;
      } else {
        grid[y][x] = palette.face;
      }
    }
  }

  // 中間 7×7 的圖案。
  final motif = _motifs[look.motif]!;
  for (var y = 0; y < motif.length; y++) {
    for (var x = 0; x < motif[y].length; x++) {
      if (motif[y][x] == '#') grid[9 + y][4 + x] = palette.motif;
    }
  }
  return grid;
}

class _MedalPalette {
  const _MedalPalette({
    required this.outline,
    required this.face,
    required this.rim,
    required this.shine,
    required this.ribbon,
    required this.stripe,
    required this.motif,
  });

  factory _MedalPalette.of(BadgeLook look) {
    final face = Color(look.face);
    return _MedalPalette(
      outline: PixelColors.ink,
      face: face,
      rim: Color.lerp(face, PixelColors.ink, 0.3)!,
      shine: Color.lerp(face, Colors.white, 0.55)!,
      ribbon: Color(look.ribbon),
      stripe: PixelColors.paper,
      motif: onColor(face),
    );
  }

  /// 還沒解鎖：灰灰的，只看得出形狀。
  static const locked = _MedalPalette(
    outline: PixelColors.muted,
    face: Color(0xFFD9D0B8),
    rim: Color(0xFFBFB49A),
    shine: Color(0xFFEAE3D0),
    ribbon: Color(0xFFC9BFA5),
    stripe: Color(0xFFEDE7D6),
    motif: Color(0xFFA39880),
  );

  final Color outline;
  final Color face;
  final Color rim;
  final Color shine;
  final Color ribbon;
  final Color stripe;
  final Color motif;
}

class _MedalPainter extends CustomPainter {
  _MedalPainter(this.look, this.locked, this.dot);

  final BadgeLook look;
  final bool locked;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = medalPixels(look, locked: locked);
    final paint = Paint()..isAntiAlias = false;

    // 先畫右下一格的硬陰影，再畫本體。
    paint.color = PixelColors.ink.withValues(alpha: locked ? 0.12 : 0.25);
    for (var y = 0; y < grid.length; y++) {
      for (var x = 0; x < grid[y].length; x++) {
        if (grid[y][x] != null) canvas.drawRect(Rect.fromLTWH((x + 1) * dot, (y + 1) * dot, dot, dot), paint);
      }
    }
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      var x = 0;
      while (x < row.length) {
        final color = row[x];
        if (color == null) {
          x++;
          continue;
        }
        // 同一列連續同色的格子合併成一個矩形，才不會有縫。
        final start = x;
        while (x < row.length && row[x] == color) {
          x++;
        }
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(start * dot, y * dot, (x - start) * dot, dot), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.look != look || old.locked != locked || old.dot != dot;
}

const _motifs = <BadgeMotif, List<String>>{
  BadgeMotif.check: ['.......', '......#', '.....##', '#...##.', '##.##..', '.###...', '..#....'],
  BadgeMotif.star: ['...#...', '..###..', '#######', '.#####.', '..###..', '.##.##.', '.#...#.'],
  BadgeMotif.flame: ['..#....', '..##...', '.####.#', '.##.###', '##...##', '##...##', '.#####.'],
  BadgeMotif.crown: ['.......', '#..#..#', '##.#.##', '#######', '#.###.#', '#######', '.......'],
  BadgeMotif.bolt: ['....##.', '...##..', '..##...', '.######', '....##.', '...##..', '..##...'],
  BadgeMotif.sprout: ['.......', '##...##', '###.###', '.##.##.', '...#...', '...#...', '.#####.'],
  BadgeMotif.book: ['.......', '.##.##.', '#..#..#', '#..#..#', '#..#..#', '##.#.##', '..###..'],
  BadgeMotif.moon: ['..###..', '.###...', '###..#.', '###....', '###....', '.###...', '..###..'],
  BadgeMotif.magnifier: ['.###...', '#...#..', '#...#..', '#...#..', '.####..', '....##.', '.....##'],
  BadgeMotif.trophy: ['#######', '#.###.#', '.#####.', '..###..', '...#...', '..###..', '.#####.'],
};
