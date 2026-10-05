import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/achievements.dart';
import '../screens/badges_screen.dart';
import 'badge_medal.dart';
import 'pixel_text.dart';
import 'pixel_ui.dart';
import 'section_title.dart';

/// 首頁的「我的獎章」：解鎖了幾個＋一排小獎章，點下去看整面獎章牆。
class BadgeStrip extends StatelessWidget {
  const BadgeStrip({super.key, required this.store});

  static const _dot = 2.0;
  static const _gap = 6.0;

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    final statuses = evaluateAchievements(store.me, store.challenge, store.today);
    final unlocked = [for (final s in statuses) if (s.unlocked) s];
    final locked = [for (final s in statuses) if (!s.unlocked) s];
    final next = locked.isEmpty ? null : locked.first;
    final medalWidth = BadgeMedal.sizeFor(_dot).width;

    return PixelBox(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => BadgesScreen(store: store)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PixelTag('BADGES'),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('我的獎章', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              PixelText('${unlocked.length}/${statuses.length}', dot: 2),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 12),
          // 解鎖的排前面，放得下幾個就放幾個。
          LayoutBuilder(
            builder: (context, constraints) {
              final fit = ((constraints.maxWidth + _gap) / (medalWidth + _gap)).floor();
              final shown = [...unlocked, ...locked].take(fit.clamp(1, statuses.length));
              return Row(
                children: [
                  for (final (i, status) in shown.indexed) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    BadgeMedal(look: status.achievement.look, locked: !status.unlocked, dot: _dot),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            next == null
                ? '全部解鎖了！可以去領實體獎章 🎉'
                : '下一個：${next.achievement.title} · ${next.progressLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
        ],
      ),
    );
  }
}
