import 'package:flutter/material.dart';

import '../data/badge_claims.dart';
import '../data/challenge_store.dart';
import '../models/achievements.dart';
import '../models/progress.dart';
import '../widgets/badge_medal.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';
import 'badge_detail_sheet.dart';

/// 獎章牆：達成成就就解鎖獎章，解鎖的可以領取實體獎章（擺飾、魔鬼氈臂章、包包吊飾）。
/// 也可以看看隊友的獎章牆（示範資料）。
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  /// 實體獎章的申請狀態：打開這頁才讀。
  late final Future<BadgeClaims> _claims = BadgeClaims.load();
  String _playerId = 'me';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BadgeClaims>(
      future: _claims,
      builder: (context, snapshot) {
        final claims = snapshot.data;
        return ListenableBuilder(
          listenable: Listenable.merge([widget.store, claims]),
          builder: (context, _) => _buildPage(context, claims),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, BadgeClaims? claims) {
    final store = widget.store;
    final players = store.players;
    final player = store.playerById(_playerId) ?? store.me;
    final statuses = evaluateAchievements(player, store.challenge, store.today);
    final unlocked = statuses.where((s) => s.unlocked).length;
    final myClaims = player.isMe ? claims : null;
    final shipping = myClaims == null ? 0 : statuses.where((s) => myClaims.claimOf(s.achievement.id) != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          player.isMe ? '我的獎章' : '${player.profile.name} 的獎章',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _BadgeHud(unlocked: unlocked, total: statuses.length, shipping: shipping, isMe: player.isMe),
              const SizedBox(height: 22),
              const SectionTitle(tag: 'PLAYERS', title: '看看誰的獎章'),
              const SizedBox(height: 10),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: players.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _PlayerKey(
                    player: players[i],
                    selected: players[i].id == player.id,
                    onTap: () => setState(() => _playerId = players[i].id),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: SectionTitle(tag: 'BADGES', title: '獎章牆')),
                  const Text(
                    '點獎章看怎麼拿到',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: _BadgeTile.height,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: statuses.length,
                itemBuilder: (context, i) => _BadgeTile(
                  status: statuses[i],
                  claimed: myClaims?.claimOf(statuses[i].achievement.id) != null,
                  onTap: claims == null
                      ? null
                      : () => showBadgeDetailSheet(
                            context,
                            store: store,
                            claims: claims,
                            playerId: player.id,
                            achievement: statuses[i].achievement,
                          ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '＊這是 Demo：申請實體獎章只會記下狀態，不會真的寄出，也不會收集地址等個人資料。',
                style: TextStyle(fontSize: 11, color: PixelColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 頂部黑色的 HUD：解鎖了幾個獎章。
class _BadgeHud extends StatelessWidget {
  const _BadgeHud({required this.unlocked, required this.total, required this.shipping, required this.isMe});

  final int unlocked;
  final int total;
  final int shipping;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      color: PixelColors.ink,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelText('BADGES', dot: 3, color: PixelColors.orange),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PixelText('$unlocked/$total', dot: 7, color: PixelColors.yellow),
          ),
          const SizedBox(height: 12),
          Text(
            isMe
                ? '達成成就就會解鎖獎章，還能領取實體獎章：放在家裡當擺飾、用魔鬼氈貼在包包，或掛在包包上當吊飾。'
                : '隊友的獎章牆（示範資料）。實體獎章只有本人可以領取。',
            style: TextStyle(color: PixelColors.paper.withValues(alpha: 0.9), fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 14),
          PixelProgressBar(
            value: total == 0 ? 0 : unlocked / total,
            color: PixelColors.yellow,
            emptyColor: PixelColors.night,
            segments: total,
          ),
          if (shipping > 0) ...[
            const SizedBox(height: 10),
            Text(
              '📦 $shipping 個實體獎章寄送中（Demo）',
              style: const TextStyle(color: PixelColors.yellow, fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }
}

/// 切換要看誰的獎章牆。
class _PlayerKey extends StatelessWidget {
  const _PlayerKey({required this.player, required this.selected, required this.onTap});

  final Player player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Keycap(
        on: selected,
        color: PixelColors.yellow,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(player.profile.avatar, style: const TextStyle(fontSize: 20)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                player.isMe ? '我' : player.profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 獎章牆上的一格：獎章＋名稱＋進度。
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.status, required this.claimed, required this.onTap});

  static const height = 194.0;

  final AchievementStatus status;
  final bool claimed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final achievement = status.achievement;
    final unlocked = status.unlocked;
    final String label;
    if (claimed) {
      label = '📦 寄送中';
    } else if (unlocked) {
      label = '✓ 已解鎖';
    } else {
      label = '🔒 未解鎖';
    }

    return PixelBox(
      onTap: onTap,
      // 要用不透明的顏色，不然會透出 PixelBox 底下的硬陰影。
      color: unlocked ? PixelColors.paper : PixelColors.background,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: BadgeMedal(look: achievement.look, locked: !unlocked, dot: 3)),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: unlocked ? PixelColors.ink : PixelColors.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          PixelProgressBar(
            value: status.ratio,
            color: unlocked ? Color(achievement.look.face) : PixelColors.muted,
            segments: 10,
            height: 10,
          ),
          const SizedBox(height: 4),
          Text(
            status.progressLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
        ],
      ),
    );
  }
}
