import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 用字串畫的像素圖：每個字元是一格，顏色查 [palette]；
/// '.' 或 palette 裡沒有的字元是透明。
class PixelSprite extends StatelessWidget {
  const PixelSprite(this.rows, {super.key, required this.palette, this.dot = 3, this.semanticLabel});

  final List<String> rows;
  final Map<String, Color> palette;

  /// 每一格的大小（邏輯像素）。
  final double dot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final columns = rows.isEmpty ? 0 : rows.first.length;
    final sprite = CustomPaint(
      size: Size(columns * dot, rows.length * dot),
      painter: _SpritePainter(rows, palette, dot),
    );
    final label = semanticLabel;
    return label == null ? sprite : Semantics(label: label, image: true, child: sprite);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.rows, this.palette, this.dot);

  final List<String> rows;
  final Map<String, Color> palette;
  final double dot;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      var x = 0;
      while (x < row.length) {
        final char = row[x];
        final color = palette[char];
        if (color == null) {
          x++;
          continue;
        }
        // 同一列連續同色的格子合併成一個矩形，畫起來比較快也不會有縫。
        final start = x;
        while (x < row.length && row[x] == char) {
          x++;
        }
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(start * dot, y * dot, (x - start) * dot, dot), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.rows != rows || old.palette != palette || old.dot != dot;
}

/// 小豬撲滿：面向右邊，頭上有一枚金幣正要投進去。
const pigSprite = [
  '........KKKK..........',
  '.......KYYYYK.K.......',
  '........KYYK.KDK......',
  '......KKKKKKKKDK......',
  '....KKPPKKKKPPPKK.....',
  '...KPWWPPPPPPPPPPK....',
  '..KPWPPPPPPPPPPKPPKKK.',
  '.KKPPPPPPPPPPPPPPPDDDK',
  'K.KPPPPPPPPPPPPPPPDKDK',
  '.KKPPPPPPPPPPPPPPPDDDK',
  '..KPPPPPPPPPPPPPPPKKK.',
  '...KPPPPPPPPPPPPPK....',
  '....KKPPPPPPPPPKK.....',
  '.....KPPKKKKKPPK......',
  '.....KPPK...KPPK......',
  '.....KKKK...KKKK......',
];

const pigPalette = {
  'K': PixelColors.ink,
  'P': Color(0xFFF7A8B8),
  'D': Color(0xFFE27396),
  'W': Color(0xFFFFFFFF),
  'Y': PixelColors.yellow,
};

/// 星星：黃色、黑框，底下兩隻腳帶一點橘色。
const starSprite = [
  '....K....',
  '...KYK...',
  'KKKKYKKKK',
  'KYYYYYYYK',
  '.KYYYYYK.',
  '..KYYYK..',
  '.KYYKYYK.',
  '.KOK.KOK.',
  '.KK...KK.',
];

const starPalette = {
  'K': PixelColors.ink,
  'Y': PixelColors.yellow,
  'O': PixelColors.orange,
};

class PixelPig extends StatelessWidget {
  const PixelPig({super.key, this.dot = 4});

  final double dot;

  @override
  Widget build(BuildContext context) =>
      PixelSprite(pigSprite, palette: pigPalette, dot: dot, semanticLabel: '小豬撲滿');
}

class PixelStar extends StatelessWidget {
  const PixelStar({super.key, this.dot = 2});

  final double dot;

  @override
  Widget build(BuildContext context) => PixelSprite(starSprite, palette: starPalette, dot: dot);
}
