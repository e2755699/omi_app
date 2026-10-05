import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../data/wish_bank.dart';
import '../models/challenge.dart';
import '../models/stars.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_sprite.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';

/// 許願時可以選的圖示。
const _wishEmojis = ['🎁', '👜', '🍣', '💆', '👟', '🎮', '🎧', '📚', '✈️', '🍰', '🎬', '🧸'];

/// 星星明細一開始只列最近幾筆。
const _ledgerPreview = 8;

/// Demo 選單一次塞進撲滿的星星。
const _demoBonus = 20;

const _mutedStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted);

typedef _WishDraft = ({String emoji, String title, int price});

/// 願望撲滿＋願望商城：打卡賺星星存進撲滿，再用星星兌換想要的犒賞。
class WishShopScreen extends StatefulWidget {
  const WishShopScreen({super.key, required this.store, this.bank});

  final ChallengeStore store;

  /// 首頁已經讀好的撲滿；沒給就自己讀。
  final WishBank? bank;

  @override
  State<WishShopScreen> createState() => _WishShopScreenState();
}

class _WishShopScreenState extends State<WishShopScreen> {
  WishBank? _bank;
  bool _showAllLedger = false;

  ChallengeStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _bank = widget.bank;
    if (_bank == null) {
      WishBank.load().then((bank) {
        if (mounted) setState(() => _bank = bank);
      });
    }
  }

  Future<void> _addWish(WishBank bank) async {
    final draft = await showModalBottomSheet<_WishDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddWishSheet(),
    );
    if (draft == null) return;
    await bank.addWish(emoji: draft.emoji, title: draft.title, price: draft.price);
  }

  Future<void> _redeem(WishBank bank, Wish wish, int earned) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmRedeemDialog(wish: wish, balance: bank.balance(earned)),
    );
    if (confirmed != true) return;
    final done = await bank.redeem(wish, earned: earned, date: _store.today);
    if (!done || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _CelebrationDialog(wish: wish, remaining: bank.balance(earned)),
    );
  }

  Future<void> _removeWish(WishBank bank, Wish wish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除「${wish.title}」？', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('兌換紀錄會保留。'),
        actions: [
          _DialogKey(label: '取消', onTap: () => Navigator.of(context).pop(false)),
          _DialogKey(label: '刪除', primary: true, onTap: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmed == true) await bank.removeWish(wish.id);
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    return Scaffold(
      appBar: AppBar(
        title: const Text('願望撲滿', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [if (bank != null) _ShopDemoMenu(bank: bank)],
      ),
      body: bank == null
          ? const SizedBox.shrink()
          : ListenableBuilder(
              listenable: Listenable.merge([_store, bank]),
              builder: (context, _) => _body(bank),
            ),
    );
  }

  Widget _body(WishBank bank) {
    final ledger = starLedgerOf(_store.me, _store.challenge, _store.today);
    final earned = ledger.total;
    final balance = bank.balance(earned);
    final wishes = bank.wishes;
    final redemptions = bank.redemptions.reversed.toList();
    final events = ledger.events.reversed.toList();
    final shownEvents = _showAllLedger ? events : events.take(_ledgerPreview).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _PiggyHeader(balance: balance, earned: earned, spent: bank.spent, bonus: bank.demoBonus),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: SectionTitle(tag: 'SHOP', title: '願望商城')),
                SizedBox(
                  width: 96,
                  height: 46,
                  child: Keycap(
                    onTap: () => _addWish(bank),
                    faceColor: PixelColors.yellow,
                    child: const Center(
                      child: Text('＋ 許願', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('存夠星星就能兌換，犒賞努力的自己。長按願望可以刪除。', style: _mutedStyle),
            const SizedBox(height: 12),
            if (wishes.isEmpty)
              const _EmptyHint('還沒有願望，按「＋ 許願」加一個吧！')
            else
              for (final wish in wishes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WishCard(
                    wish: wish,
                    balance: balance,
                    times: bank.timesRedeemed(wish.id),
                    onRedeem: bank.canRedeem(wish, earned) ? () => _redeem(bank, wish, earned) : null,
                    onLongPress: () => _removeWish(bank, wish),
                  ),
                ),
            const SizedBox(height: 18),
            const SectionTitle(tag: 'GOT', title: '兌換紀錄'),
            const SizedBox(height: 12),
            if (redemptions.isEmpty)
              const _EmptyHint('還沒有兌換過，繼續存星星！')
            else
              _RedemptionList(redemptions: redemptions),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: SectionTitle(tag: 'LOG', title: '星星明細')),
                Text('共賺到 $earned 顆', style: _mutedStyle),
              ],
            ),
            const SizedBox(height: 12),
            _RulesBox(ledger: ledger),
            const SizedBox(height: 10),
            if (events.isEmpty && bank.demoBonus == 0)
              const _EmptyHint('還沒有星星。去打卡吧，全勤一天就有 1 顆！')
            else
              _LedgerList(
                events: shownEvents,
                bonus: bank.demoBonus,
                hidden: events.length - shownEvents.length,
                onShowAll: () => setState(() => _showAllLedger = true),
              ),
            const SizedBox(height: 16),
            const Text(
              '＊這是 Demo：星星是從你的打卡紀錄算出來的，願望和兌換紀錄只存在這支手機。',
              style: TextStyle(fontSize: 11, color: PixelColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 黑色的撲滿看板：小豬＋還有幾顆星。
class _PiggyHeader extends StatelessWidget {
  const _PiggyHeader({required this.balance, required this.earned, required this.spent, required this.bonus});

  final int balance;
  final int earned;
  final int spent;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    final bonusText = bonus > 0 ? '＋Demo $bonus 顆' : '';
    return PixelBox(
      color: PixelColors.ink,
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 18),
      child: Row(
        children: [
          // 小豬放在亮色的小窗裡，黑色外框才看得到。
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const ShapeDecoration(
              color: PixelColors.background,
              shape: PixelBorder(color: PixelColors.yellow),
            ),
            child: const PixelPig(dot: 4),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PixelText('PIGGY BANK', dot: 2, color: PixelColors.orange),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const PixelStar(dot: 3),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PixelText('$balance', dot: 6, color: PixelColors.yellow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '賺到 $earned 顆$bonusText · 已兌換 $spent 顆',
                  style: TextStyle(
                    fontSize: 13,
                    color: PixelColors.paper.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 商城裡的一個願望：價格、存到幾成、兌換鍵。
class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.wish,
    required this.balance,
    required this.times,
    required this.onRedeem,
    required this.onLongPress,
  });

  final Wish wish;
  final int balance;
  final int times;

  /// 星星不夠時是 null，兌換鍵會變灰。
  final VoidCallback? onRedeem;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ready = balance >= wish.price;
    return GestureDetector(
      onLongPress: onLongPress,
      child: PixelBox(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ready ? PixelColors.yellow : PixelColors.sand,
                border: Border.all(color: PixelColors.ink, width: 2),
              ),
              child: Text(wish.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wish.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const PixelStar(dot: 2),
                      const SizedBox(width: 4),
                      PixelText('${wish.price}', dot: 2),
                      if (times > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '已兌換 ×$times',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: PixelColors.green),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  PixelProgressBar(
                    value: balance / wish.price,
                    color: ready ? PixelColors.green : PixelColors.orange,
                    segments: 10,
                    height: 12,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ready ? '星星夠了，可以兌換！' : '還差 ${wish.price - balance} 顆星',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              height: 58,
              child: Keycap(
                onTap: onRedeem,
                faceColor: ready ? PixelColors.yellow : const Color(0xFFFFFBF0),
                child: Center(
                  child: Text(
                    '兌換',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: onRedeem == null ? PixelColors.muted : PixelColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedemptionList extends StatelessWidget {
  const _RedemptionList({required this.redemptions});

  /// 新的在前。
  final List<Redemption> redemptions;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          for (final (i, redemption) in redemptions.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 2, color: PixelColors.sand),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(redemption.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(redemption.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('${formatDate(redemption.date)} 兌換', style: _mutedStyle),
                      ],
                    ),
                  ),
                  PixelText('-${redemption.stars}', dot: 2),
                  const SizedBox(width: 4),
                  const PixelStar(dot: 2),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 規則表：每條規則幾顆星、已經達成幾次。
class _RulesBox extends StatelessWidget {
  const _RulesBox({required this.ledger});

  final StarLedger ledger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PixelColors.sand.withValues(alpha: 0.6),
        border: Border.all(color: PixelColors.ink.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('怎麼賺星星', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final rule in StarRule.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Row(
                      children: [
                        const PixelStar(dot: 2),
                        const SizedBox(width: 3),
                        PixelText('+${rule.stars}', dot: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${rule.title}　', style: const TextStyle(fontWeight: FontWeight.w900)),
                          TextSpan(
                            text: rule.description,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: PixelColors.muted),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('×${ledger.countOf(rule)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text('參考：全部做到的話，一週最多賺 $maxStarsPerWeek 顆星', style: const TextStyle(fontSize: 11, color: PixelColors.muted)),
        ],
      ),
    );
  }
}

/// 星星明細：新的在前，太多時先收起來。
class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.events, required this.bonus, required this.hidden, required this.onShowAll});

  final List<StarEvent> events;
  final int bonus;
  final int hidden;
  final VoidCallback onShowAll;

  static String _emoji(StarEvent event) => switch (event.rule) {
        StarRule.perfectDay => '✅',
        StarRule.streak => '🔥',
        StarRule.fullPillar => event.pillar?.emoji ?? '⚡',
      };

  @override
  Widget build(BuildContext context) {
    final rows = [
      if (bonus > 0) _LedgerRow(date: null, emoji: '🧪', reason: 'Demo 加碼', stars: bonus),
      for (final event in events)
        _LedgerRow(date: event.date, emoji: _emoji(event), reason: event.reason, stars: event.stars),
    ];
    return PixelBox(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 2, color: PixelColors.sand),
            row,
          ],
          if (hidden > 0)
            TextButton(onPressed: onShowAll, child: Text('再顯示 $hidden 筆')),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.date, required this.emoji, required this.reason, required this.stars});

  final DateTime? date;
  final String emoji;
  final String reason;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(date == null ? 'Demo' : formatDate(date), style: _mutedStyle),
          ),
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          PixelText('+$stars', dot: 2, color: PixelColors.green),
          const SizedBox(width: 4),
          const PixelStar(dot: 2),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(text, style: const TextStyle(color: PixelColors.muted))),
    );
  }
}

/// 對話框底下的鍵帽按鈕。
class _DialogKey extends StatelessWidget {
  const _DialogKey({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 52,
      child: Keycap(
        onTap: onTap,
        faceColor: primary ? PixelColors.yellow : const Color(0xFFFFFBF0),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _ConfirmRedeemDialog extends StatelessWidget {
  const _ConfirmRedeemDialog({required this.wish, required this.balance});

  final Wish wish;
  final int balance;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('確定要兌換嗎？', style: TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(wish.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            wish.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            '要用掉 ${wish.price} 顆星，撲滿還剩 ${balance - wish.price} 顆',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
        ],
      ),
      actions: [
        _DialogKey(label: '再想想', onTap: () => Navigator.of(context).pop(false)),
        _DialogKey(label: '兌換！', primary: true, onTap: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}

/// 兌換成功的小慶祝：星星從願望旁邊炸開。
class _CelebrationDialog extends StatelessWidget {
  const _CelebrationDialog({required this.wish, required this.remaining});

  final Wish wish;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (context, t, _) => SizedBox(
                width: 200,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < 8; i++)
                      Transform.translate(
                        offset: Offset.fromDirection(i * math.pi / 4 - math.pi / 2, 62 * t),
                        child: const PixelStar(dot: 2),
                      ),
                    Transform.scale(
                      scale: 0.3 + 0.7 * t,
                      child: Text(wish.emoji, style: const TextStyle(fontSize: 56)),
                    ),
                  ],
                ),
              ),
            ),
            const PixelText('GET!', dot: 5, color: PixelColors.orange),
            const SizedBox(height: 14),
            Text(
              '兌換成功：${wish.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text('辛苦了，好好犒賞自己 🎉\n撲滿還剩 $remaining 顆星', textAlign: TextAlign.center, style: _mutedStyle),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: Keycap(
                faceColor: PixelColors.yellow,
                onTap: () => Navigator.of(context).pop(),
                child: const Center(
                  child: Text('好耶！', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 許願：選圖示、寫名字、用鍵帽調價格。
class _AddWishSheet extends StatefulWidget {
  const _AddWishSheet();

  @override
  State<_AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends State<_AddWishSheet> {
  final _title = TextEditingController();
  String _emoji = _wishEmojis.first;
  int _price = 10;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop<_WishDraft>((emoji: _emoji, title: title, price: _price));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _title.text.trim().isNotEmpty;
    Widget priceKey(int delta) => SizedBox(
          width: 62,
          height: 54,
          child: Keycap(
            onTap: () => setState(() => _price = (_price + delta).clamp(1, WishBank.maxPrice)),
            child: Center(
              child: Text(
                delta > 0 ? '+$delta' : '$delta',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        );

    return Padding(
      // 鍵盤跳出來時往上推。
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('許一個願望 🌠', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('存夠星星就能兌換，犒賞努力的自己', style: TextStyle(color: PixelColors.muted)),
            const SizedBox(height: 16),
            const Text('選一個圖示', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final emoji in _wishEmojis)
                  SizedBox(
                    width: 50,
                    height: 54,
                    child: Keycap(
                      on: emoji == _emoji,
                      onTap: () => setState(() => _emoji = emoji),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: '想要什麼？', hintText: '例如：新的跑鞋'),
            ),
            const SizedBox(height: 8),
            const Text('要幾顆星星？', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PixelStar(dot: 4),
                const SizedBox(width: 12),
                PixelText('$_price', dot: 6),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '參考：每天全勤 +1，全部做到的話一週最多 $maxStarsPerWeek 顆',
              textAlign: TextAlign.center,
              style: _mutedStyle,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final delta in const [-5, -1, 1, 5, 10]) priceKey(delta)],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: Keycap(
                onTap: ready ? _save : null,
                faceColor: PixelColors.yellow,
                child: Center(
                  child: Text(
                    '放進願望商城',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: ready ? PixelColors.ink : PixelColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShopDemoAction { bonus, reset }

/// Demo 工具：剛裝好時撲滿是空的，先塞一些星星才試得了兌換。
class _ShopDemoMenu extends StatelessWidget {
  const _ShopDemoMenu({required this.bank});

  final WishBank bank;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ShopDemoAction>(
      tooltip: 'Demo 工具',
      icon: const Icon(Icons.science_outlined),
      onSelected: (action) => switch (action) {
        _ShopDemoAction.bonus => bank.addDemoBonus(_demoBonus),
        _ShopDemoAction.reset => bank.resetDemo(),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ShopDemoAction.bonus, child: Text('撲滿裡先放 $_demoBonus 顆星（Demo）')),
        PopupMenuItem(value: _ShopDemoAction.reset, child: Text('願望商城回到預設（Demo）')),
      ],
    );
  }
}
