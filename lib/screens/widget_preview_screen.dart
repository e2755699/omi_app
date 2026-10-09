import 'package:flutter/material.dart';

import '../data/challenge_store.dart';
import '../models/challenge.dart';
import '../models/rules.dart';
import '../widgets/energy_tile.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import 'daily_record_screen.dart';

/// Demo：iOS 桌面小工具長什麼樣子。用 Flutter 畫在假的 iPhone 桌面上，
/// 確認 UI 之後再用 WidgetKit 做成真的。鍵帽可以按，會直接幫今天打卡。
class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({super.key, required this.store});

  final ChallengeStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iOS 桌面小工具（預覽）', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final width = MediaQuery.sizeOf(context).width;
          // iOS 的中尺寸小工具大約 338×158 pt，小尺寸 158×158。
          final medium = (width - 48).clamp(240.0, 338.0);
          final scale = medium / 338;
          final small = 158 * scale;
          final height = 158 * scale;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                '桌面上顯示收到的加油數和今天的鍵帽。iOS 17 以上可以直接在桌面按鍵帽打卡；'
                '更舊的版本點了會打開 App。下面的鍵帽可以按，會真的幫今天打卡。',
                style: TextStyle(fontSize: 13, color: PixelColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              _Wallpaper(
                child: Column(
                  children: [
                    const _Label('中尺寸（4×2）'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: medium,
                      height: height,
                      child: _OmiWidget(store: store, columns: 4, scale: scale),
                    ),
                    const SizedBox(height: 20),
                    const _Label('小尺寸（2×2）'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: small,
                          height: height,
                          child: _OmiWidget(store: store, columns: 2, scale: scale),
                        ),
                        SizedBox(width: 22 * scale),
                        _FakeIcons(size: small, scale: scale),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FakeIconRow(scale: scale),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '備註：iOS 會把小工具切成圓角，所以外框用圓角、裡面維持像素風。'
                '真的做成 WidgetKit 之後，字型和鍵帽會用 SwiftUI 重畫，樣子以這個為準。',
                style: TextStyle(fontSize: 12, color: PixelColors.muted, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 小工具本體：黑色頂條（第幾天、加油數）＋鍵帽＋底下的「寫 Reflect」。
class _OmiWidget extends StatelessWidget {
  const _OmiWidget({required this.store, required this.columns, required this.scale});

  final ChallengeStore store;
  final int columns;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final challenge = store.challenge;
    final today = store.today;
    final ongoing = store.isSetUp && store.phase == ChallengePhase.ongoing;
    final keys = [
      for (final item in store.items)
        if (item.pillar != Pillar.reflect) item,
    ].take(columns * 2).toList();
    final done = keys.where((item) => store.entryOn(item, today).isDone).length;
    final cheers = store.cheersFor(store.me.id);
    final complete = store.summary.todayComplete;

    final dayText = switch (store.phase) {
      ChallengePhase.notStarted => 'D-${daysBetween(today, challenge.start)}',
      ChallengePhase.ongoing => 'DAY ${challenge.dayNumber(today)}/${challenge.totalDays}',
      ChallengePhase.finished => 'CLEAR!',
    };
    final cheersText = complete ? '🎉 $cheers 人幫你慶祝' : '📣 $cheers 人幫你加油';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22 * scale),
      child: Container(
        color: PixelColors.ink,
        padding: EdgeInsets.all(3 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8 * scale, 4 * scale, 8 * scale, 5 * scale),
              child: Row(
                children: [
                  PixelText(dayText, dot: 2 * scale, color: PixelColors.yellow),
                  const Spacer(),
                  if (columns > 2 && ongoing)
                    Text(
                      cheersText,
                      style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w900, color: PixelColors.paper),
                    ),
                  if (columns == 2 && ongoing)
                    Text(
                      '${complete ? '🎉' : '📣'} $cheers',
                      style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w900, color: PixelColors.paper),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: PixelColors.background,
                padding: EdgeInsets.all(4 * scale),
                child: !ongoing
                    ? Center(
                        child: Text(
                          store.isSetUp ? '${formatShortDate(challenge.start)} 開始打卡' : '打開 App 完成設定',
                          style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w900),
                        ),
                      )
                    : Column(
                        children: [
                          for (var row = 0; row < 2; row++)
                            Expanded(
                              child: Row(
                                children: [
                                  for (var col = 0; col < columns; col++)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(2 * scale),
                                        child: row * columns + col < keys.length
                                            ? _WidgetKey(
                                                store: store,
                                                item: keys[row * columns + col],
                                                scale: scale,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            if (ongoing)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => DailyRecordScreen(store: store)),
                ),
                child: Container(
                  color: PixelColors.ink,
                  padding: EdgeInsets.fromLTRB(8 * scale, 4 * scale, 8 * scale, 3 * scale),
                  child: Text(
                    columns > 2 ? '今天 $done/${keys.length} 項 · ✏️ 寫 Reflect ›' : '$done/${keys.length} · ✏️ Reflect ›',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w900, color: PixelColors.paper),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WidgetKey extends StatelessWidget {
  const _WidgetKey({required this.store, required this.item, required this.scale});

  final ChallengeStore store;
  final ChallengeItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final on = store.entryOn(item, store.today).isDone;
    final color = pillarColor(item.pillar);
    return Keycap(
      on: on,
      color: color,
      travel: 2 * scale,
      thickness: 0.5,
      onTap: () => store.quickToggle(item),
      // 小工具的鍵帽很矮，emoji 和名字放同一行才塞得下。
      child: Center(
        child: Text(
          // 打卡後用 ✓ 取代 emoji，字數不變才不會被截掉。
          '${on ? '✓' : item.emoji} ${item.shortTitle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11 * scale,
            fontWeight: FontWeight.w900,
            color: on ? onColor(color) : PixelColors.ink,
          ),
        ),
      ),
    );
  }
}

/// 假的 iPhone 桌布，讓小工具看起來像放在桌面上。
class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B3A67), Color(0xFF5B2A86), Color(0xFF1C2541)],
        ),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70),
    );
  }
}

/// 小工具旁邊的 2×2 假 App 圖示。
class _FakeIcons extends StatelessWidget {
  const _FakeIcons({required this.size, required this.scale});

  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final icon = 60 * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var row = 0; row < 2; row++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var col = 0; col < 2; col++)
                  _FakeIcon(size: icon, color: _iconColors[(row * 2 + col) % _iconColors.length]),
              ],
            ),
        ],
      ),
    );
  }
}

class _FakeIconRow extends StatelessWidget {
  const _FakeIconRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 4; i++) _FakeIcon(size: 60 * scale, color: _iconColors[(i + 1) % _iconColors.length]),
      ],
    );
  }
}

const _iconColors = [Color(0xFF34C759), Color(0xFF007AFF), Color(0xFFFF9500), Color(0xFFFF2D55), Color(0xFF5856D6)];

class _FakeIcon extends StatelessWidget {
  const _FakeIcon({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
    );
  }
}
