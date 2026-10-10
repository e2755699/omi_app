import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../data/home_widget_bridge.dart';
import '../models/challenge.dart';
import '../models/progress.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/player_card.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';
import 'daily_record_screen.dart';
import 'item_detail_sheet.dart';
import 'photo_wall_screen.dart';
import 'player_screen.dart';
import 'setup_tutorial.dart';
import 'weekly_screen.dart';
import 'widget_preview_screen.dart';
import 'account_screen.dart';

/// 首頁：挑戰進度 → 各項挑戰的能量槽 → 每日打卡 → 本週任務 → 大家的進度。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final ChallengeStore store;

  Future<void> _cheer(BuildContext context, Player player, WeekSummary summary) async {
    try {
      await store.cheer(player.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加油還沒送出，請確認連線後再試一次。')));
      }
      return;
    }
    if (!context.mounted) return;
    final name = player.profile.name;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(summary.todayComplete ? '你幫 $name 慶祝了 🎉' : '你幫 $name 集氣加油 📣')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final challenge = store.challenge;
        final summary = store.summary;
        final players = store.players;
        final summaries = [for (final player in players) player.summary(store.challengeFor(player), store.today)];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                PixelText(
                  '${formatShortDate(challenge.start)}-${formatShortDate(challenge.end)}',
                  dot: 2,
                  color: PixelColors.yellow,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '帳號與資料',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountScreen(account: store.account, store: store),
                  ),
                ),
              ),
              _DemoMenu(store: store),
              IconButton(
                tooltip: '重新設定',
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SetupTutorial(store: store))),
              ),
            ],
          ),
          body: isWideLayout(context)
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左欄固定：挑戰進度＋每日打卡。
                        SizedBox(
                          width: 400,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 8, 32),
                            children: [
                              if (store.previewDate != null) ...[
                                _PreviewBanner(store: store),
                                const SizedBox(height: 16),
                              ],
                              _ChallengeHud(store: store),
                              const SizedBox(height: 16),
                              _CheckInCard(store: store, summary: summary),
                              const SizedBox(height: 16),
                              _WeeklyCard(store: store),
                            ],
                          ),
                        ),
                        // 右欄：各項挑戰的能量槽＋大家的進度。
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              ..._energySlivers(context, summary, top: 24),
                              ..._playerSlivers(context, players, summaries),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: CustomScrollView(
                      slivers: [
                        if (store.previewDate != null)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            sliver: SliverToBoxAdapter(child: _PreviewBanner(store: store)),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          sliver: SliverToBoxAdapter(child: _ChallengeHud(store: store)),
                        ),
                        ..._energySlivers(context, summary, top: 24),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _CheckInCard(store: store, summary: summary),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          sliver: SliverToBoxAdapter(child: _WeeklyCard(store: store)),
                        ),
                        ..._playerSlivers(context, players, summaries),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  /// 各項挑戰的能量槽。
  List<Widget> _energySlivers(BuildContext context, WeekSummary summary, {required double top}) {
    final items = store.items;
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, top, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Expanded(
                child: SectionTitle(tag: 'ENERGY', title: '各項挑戰'),
              ),
              Text(
                '第 ${store.weekNumber} 週 ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
              ),
              PixelText('${summary.percent}%', dot: 2),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: EnergyTile.height,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => EnergyTile(
            item: items[i],
            progress: store.progress(items[i]),
            onTap: () => showItemDetailSheet(context, store, items[i]),
          ),
        ),
      ),
    ];
  }

  /// 大家的進度＋Demo 說明。
  List<Widget> _playerSlivers(BuildContext context, List<Player> players, List<WeekSummary> summaries) {
    if (players.length <= 1) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          sliver: SliverToBoxAdapter(
            child: PixelBox(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.isCloud ? '群組已連接' : '紀錄保存在這台裝置', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(store.isCloud ? '可從帳號與資料更新隊友、查看同步狀態。' : '想和夥伴一起時，再登入加入群組。'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountScreen(account: store.account, store: store),
                      ),
                    ),
                    child: const Text('帳號與資料'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final completeToday = summaries.where((s) => s.todayComplete).length;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Expanded(
                child: SectionTitle(tag: 'PLAYERS', title: '大家的進度'),
              ),
              if (store.phase == ChallengePhase.ongoing)
                Text(
                  '今天 $completeToday/${players.length} 人全完成',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: PlayerCard.height,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: players.length,
          itemBuilder: (context, i) => PlayerCard(
            player: players[i],
            summary: summaries[i],
            cheers: store.cheersFor(players[i].id),
            cheered: store.hasCheered(players[i].id),
            onCheer: store.phase == ChallengePhase.ongoing && !players[i].isMe
                ? () => _cheer(context, players[i], summaries[i])
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerScreen(store: store, playerId: players[i].id),
              ),
            ),
          ),
        ),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
        sliver: SliverToBoxAdapter(
          child: Text('＊這是 Demo：隊友是示範資料，你的紀錄只存在這台裝置。', style: TextStyle(fontSize: 11, color: PixelColors.muted)),
        ),
      ),
    ];
  }
}

/// 頂部黑色的「遊戲 HUD」：挑戰進度。
class _ChallengeHud extends StatelessWidget {
  const _ChallengeHud({required this.store});

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    final challenge = store.challenge;
    final today = store.today;
    final total = challenge.totalDays;
    final dayNumber = challenge.dayNumber(today);
    final remaining = total - dayNumber;
    final daysToStart = daysBetween(today, challenge.start);

    final achieved = store.me.completeDays(challenge, today);
    final (String tag, String big, String caption) = switch (store.phase) {
      ChallengePhase.notStarted => (
        'READY?',
        'D-$daysToStart',
        '還有 $daysToStart 天開始 · ${formatDate(challenge.start)} 開跑',
      ),
      ChallengePhase.ongoing => (
        'DAY',
        '$dayNumber/$total',
        '第 ${store.weekNumber} 週 · ${remaining == 0 ? '最後一天，衝啊！' : '還剩 $remaining 天'} · ⚡ 達成 $achieved 天',
      ),
      ChallengePhase.finished => ('CLEAR!', '$total/$total', '挑戰完成 🎉 達成 $achieved 天，辛苦大家了！'),
    };

    return PixelBox(
      color: PixelColors.ink,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(tag, dot: 3, color: PixelColors.orange),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PixelText(big, dot: 7, color: PixelColors.yellow),
          ),
          const SizedBox(height: 12),
          Text(
            caption,
            style: TextStyle(color: PixelColors.paper.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          PixelProgressBar(
            value: challenge.elapsedDays(today) / total,
            color: PixelColors.yellow,
            emptyColor: PixelColors.night,
          ),
        ],
      ),
    );
  }
}

/// 每日打卡：點進去是「每日紀錄」，在那裡勾項目、寫 Reflect。
class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.store, required this.summary});

  final ChallengeStore store;
  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final me = store.me;
    final ongoing = store.phase == ChallengePhase.ongoing;
    final checkedIn = ongoing && me.checkedInOn(store.challenge, store.today);
    final streak = me.checkInStreak(store.challenge, store.today);
    final achieved = me.completeDays(store.challenge, store.today);
    final cheers = store.cheersFor(me.id);

    final String label;
    if (store.phase == ChallengePhase.notStarted) {
      label = '${formatShortDate(store.challenge.start)} 開始打卡';
    } else if (store.phase == ChallengePhase.finished) {
      label = '挑戰已結束';
    } else {
      label = checkedIn ? '今天已打卡 · 點我編輯' : '每日打卡';
    }

    return PixelBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PixelText('DAILY', dot: 2, color: PixelColors.muted),
              const Spacer(),
              if (ongoing) _AchievedBadge(days: achieved),
            ],
          ),
          const SizedBox(height: 12),
          PixelBox(
            color: !ongoing
                ? PixelColors.sand
                : checkedIn
                ? PixelColors.paper
                : PixelColors.yellow,
            pressed: checkedIn || !ongoing,
            onTap: ongoing
                ? () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => DailyRecordScreen(store: store)))
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (checkedIn)
                  const PixelText('✓', dot: 3, color: PixelColors.green)
                else
                  const Text('📝', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: ongoing ? PixelColors.ink : PixelColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ongoing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '今天完成 ${summary.dailyDone}/${summary.dailyTotal} 個每日項目',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PixelColors.muted),
                  ),
                ),
                if (cheers > 0)
                  Text(
                    summary.todayComplete ? '🎉 $cheers 人幫你慶祝' : '📣 $cheers 人幫你加油',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
              ],
            ),
            // 連續天數保留，但放在不顯眼的位置（擁有者決定）。
            if (streak > 1) ...[
              const SizedBox(height: 4),
              Text(
                '🔥 連續記錄 $streak 天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PixelColors.muted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 每日項目全部完成的天數：首頁主要的數字。
class _AchievedBadge extends StatelessWidget {
  const _AchievedBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PixelColors.yellow,
        border: Border.all(color: PixelColors.ink, width: 2),
      ),
      child: Text('⚡ 達成 $days 天', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

/// 本週任務：每週回顧三題、一張照片。週五起變醒目，點了直接進去寫。
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.store});

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    final ongoing = store.phase == ChallengePhase.ongoing;
    final review = itemById('review');
    final answered = store.progress(review).value;
    final hasPhoto = store.photoOn(store.today) != null;
    final done = answered >= review.prompts.length && hasPhoto;
    final urgent = ongoing && !done && store.today.weekday >= DateTime.friday;
    return PixelBox(
      color: urgent ? PixelColors.yellow : PixelColors.paper,
      onTap: ongoing
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WeeklyScreen(store: store)))
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PixelText('WEEKLY', dot: 2, color: PixelColors.muted),
              const SizedBox(width: 8),
              Text(
                '第 ${store.weekNumber} 週',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
              ),
              const Spacer(),
              if (ongoing)
                IconButton(
                  tooltip: '照片牆',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => PhotoWallScreen(store: store))),
                  icon: const Icon(Icons.grid_view),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(done ? '本週任務完成 ✓' : '本週任務：回顧三題・一張照片', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              _WeeklyChip(label: '🔍 回顧 $answered/${review.prompts.length} 題', done: answered >= review.prompts.length),
              const SizedBox(width: 8),
              _WeeklyChip(label: hasPhoto ? '📷 照片已留' : '📷 照片還沒', done: hasPhoto),
              const Spacer(),
              if (ongoing) const Icon(Icons.chevron_right),
            ],
          ),
          if (urgent) ...[
            const SizedBox(height: 6),
            const Text('週日前寫好，一週一次就好', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _WeeklyChip extends StatelessWidget {
  const _WeeklyChip({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: done ? PixelColors.green.withValues(alpha: 0.2) : Colors.white,
        border: Border.all(color: PixelColors.ink, width: 2),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.store});

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      color: PixelColors.orange,
      depth: 0,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          const PixelText('DEMO', dot: 2),
          const SizedBox(width: 8),
          Expanded(
            child: Text('假裝今天是 ${formatDate(store.today)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(onPressed: () => store.setPreviewDate(null), child: const Text('用真的今天')),
        ],
      ),
    );
  }
}

enum _DemoAction { previewDate, addWidget, widgetPreview, reset, licenses }

/// Demo 工具：換日期看不同階段、把小工具加到桌面、清掉資料重新開始教學。
class _DemoMenu extends StatelessWidget {
  const _DemoMenu({required this.store});

  final ChallengeStore store;

  Future<void> _pickPreviewDate(BuildContext context) async {
    final challenge = store.challenge;
    final first = DateTime(challenge.start.year, challenge.start.month, challenge.start.day - 14);
    final last = DateTime(challenge.end.year, challenge.end.month, challenge.end.day + 14);
    var initial = store.today;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = challenge.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: '預覽哪一天的畫面？',
    );
    if (picked != null) await store.setPreviewDate(picked);
  }

  Future<void> _addWidget(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final requested = await HomeWidgetBridge.requestPin();
    if (!requested) {
      messenger.showSnackBar(const SnackBar(content: Text('請長按手機桌面 → 小工具 → 找「Omi」拖到桌面')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DemoAction>(
      tooltip: 'Demo 工具',
      icon: const Icon(Icons.science_outlined),
      onSelected: (action) async {
        switch (action) {
          case _DemoAction.previewDate:
            await _pickPreviewDate(context);
          case _DemoAction.addWidget:
            await _addWidget(context);
          case _DemoAction.widgetPreview:
            if (context.mounted) {
              await Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => WidgetPreviewScreen(store: store)));
            }
          case _DemoAction.reset:
            await store.resetAll();
          case _DemoAction.licenses:
            // App 本身保留所有權利；第三方開源元件的授權條款列在這頁。
            showLicensePage(
              context: context,
              applicationName: 'Omi',
              applicationLegalese: '© 2026 Dustin Liu. All rights reserved.',
            );
        }
      },
      itemBuilder: (_) => [
        if (!store.isCloud) const PopupMenuItem(value: _DemoAction.previewDate, child: Text('換一天看看（Demo 日期）')),
        const PopupMenuItem(value: _DemoAction.addWidget, child: Text('把小工具加到桌面（Android）')),
        const PopupMenuItem(value: _DemoAction.widgetPreview, child: Text('iOS 桌面小工具預覽（Demo）')),
        if (!store.isCloud) const PopupMenuItem(value: _DemoAction.reset, child: Text('清除本機資料，重新開始教學')),
        const PopupMenuItem(value: _DemoAction.licenses, child: Text('授權資訊')),
      ],
    );
  }
}
