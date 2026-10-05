import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../data/wish_bank.dart';
import '../models/stars.dart';
import '../screens/wish_shop_screen.dart';
import 'pixel_sprite.dart';
import 'pixel_text.dart';
import 'pixel_ui.dart';

/// 首頁右上角的星星數（撲滿裡還有幾顆），點一下打開願望撲滿。
class StarCounter extends StatefulWidget {
  const StarCounter({super.key, required this.store});

  final ChallengeStore store;

  @override
  State<StarCounter> createState() => _StarCounterState();
}

class _StarCounterState extends State<StarCounter> {
  WishBank? _bank;

  @override
  void initState() {
    super.initState();
    WishBank.load().then((bank) {
      if (mounted) setState(() => _bank = bank);
    });
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WishShopScreen(store: widget.store, bank: _bank)),
    );
    // 商城可能是自己讀的撲滿，回來時再同步一次。
    _bank?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final bank = _bank;
    return ListenableBuilder(
      listenable: Listenable.merge([store, ?bank]),
      builder: (context, _) {
        final earned = starLedgerOf(store.me, store.challenge, store.today).total;
        final stars = bank?.balance(earned) ?? earned;
        return Tooltip(
          message: '願望撲滿',
          child: Semantics(
            button: true,
            label: '願望撲滿，有 $stars 顆星',
            excludeSemantics: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _open,
                child: Padding(
                  // 外面留空間，讓按的範圍夠大。
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(7, 6, 9, 6),
                      decoration: const ShapeDecoration(
                        color: PixelColors.night,
                        shape: PixelBorder(width: 2, color: PixelColors.yellow),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PixelStar(dot: 2),
                          const SizedBox(width: 6),
                          PixelText('$stars', dot: 2, color: PixelColors.yellow),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
