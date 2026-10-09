import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../data/photo_store.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';
import 'weekly_screen.dart';

/// 照片牆：挑戰的每一週一格，結束時就是這段日子的縮影。
/// 現在只有自己的；後端上線後會變成大家一起的照片牆。
class PhotoWallScreen extends StatelessWidget {
  const PhotoWallScreen({super.key, required this.store});

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final challenge = store.challenge;
        final today = store.today;
        final currentWeek = challenge.weekNumber(challenge.clamp(today));
        final weeks = [
          for (var w = 1; w <= challenge.totalWeeks; w++)
            (w, DateTime(challenge.start.year, challenge.start.month, challenge.start.day + (w - 1) * 7)),
        ];
        final filled = weeks.where((week) => store.photoOn(challenge.clamp(week.$2)) != null).length;

        return Scaffold(
          appBar: AppBar(title: const Text('照片牆', style: TextStyle(fontWeight: FontWeight.w900))),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const PixelTag('WALL', dot: 3),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('每週一張，留下這段日子', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          ),
                          PixelText('$filled/${challenge.totalWeeks}', dot: 3),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: weeks.length,
                      itemBuilder: (context, i) {
                        final (week, monday) = weeks[i];
                        final date = challenge.clamp(monday);
                        final image = PhotoStore.image(store.photoOn(date));
                        final reachable = week <= currentWeek;
                        return GestureDetector(
                          onTap: reachable
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => WeeklyScreen(store: store, date: date)),
                                  )
                              : null,
                          child: Container(
                            decoration: ShapeDecoration(
                              color: image != null
                                  ? PixelColors.ink
                                  : reachable
                                      ? PixelColors.paper
                                      : PixelColors.sand,
                              shape: PixelBorder(color: reachable ? PixelColors.ink : PixelColors.muted),
                              image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
                            ),
                            child: Stack(
                              children: [
                                if (image == null)
                                  Center(
                                    child: PixelText(
                                      'W$week',
                                      dot: 3,
                                      color: reachable ? PixelColors.muted : PixelColors.muted.withValues(alpha: 0.5),
                                    ),
                                  ),
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: PixelTag(week == currentWeek ? 'WEEK $week ·NOW' : 'WEEK $week'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '＊現在只有自己的照片；後端上線後，會變成大家一起的照片牆。',
                        style: TextStyle(fontSize: 11, color: PixelColors.muted),
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
