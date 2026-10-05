import 'package:flutter/material.dart';

import 'pixel_text.dart';
import 'pixel_ui.dart';

/// 黃底的像素小標籤，例如「DAY 30」。
class PixelTag extends StatelessWidget {
  const PixelTag(this.text, {super.key, this.dot = 2});

  final String text;
  final double dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PixelColors.yellow,
      padding: EdgeInsets.symmetric(horizontal: dot * 2.5, vertical: dot * 2),
      child: PixelText(text, dot: dot),
    );
  }
}

/// 區塊標題：像素標籤＋中文標題。
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.tag, required this.title});

  final String tag;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PixelTag(tag),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}
