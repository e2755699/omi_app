import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 色系參考「電扶梯走左邊」網站：黑色頂欄、米黃底、亮黃按鈕、手扶梯的橘。
abstract final class PixelColors {
  static const ink = Color(0xFF1A1A1A);
  static const background = Color(0xFFF4EAC8);
  static const paper = Color(0xFFFFF8E6);
  static const sand = Color(0xFFE6D8AC);
  static const yellow = Color(0xFFFFCC00);
  static const orange = Color(0xFFF29F05);
  static const muted = Color(0xFF6E6250);
  static const green = Color(0xFF2E9E5B);

  /// 黑底上的空格。
  static const night = Color(0xFF3A362E);
}

/// 依背景色挑選看得清楚的文字顏色。
Color onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? PixelColors.paper : PixelColors.ink;

/// 像素風外框：四個角各缺一格，像 8-bit 遊戲的對話框。
class PixelBorder extends ShapeBorder {
  const PixelBorder({this.width = 3, this.color = PixelColors.ink});

  final double width;
  final Color color;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final n = width;
    return Path()
      ..moveTo(rect.left + n, rect.top)
      ..lineTo(rect.right - n, rect.top)
      ..lineTo(rect.right - n, rect.top + n)
      ..lineTo(rect.right, rect.top + n)
      ..lineTo(rect.right, rect.bottom - n)
      ..lineTo(rect.right - n, rect.bottom - n)
      ..lineTo(rect.right - n, rect.bottom)
      ..lineTo(rect.left + n, rect.bottom)
      ..lineTo(rect.left + n, rect.bottom - n)
      ..lineTo(rect.left, rect.bottom - n)
      ..lineTo(rect.left, rect.top + n)
      ..lineTo(rect.left + n, rect.top + n)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect.deflate(width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width == 0) return;
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addRect(rect.deflate(width));
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  @override
  ShapeBorder scale(double t) => PixelBorder(width: width * t, color: color);
}

/// 像素風方塊：粗黑框＋右下硬陰影。給 [onTap] 就能按，按下去會「陷下去」。
class PixelBox extends StatefulWidget {
  const PixelBox({
    super.key,
    required this.child,
    this.color = PixelColors.paper,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.depth = 4,
    this.borderWidth = 3,
    this.pressed = false,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// 陰影深度，也是按下去時位移的距離。
  final double depth;
  final double borderWidth;

  /// 固定顯示成按下去的樣子（例如今天已經打過卡）。
  final bool pressed;

  @override
  State<PixelBox> createState() => _PixelBoxState();
}

class _PixelBoxState extends State<PixelBox> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final sunk = widget.pressed || _down;
    final shift = sunk ? widget.depth : 0.0;
    final box = Padding(
      padding: EdgeInsets.fromLTRB(shift, shift, widget.depth - shift, widget.depth - shift),
      child: Container(
        padding: widget.padding,
        decoration: ShapeDecoration(
          color: widget.color,
          shape: PixelBorder(width: widget.borderWidth),
          shadows: sunk || widget.depth == 0
              ? null
              : [BoxShadow(color: PixelColors.ink, offset: Offset(widget.depth, widget.depth))],
        ),
        child: widget.child,
      ),
    );
    if (widget.onTap == null) return box;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          child: box,
        ),
      ),
    );
  }
}

/// 一格一格的像素進度條。
class PixelProgressBar extends StatelessWidget {
  const PixelProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.segments = 20,
    this.height = 14,
    this.emptyColor = PixelColors.sand,
    this.frameColor = PixelColors.ink,
  });

  /// 0–1。
  final double value;
  final Color color;
  final int segments;
  final double height;
  final Color emptyColor;
  final Color frameColor;

  @override
  Widget build(BuildContext context) {
    // 只要有進度就至少亮一格，才看得出來有在動。
    final filled = value <= 0 ? 0 : math.max(1, (value.clamp(0.0, 1.0) * segments).round());
    return PixelCellsBar(
      cells: [for (var i = 0; i < segments; i++) i < filled],
      color: color,
      height: height,
      emptyColor: emptyColor,
      frameColor: frameColor,
    );
  }
}

/// 能量槽：每一格 true 亮、false 暗、null 不算（例如不在挑戰期間）。
class PixelCellsBar extends StatelessWidget {
  const PixelCellsBar({
    super.key,
    required this.cells,
    required this.color,
    this.height = 14,
    this.emptyColor = PixelColors.sand,
    this.frameColor = PixelColors.ink,
  });

  final List<bool?> cells;
  final Color color;
  final double height;
  final Color emptyColor;
  final Color frameColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      color: frameColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: ColoredBox(
                color: switch (cells[i]) {
                  true => color,
                  false => emptyColor,
                  null => emptyColor.withValues(alpha: 0.3),
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
