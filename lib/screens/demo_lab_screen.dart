import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../widgets/flex/flex_card.dart';
import '../widgets/flex/milestone_celebration.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';
import 'flex_studio_screen.dart';

/// Demo Lab：還在實驗的新功能先放這裡試玩，確定了才放進正式的畫面。
class DemoLabScreen extends StatelessWidget {
  const DemoLabScreen({super.key, required this.store});

  final ChallengeStore store;

  void _openStudio(BuildContext context, {FlexStyle style = FlexStyle.pixel, FlexTemplate template = FlexTemplate.streak}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlexStudioScreen(store: store, initialStyle: style, initialTemplate: template),
      ),
    );
  }

  Future<void> _celebrate(BuildContext context) async {
    final player = flexDemoPlayer(store);
    final share = await showMilestoneCelebration(context, flexStatsOf(store, player));
    if (share == true && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FlexStudioScreen(
            store: store,
            initialStyle: FlexStyle.holo,
            initialTemplate: FlexTemplate.streak,
            playerId: player.id,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const PixelText('DEMO LAB', dot: 3, color: PixelColors.yellow)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final stats = flexStatsOf(store, flexDemoPlayer(store));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const PixelBox(
                    color: PixelColors.ink,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '🧪 還在實驗的新功能先放在這裡試玩。玩玩看、給意見，確定了才會放進正式的畫面。',
                      style: TextStyle(color: PixelColors.paper, fontWeight: FontWeight.w800, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(tag: 'NEW', title: '炫耀卡 SHOW OFF'),
                  const SizedBox(height: 8),
                  const Text(
                    '把連續打卡、最強項目、百日戰績、能力值做成圖卡，分享到 IG／Threads 限動、Discord、LINE。'
                    '有兩種風格，點一張開始做：',
                    style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final style in FlexStyle.values) ...[
                        if (style != FlexStyle.values.first) const SizedBox(width: 12),
                        Expanded(
                          child: _StyleThumb(
                            style: style,
                            onTap: () => _openStudio(context, style: style),
                            child: FlexCard(style: style, template: FlexTemplate.streak, format: FlexFormat.story, stats: stats),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionTitle(tag: 'NEW', title: '里程碑慶祝'),
                  const SizedBox(height: 8),
                  Text(
                    '連續打卡 ${streakMilestones.join('／')} 天時跳出慶祝畫面，翻開一張閃卡，一鍵炫耀。'
                    '（Duolingo 把這種時刻做成全螢幕慶祝後，分享量變成 5–10 倍。）',
                    style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  PixelBox(
                    color: PixelColors.yellow,
                    onTap: () => _celebrate(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        '▶ 模擬一次（連續 ${stats.streak} 天）',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '＊Demo：用「${stats.player.isMe ? '你' : stats.player.profile.name}」現在的連續天數模擬。'
                    '正式版會在打卡後剛好達到里程碑時自動跳出來。',
                    style: const TextStyle(fontSize: 11, color: PixelColors.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StyleThumb extends StatelessWidget {
  const _StyleThumb({required this.style, required this.onTap, required this.child});

  final FlexStyle style;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 9 / 16,
            // 縮圖不用接收點擊，點整張卡就打開工作室。
            child: IgnorePointer(child: FittedBox(child: child)),
          ),
          const SizedBox(height: 8),
          Text(style.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          Text(
            style.caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
        ],
      ),
    );
  }
}
