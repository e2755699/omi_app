import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 機械鍵盤鍵帽造型的按鈕：平常是凸起的米色鍵帽；
/// [on]（已打卡）時維持按下去的樣子，頂面亮成 [color]。
class Keycap extends StatefulWidget {
  const Keycap({
    super.key,
    required this.child,
    required this.onTap,
    this.on = false,
    this.color = PixelColors.yellow,
    this.faceColor = const Color(0xFFFFFBF0),
    this.travel = 6,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool on;

  /// 亮起來的顏色。
  final Color color;

  /// 還沒按下去時鍵帽頂面的顏色。
  final Color faceColor;

  /// 鍵程：按下去會往下沉多少。
  final double travel;

  @override
  State<Keycap> createState() => _KeycapState();
}

class _KeycapState extends State<Keycap> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sunk = widget.on || _down;
    final top = !enabled
        ? PixelColors.sand
        : widget.on
            ? widget.color
            : widget.faceColor;
    final side = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), top);
    final light = Color.alphaBlend(Colors.white.withValues(alpha: 0.55), top);
    final shade = Color.alphaBlend(Colors.black.withValues(alpha: 0.12), top);

    return Semantics(
      button: true,
      selected: widget.on,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => _setDown(true) : null,
          onTapUp: enabled ? (_) => _setDown(false) : null,
          onTapCancel: enabled ? () => _setDown(false) : null,
          child: Padding(
            // 按下去時整顆往下沉，鍵帽側邊變薄，總高度不變。
            padding: EdgeInsets.only(top: sunk ? widget.travel : 0),
            child: Container(
              padding: EdgeInsets.fromLTRB(3, 2, 3, 3 + (sunk ? 0 : widget.travel)),
              decoration: ShapeDecoration(color: side, shape: const PixelBorder()),
              child: Container(
                decoration: BoxDecoration(
                  color: top,
                  border: Border(
                    top: BorderSide(color: light, width: 2),
                    left: BorderSide(color: light, width: 2),
                    right: BorderSide(color: shade, width: 2),
                    bottom: BorderSide(color: shade, width: 2),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
