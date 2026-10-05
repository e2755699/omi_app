import 'package:flutter/material.dart';

import '../data/badge_claims.dart';
import '../data/challenge_store.dart';
import '../models/achievements.dart';
import '../models/challenge.dart';
import '../models/progress.dart';
import '../widgets/badge_medal.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';

Future<void> showBadgeDetailSheet(
  BuildContext context, {
  required ChallengeStore store,
  required BadgeClaims claims,
  required String playerId,
  required Achievement achievement,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BadgeDetailSheet(store: store, claims: claims, playerId: playerId, achievement: achievement),
  );
}

/// 點獎章打開：說明、進度，解鎖了就能選款式領取實體獎章（Demo）。
class BadgeDetailSheet extends StatefulWidget {
  const BadgeDetailSheet({
    super.key,
    required this.store,
    required this.claims,
    required this.playerId,
    required this.achievement,
  });

  final ChallengeStore store;
  final BadgeClaims claims;
  final String playerId;
  final Achievement achievement;

  @override
  State<BadgeDetailSheet> createState() => _BadgeDetailSheetState();
}

class _BadgeDetailSheetState extends State<BadgeDetailSheet> {
  BadgeForm? _form;

  Achievement get _achievement => widget.achievement;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.claims]),
      builder: (context, _) {
        final player = store.playerById(widget.playerId) ?? store.me;
        final status = _achievement.evaluate(BadgeStats.of(player, store.challenge, store.today));
        final unlocked = status.unlocked;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PixelTag(unlocked ? 'UNLOCKED' : 'LOCKED'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_achievement.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(child: BadgeMedal(look: _achievement.look, locked: !unlocked, dot: 6)),
              const SizedBox(height: 16),
              Text(
                _achievement.description,
                style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                color: PixelColors.sand.withValues(alpha: 0.6),
                child: Text('🎯 怎麼拿到：${_achievement.howTo}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const PixelTag('PROGRESS'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      unlocked ? '已解鎖！' : '還沒解鎖',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(status.progressLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              PixelProgressBar(value: status.ratio, color: Color(_achievement.look.face), height: 18),
              const SizedBox(height: 26),
              const SectionTitle(tag: 'REAL', title: '實體獎章'),
              const SizedBox(height: 6),
              const Text(
                '解鎖的獎章可以換成實體的：放在家裡當擺飾、用魔鬼氈貼在包包上，或掛在包包上當吊飾。',
                style: TextStyle(fontSize: 12, height: 1.4, color: PixelColors.muted),
              ),
              const SizedBox(height: 14),
              ..._claimSection(player, status),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _claimSection(Player player, AchievementStatus status) {
    if (!player.isMe) {
      return [
        Text(
          '這是 ${player.profile.name} 的獎章，實體獎章只有本人可以領取。',
          style: const TextStyle(fontWeight: FontWeight.w700, color: PixelColors.muted),
        ),
      ];
    }

    final claim = widget.claims.claimOf(_achievement.id);
    if (claim != null) {
      return [
        PixelBox(
          color: PixelColors.yellow,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📦', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('已申請，寄送中（Demo）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '款式：${claim.form.emoji} ${claim.form.label} · ${formatDate(claim.requestedOn)} 申請',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '＊Demo 只記下申請狀態，不會真的寄出，也不會收集地址等個人資料。',
          style: TextStyle(fontSize: 11, color: PixelColors.muted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => widget.claims.cancel(_achievement.id),
            child: const Text('取消申請（Demo）'),
          ),
        ),
      ];
    }

    final unlocked = status.unlocked;
    final form = _form;
    final String hint;
    if (!unlocked) {
      hint = '解鎖後才能領取，先看看有哪些款式';
    } else if (form == null) {
      hint = '選一種款式';
    } else {
      hint = '選好了：${form.emoji} ${form.label}';
    }

    return [
      Text(hint, style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in BadgeForm.values) ...[
            if (option != BadgeForm.values.first) const SizedBox(width: 8),
            Expanded(
              child: _FormKey(
                form: option,
                selected: unlocked && form == option,
                onTap: unlocked ? () => setState(() => _form = option) : null,
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 60,
        child: Keycap(
          faceColor: PixelColors.yellow,
          onTap: unlocked && form != null ? () => widget.claims.request(status, form, widget.store.today) : null,
          child: Center(
            child: Text(
              unlocked ? '領取實體獎章' : '🔒 解鎖後才能領取',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: unlocked && form != null ? PixelColors.ink : PixelColors.muted,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// 實體獎章的款式：用鍵帽選，選了就按下去亮起來。
class _FormKey extends StatelessWidget {
  const _FormKey({required this.form, required this.selected, required this.onTap});

  final BadgeForm form;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: 112,
      child: Keycap(
        on: selected,
        color: PixelColors.yellow,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(form.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 2),
              Text(
                form.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: enabled ? PixelColors.ink : PixelColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                form.hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w700, color: PixelColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
