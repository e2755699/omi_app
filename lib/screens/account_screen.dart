import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../data/challenge_store.dart';
import 'group_panel.dart';
import '../widgets/guide_bubble.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/section_title.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.account, this.store});

  final AccountController account;
  final ChallengeStore? store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('帳號與資料')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AccountPanel(account: account),
            if (store != null)
              ListenableBuilder(
                listenable: account,
                builder: (context, _) => account.isSignedIn
                    ? GroupPanel(key: ValueKey(account.userId), store: store!)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 教學最後一步與首頁共用；登入不會自動上傳使用者的本機資料。
class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.account, this.beforeSignIn});

  final AccountController account;
  final Future<void> Function()? beforeSignIn;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  bool _saving = false;
  String? _error;

  Future<void> _login() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.beforeSignIn?.call();
      await widget.account.signInWithDiscord();
    } catch (_) {
      if (mounted) setState(() => _error = '設定還沒存好，請再試一次。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.account,
    builder: (context, _) {
      final account = widget.account;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(tag: 'ACCOUNT', title: '用你喜歡的方式開始'),
          const SizedBox(height: 16),
          if (account.isSignedIn) ...[
            const GuideBubble(text: '歡迎上車！🎉\n接下來到「帳號與資料」開一個小隊，或用邀請碼找到你的夥伴，一起互相加油。'),
            const SizedBox(height: 20),
            const Text('Discord 已登入 ✓', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('之前留在這台裝置的紀錄，要等你點頭帶過去才會上傳。'),
            TextButton(onPressed: account.busy ? null : account.signOut, child: const Text('登出 Discord')),
          ] else ...[
            const GuideBubble(text: '想一個人慢慢走，或找夥伴一起走，都很好。\n先不登入也能打卡、寫心得、留下照片，紀錄會好好收在這台裝置裡。'),
            const SizedBox(height: 20),
            const PixelBox(
              padding: EdgeInsets.all(16),
              child: Text('登入 Discord，就能和夥伴組隊、互相加油。\n現在還不想決定也沒關係，之後隨時能從首頁回來找我。', style: TextStyle(height: 1.6)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 64,
              child: Keycap(
                onTap: account.configured && !account.busy && !_saving ? _login : null,
                color: PixelColors.yellow,
                child: Text(
                  account.busy || _saving ? '正在開啟登入…' : '使用 Discord 登入',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            if (!account.configured) ...[
              const SizedBox(height: 10),
              const Text('Discord 登入還在準備中，先自己走走，之後再來找夥伴。', style: TextStyle(color: PixelColors.muted)),
            ],
          ],
          if (_error ?? account.message case final String message) ...[
            const SizedBox(height: 16),
            PixelBox(
              color: PixelColors.sand,
              depth: 3,
              padding: const EdgeInsets.all(14),
              child: Text(message, style: const TextStyle(height: 1.6, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      );
    },
  );
}
