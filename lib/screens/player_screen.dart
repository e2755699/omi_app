import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/challenge.dart';
import '../widgets/energy_tile.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/player_card.dart';
import '../widgets/section_title.dart';

/// 某位參加者的進度：各項挑戰的能量槽＋最近的 Reflect。
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.store, required this.playerId});

  final ChallengeStore store;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final player = store.playerById(playerId);
        if (player == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('找不到這位參加者')));
        }
        final challenge = store.challenge;
        final today = store.today;
        final summary = player.summary(challenge, today);
        final items = player.items;
        final notes = player.recentNotes(challenge, today);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              player.isMe ? '我的進度' : player.profile.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  PixelBox(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        PlayerAvatar(profile: player.profile, size: 56),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.profile.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              PixelProgressBar(value: summary.energy, color: PixelColors.yellow, segments: 10),
                              const SizedBox(height: 4),
                              Text(
                                '本週能量 ${summary.percent}% · 今天 ${summary.dailyDone}/${summary.dailyTotal} 項',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PixelColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: SectionTitle(tag: 'ENERGY', title: '各項挑戰')),
                      Text(
                        '第 ${store.weekNumber} 週',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: EnergyTile.height,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => EnergyTile(
                      item: items[i],
                      progress: player.progress(items[i], challenge, today),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(tag: 'REFLECT', title: '最近注意到的事'),
                  const SizedBox(height: 10),
                  if (notes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('還沒有紀錄', style: TextStyle(color: PixelColors.muted))),
                    )
                  else
                    for (final (date, note) in notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PixelBox(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  PixelTag('DAY ${challenge.dayNumber(date)}'),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatDate(date),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: PixelColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('💭 $note', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
