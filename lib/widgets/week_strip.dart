import 'package:flutter/material.dart';

import '../models/challenge.dart';
import 'pixel_text.dart';
import 'pixel_ui.dart';

class WeekStripDay {
  const WeekStripDay({
    required this.date,
    required this.inChallenge,
    required this.filled,
    this.highlighted = false,
    this.caption,
    this.onTap,
  });

  final DateTime date;
  final bool inChallenge;
  final bool filled;

  /// 粗框標出來（今天，或正在編輯的那天）。
  final bool highlighted;

  /// 格子下面的字，預設是日期。
  final String? caption;
  final VoidCallback? onTap;
}

/// 一週七格（週一到週日）。
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.days, required this.color});

  final List<WeekStripDay> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: day.onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      weekdayLabel(day.date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: day.highlighted ? PixelColors.ink : PixelColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !day.inChallenge
                              ? Colors.transparent
                              : day.filled
                                  ? color
                                  : PixelColors.paper,
                          border: Border.all(
                            color: day.highlighted
                                ? PixelColors.ink
                                : day.inChallenge
                                    ? PixelColors.ink.withValues(alpha: 0.3)
                                    : PixelColors.sand,
                            width: day.highlighted ? 3 : 2,
                          ),
                        ),
                        child: day.filled ? PixelText('✓', dot: 2, color: onColor(color)) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.caption ?? formatShortDate(day.date),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PixelColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
