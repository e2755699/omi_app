import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';
import '../widgets/week_strip.dart';
import 'daily_record_screen.dart';

Future<void> showItemDetailSheet(BuildContext context, ChallengeStore store, ChallengeItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ItemDetailSheet(store: store, item: item),
  );
}

/// 點首頁能量槽打開：規則、我的目標、這週每天的狀況。
class ItemDetailSheet extends StatelessWidget {
  const ItemDetailSheet({super.key, required this.store, required this.item});

  final ChallengeStore store;
  final ChallengeItem item;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final challenge = store.challenge;
        final today = store.today;
        final progress = store.progress(item);
        final color = pillarColor(item.pillar);
        final week = challenge.weekOf(challenge.clamp(today));
        final notes = _notesThisWeek(week);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PixelTag(item.pillar.tag),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item.emoji} ${item.title}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.rule, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                color: PixelColors.sand.withValues(alpha: 0.6),
                child: Text(
                  '🎯 我的目標：${itemTarget(item, store.profile)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  PixelTag('WEEK ${store.weekNumber}'),
                  const SizedBox(width: 10),
                  const Text('本週能量', style: TextStyle(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(progressText(item, progress), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              PixelCellsBar(cells: progress.cells, color: color, height: 18),
              if (item.kind != ItemKind.weekly) ...[
                const SizedBox(height: 16),
                WeekStrip(
                  color: color,
                  days: [
                    for (final day in week)
                      WeekStripDay(
                        date: day,
                        inChallenge: challenge.contains(day),
                        filled: !day.isAfter(today) && store.entryOn(item, day).isDone,
                        highlighted: day == today,
                        caption: item.kind == ItemKind.weeklyAmount && store.entryOn(item, day).isDone
                            ? '${store.entryOn(item, day).amount}'
                            : null,
                      ),
                  ],
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('這週寫的', style: TextStyle(fontWeight: FontWeight.w900)),
                for (final note in notes) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: PixelColors.ink.withValues(alpha: 0.2), width: 2),
                    ),
                    child: Text(note, style: const TextStyle(height: 1.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
              if (store.canLogOn(today)) ...[
                const SizedBox(height: 24),
                PixelBox(
                  color: PixelColors.yellow,
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(MaterialPageRoute<void>(builder: (_) => DailyRecordScreen(store: store)));
                  },
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Center(
                    child: Text('📝 去每日紀錄填寫', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<String> _notesThisWeek(List<DateTime> week) {
    if (!item.needsWriting) return const [];
    if (item.kind == ItemKind.weekly) {
      final notes = store.entryOn(item, week.first).notes;
      return [
        for (var i = 0; i < notes.length && i < item.prompts.length; i++)
          if (notes[i].isNotEmpty) '${item.prompts[i]}\n${notes[i]}',
      ];
    }
    return [
      for (final day in week)
        if (store.entryOn(item, day).notes case [final note, ...] when note.isNotEmpty) '${formatShortDateOf(day)}　$note',
    ];
  }
}

String formatShortDateOf(DateTime day) => '${day.month}/${day.day}';
