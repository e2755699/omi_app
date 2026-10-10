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
          const GuideBubble(text: '先自己走，也很好。\n不登入也可以打卡、寫心得、留下照片，紀錄會存在這台裝置。'),
          const SizedBox(height: 20),
          const PixelBox(
            padding: EdgeInsets.all(16),
            child: Text('本機使用時看不到其他玩家。\n之後想和夥伴一起，再從首頁登入。', style: TextStyle(height: 1.6)),
          ),
          const SizedBox(height: 20),
          if (account.isSignedIn) ...[
            const Text('Discord 已登入 ✓', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('登入後可從「帳號與資料」建立或加入群組。\n原本的本機紀錄，只有你選擇帶入時才會上傳。'),
            TextButton(onPressed: account.busy ? null : account.signOut, child: const Text('登出 Discord')),
          ] else ...[
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
              const Text('Discord 登入準備中，現在可以先在本機使用。', style: TextStyle(color: PixelColors.muted)),
            ],
          ],
          if (_error ?? account.message case final String message) ...[
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: PixelColors.muted)),
          ],
        ],
      );
    },
  );
}
