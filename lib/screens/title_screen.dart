import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';
import '../widgets/sisyphus_scene.dart';

const _story = '希臘神話裡的薛西弗斯（Σίσυφος），每天把一顆大石頭推上山頂；'
    '石頭滾下來，隔天再推一次。\n'
    '卡繆說：「我們必須想像薛西弗斯是快樂的。」\n'
    '好習慣也是這樣——沒有一次就攻頂這種事，只有每天，再推一次。\n'
    'Omi 陪你把接下來 100 天的每一次推石頭，變成看得見的能量、聽得到的加油。';

const _purposes = [
  ('🪨', '每天推一點', '把 The Rules 拆成一顆顆鍵帽，按下去就是今天的一小步'),
  ('⚡', '看得見的進步', '每一項挑戰都有能量槽，推一次亮一格'),
  ('📣', '一起推比較不累', '隊友會幫你集氣，完成了大家一起慶祝'),
];

/// STEP 0：打開 App 的第一個畫面，介紹 Omi 是什麼，按「開始挑戰」才進教學。
/// 寬螢幕左右分欄：左邊標題＋推石頭動畫，右邊故事。
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.challenge, required this.onStart});

  final Challenge challenge;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    return Scaffold(
      body: SafeArea(child: wide ? _wide() : _narrow()),
    );
  }

  Widget _narrow() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(dot: 12),
                    const SizedBox(height: 20),
                    const PixelBox(child: SisyphusScene()),
                    const SizedBox(height: 18),
                    ..._storyAndPurposes(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: _startKey(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wide() {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(dot: 16),
                        const SizedBox(height: 28),
                        const PixelBox(child: SisyphusScene(height: 220)),
                        const SizedBox(height: 28),
                        _startKey(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _storyAndPurposes(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({required double dot}) {
    return Column(
      children: [
        PixelText('OMI', dot: dot),
        const SizedBox(height: 14),
        const Text(
          '～ 快樂的 Σίσυφος ～',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          '${challenge.totalDays} 天挑戰 · ${formatShortDate(challenge.start)} – ${formatShortDate(challenge.end)}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: PixelColors.muted),
        ),
      ],
    );
  }

  List<Widget> _storyAndPurposes() => [
        const PixelBox(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelTag('STORY'),
              SizedBox(height: 10),
              Text(_story, style: TextStyle(fontSize: 15, height: 1.7, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final (emoji, title, description) in _purposes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PixelBox(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PixelColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ];

  Widget _startKey() {
    return SizedBox(
      height: 64,
      child: Keycap(
        faceColor: PixelColors.yellow,
        onTap: onStart,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('開始挑戰', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(width: 10),
            PixelText('>', dot: 3),
          ],
        ),
      ),
    );
  }
}
