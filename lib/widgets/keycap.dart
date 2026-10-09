import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pixel_ui.dart';

/// 機械鍵盤鍵帽造型的按鈕，從正前上方看：
/// 頂面比較小、後緣受光最亮、前壁最厚、左右是側壁，底下還有一道硬陰影（浮在桌面上）。
/// 按下去時整顆往下沉：陰影消失、前壁變薄、後緣露出更多，附一點震動；
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
    this.thickness = 1,
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

  /// 鍵帽側壁、前壁、陰影的厚度倍率；小顆的鍵帽（例如桌面小工具）用 0.5。
  final double thickness;

  @override
  State<Keycap> createState() => _KeycapState();
}

class _KeycapState extends State<Keycap> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
    // 按下去重一點、彈起來輕一點，像真的鍵軸。
    if (value) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sunk = widget.on || _down;
    final cap = !enabled
        ? PixelColors.sand
        : widget.on
            ? widget.color
            : widget.faceColor;

    Color mix(Color tint, double amount) => Color.alphaBlend(tint.withValues(alpha: amount), cap);

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: sunk ? 1 : 0),
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            builder: (context, pressed, child) => _KeycapBody(
              pressed: pressed,
              travel: widget.travel,
              thickness: widget.thickness,
              backLip: mix(Colors.white, 0.5),
              frontWall: mix(Colors.black, 0.3),
              sideWall: mix(Colors.black, 0.2),
              face: cap,
              faceEdge: mix(Colors.black, 0.14),
              faceLight: mix(Colors.white, 0.6),
              child: child!,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _KeycapBody extends StatelessWidget {
  const _KeycapBody({
    required this.pressed,
    required this.travel,
    required this.thickness,
    required this.backLip,
    required this.frontWall,
    required this.sideWall,
    required this.face,
    required this.faceEdge,
    required this.faceLight,
    required this.child,
  });

  /// 0 是浮起來，1 是完全按下去。
  final double pressed;
  final double travel;
  final double thickness;
  final Color backLip;
  final Color frontWall;
  final Color sideWall;
  final Color face;
  final Color faceEdge;
  final Color faceLight;
  final Widget child;

  /// 側壁、後緣、前壁、陰影的厚度（倍率 1 時），都取整數像素才不會糊。
  double _px(double base, {double min = 1}) => (base * thickness).roundToDouble().clamp(min, double.infinity);

  @override
  Widget build(BuildContext context) {
    final side = _px(6);
    final outline = _px(3);
    final depth = _px(4);
    final edge = thickness < 0.75 ? 1.0 : 2.0;
    final sink = (travel * pressed).roundToDouble();
    // 按下去：整顆往下沉、陰影被吃掉；後緣露出更多、前壁變薄，總高度不變。
    final back = _px(4) + sink;
    final front = _px(14) - sink;
    final shadow = (depth * (1 - pressed)).roundToDouble();

    return Padding(
      padding: EdgeInsets.fromLTRB(depth - shadow, depth - shadow, shadow, shadow),
      child: Container(
        decoration: ShapeDecoration(
          color: sideWall,
          shape: PixelBorder(width: outline),
          shadows: shadow == 0 ? null : [BoxShadow(color: PixelColors.ink, offset: Offset(shadow, shadow))],
        ),
        padding: EdgeInsets.all(outline),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // 後緣（受光）與前壁。
            Positioned(left: side, right: side, top: 0, height: back, child: ColoredBox(color: backLip)),
            Positioned(left: side, right: side, bottom: 0, height: front, child: ColoredBox(color: frontWall)),
            // 頂面：缺角邊框當作圓角，上緣一條亮邊。
            Padding(
              padding: EdgeInsets.fromLTRB(side, back, side, front),
              child: Container(
                decoration: ShapeDecoration(color: face, shape: PixelBorder(width: edge, color: faceEdge)),
                padding: const EdgeInsets.fromLTRB(1, 1, 1, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: edge, child: ColoredBox(color: faceLight)),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
