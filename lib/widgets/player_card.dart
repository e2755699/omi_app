import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/progress.dart';
import '../models/rules.dart';
import 'energy_tile.dart';
import 'pixel_text.dart';
import 'pixel_ui.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.profile, this.size = 36});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PixelColors.yellow.withValues(alpha: 0.35),
        border: Border.all(color: PixelColors.ink, width: 2),
      ),
      child: Text(profile.avatar, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// 「大家的進度」裡的一張卡片：本週能量＋五大類的電池＋應援按鈕。
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    required this.summary,
    required this.cheers,
    this.cheered = false,
    this.onCheer,
    this.onTap,
  });

  static const height = 232.0;

  final Player player;
  final WeekSummary summary;

  /// 今天收到幾個加油／慶祝。
  final int cheers;

  /// 我今天幫他加油過了。
  final bool cheered;

  /// null 表示不能加油（自己，或挑戰不在進行中）。
  final VoidCallback? onCheer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = player.profile.name;
    final title = player.isMe && name != Profile.defaultName ? '$name（我）' : name;
    return PixelBox(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(profile: player.profile),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              _TodayMark(done: summary.todayComplete),
            ],
          ),
          const SizedBox(height: 10),
          PixelProgressBar(value: summary.energy, color: PixelColors.yellow, segments: 10, height: 12),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '本週能量',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
              ),
              const Spacer(),
              PixelText('${summary.percent}%', dot: 2),
            ],
          ),
          const Spacer(),
          PillarBatteries(energy: summary.pillarEnergy),
          const SizedBox(height: 6),
          Text(
            '今天 ${summary.dailyDone}/${summary.dailyTotal} 項',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${summary.todayComplete ? '🎉' : '📣'} $cheers',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (player.isMe)
                const Text(
                  '收到的應援',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
                )
              else if (onCheer != null || cheered)
                _CheerButton(celebrate: summary.todayComplete, cheered: cheered, onTap: onCheer),
            ],
          ),
        ],
      ),
    );
  }
}

/// 今天還沒完成 → 集氣加油；已經完成 → 慶祝。
class _CheerButton extends StatelessWidget {
  const _CheerButton({required this.celebrate, required this.cheered, required this.onTap});

  final bool celebrate;
  final bool cheered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (cheered) {
      label = celebrate ? '已慶祝 ✓' : '已集氣 ✓';
    } else {
      label = celebrate ? '🎉 慶祝' : '📣 集氣加油';
    }
    return PixelBox(
      color: cheered
          ? PixelColors.paper
          : celebrate
              ? PixelColors.orange
              : PixelColors.yellow,
      pressed: cheered,
      depth: 3,
      borderWidth: 2,
      onTap: cheered ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

/// 五大類各一顆直立的小電池。
class PillarBatteries extends StatelessWidget {
  const PillarBatteries({super.key, required this.energy, this.height = 30});

  final Map<Pillar, double> energy;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final pillar in Pillar.values) ...[
          if (pillar != Pillar.values.first) const SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message: '${pillar.tag} ${((energy[pillar] ?? 0) * 100).round()}%',
              child: Column(
                children: [
                  Container(
                    height: height,
                    padding: const EdgeInsets.all(2),
                    color: PixelColors.ink,
                    child: ColoredBox(
                      color: PixelColors.sand,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: energy[pillar] ?? 0,
                          widthFactor: 1,
                          child: ColoredBox(color: pillarColor(pillar)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(pillar.emoji, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TodayMark extends StatelessWidget {
  const _TodayMark({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: done ? '今天的每日項目都完成了' : '今天還沒全部完成',
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? PixelColors.yellow : PixelColors.sand,
          border: Border.all(
            color: done ? PixelColors.ink : PixelColors.muted.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: done ? const PixelText('✓', dot: 2) : null,
      ),
    );
  }
}
