import 'package:flutter/material.dart';

import 'pixel_ui.dart';

/// 教學裡的嚮導：像素頭像＋一個字一個字跑出來的對話框。點對話框可以直接顯示全部。
class GuideBubble extends StatefulWidget {
  const GuideBubble({super.key, required this.text});

  final String text;

  @override
  State<GuideBubble> createState() => _GuideBubbleState();
}

class _GuideBubbleState extends State<GuideBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _typing = AnimationController(
    vsync: this,
    duration: _durationFor(widget.text),
  )..forward();

  static Duration _durationFor(String text) => Duration(milliseconds: 25 * text.characters.length);

  @override
  void didUpdateWidget(GuideBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _typing
        ..duration = _durationFor(widget.text)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w700);
    final characters = widget.text.characters;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PixelColors.yellow,
            border: Border.all(color: PixelColors.ink, width: 3),
          ),
          child: const Text('🧭', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _typing.value = 1,
            child: PixelBox(
              padding: const EdgeInsets.all(12),
              child: AnimatedBuilder(
                animation: _typing,
                builder: (context, _) {
                  final shown = (characters.length * _typing.value).round();
                  return Stack(
                    children: [
                      // 先用完整的字撐出高度，打字的時候框框才不會一直長高。
                      Opacity(opacity: 0, child: Text(widget.text, style: style)),
                      Text(characters.take(shown).toString(), style: style),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
