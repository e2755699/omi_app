import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../models/rules.dart';
import 'pixel_text.dart';
import 'pixel_ui.dart';

Color pillarColor(Pillar pillar) => switch (pillar) {
      Pillar.move => const Color(0xFFF29F05),
      Pillar.nourish => const Color(0xFF3FA34D),
      Pillar.learn => const Color(0xFF3A86FF),
      Pillar.recover => const Color(0xFF8B5CF6),
      Pillar.reflect => const Color(0xFFE4572E),
    };

/// 能量槽下面的數字，例如「70/150 分鐘」「3/7 天」。
String progressText(ChallengeItem item, ItemProgress progress) => switch (item.kind) {
      ItemKind.daily => '${progress.value}/${progress.target} 天',
      ItemKind.weeklyAmount => '${progress.value}/${progress.target} ${item.unit}',
      ItemKind.weekly when progress.target > 1 => '${progress.value}/${progress.target} 題',
      ItemKind.weekly => progress.doneNow ? '本週完成' : '本週還沒',
    };

/// 首頁上的一格：一個挑戰項目＋它這週的能量槽。
class EnergyTile extends StatelessWidget {
  const EnergyTile({super.key, required this.item, required this.progress, this.onTap});

  static const height = 98.0;

  final ChallengeItem item;
  final ItemProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              if (progress.energy >= 1) const PixelText('✓', dot: 2, color: PixelColors.green),
            ],
          ),
          const Spacer(),
          PixelCellsBar(cells: progress.cells, color: pillarColor(item.pillar), height: 12),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressText(item, progress),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
                ),
              ),
              PixelText('${progress.percent}%', dot: 2),
            ],
          ),
        ],
      ),
    );
  }
}
