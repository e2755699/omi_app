import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/challenge_store.dart';
import '../data/flex_share.dart';
import '../models/brag.dart';
import '../models/challenge.dart';
import '../models/progress.dart';
import '../widgets/flex/flex_card.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';

/// [player] 的戰績（名次跟所有參加者比）。
BragStats flexStatsOf(ChallengeStore store, Player player) =>
    BragStats.of(player, store.challenge, store.today, cheers: store.cheersFor(player.id), teammates: store.players);

/// Demo 預設看誰的卡：自己有紀錄就用自己，不然先拿最認真的示範隊友來看效果。
Player flexDemoPlayer(ChallengeStore store) {
  final players = store.players;
  if (flexStatsOf(store, players.first).hasRecords) return players.first;
  final ranked = [...players.skip(1)]
    ..sort((a, b) => flexStatsOf(store, b).overall.compareTo(flexStatsOf(store, a).overall));
  return ranked.isEmpty ? players.first : ranked.first;
}

/// 炫耀卡工作室：選風格、選要炫耀什麼、選尺寸，預覽後分享。
class FlexStudioScreen extends StatefulWidget {
  const FlexStudioScreen({
    super.key,
    required this.store,
    this.initialTemplate = FlexTemplate.streak,
    this.initialStyle = FlexStyle.pixel,
    this.playerId,
  });

  final ChallengeStore store;
  final FlexTemplate initialTemplate;
  final FlexStyle initialStyle;

  /// Demo：看誰的戰績。null 就是自己（自己還沒紀錄時改用示範隊友）。
  final String? playerId;

  @override
  State<FlexStudioScreen> createState() => _FlexStudioScreenState();
}

class _FlexStudioScreenState extends State<FlexStudioScreen> {
  final _cardKey = GlobalKey();
  late FlexTemplate _template = widget.initialTemplate;
  late FlexStyle _style = widget.initialStyle;
  FlexFormat _format = FlexFormat.story;
  late String _playerId = widget.playerId ?? _defaultPlayerId();

  /// 存圖的時候先把動畫停在最好看的那一格。
  bool _capturing = false;
  bool _busy = false;

  /// 閃卡可以用手指拖著轉，看反光。
  Offset _tilt = Offset.zero;

  ChallengeStore get _store => widget.store;

  BragStats _statsFor(Player player) => flexStatsOf(_store, player);

  String _defaultPlayerId() => flexDemoPlayer(_store).id;

  Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareImage(BuildContext buttonContext) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final origin = _originOf(buttonContext);
    setState(() {
      _busy = true;
      _capturing = true;
      _tilt = Offset.zero;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      final png = boundary == null ? null : await captureFlexCard(boundary);
      if (mounted) setState(() => _capturing = false);
      if (png == null) throw StateError('沒有畫面可以存');
      await shareFlexImage(png, fileName: 'omi-${_template.name}-${_style.name}.png', origin: origin);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('分享失敗：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _capturing = false;
        });
      }
    }
  }

  Future<void> _copyText(BragStats stats) async {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await Clipboard.setData(ClipboardData(text: flexShareText(_template, stats)));
      messenger.showSnackBar(const SnackBar(content: Text('已複製，貼到 Discord 或 LINE 吧 📋')));
    } catch (_) {
      // 有些瀏覽器不讓網頁寫剪貼簿。
      messenger.showSnackBar(const SnackBar(content: Text('這個瀏覽器不讓複製，請長按下面的文字版自己複製')));
    }
  }

  /// 分享圖片＋複製文字。手機上固定在最下面，不用捲就按得到。
  Widget _actions(BragStats stats) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Builder(
            builder: (buttonContext) => PixelBox(
              color: PixelColors.yellow,
              onTap: _busy ? null : () => _shareImage(buttonContext),
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Center(
                heightFactor: 1,
                child: Text(
                  _busy ? '準備圖片中…' : '📤 分享圖片',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PixelBox(
            onTap: () => _copyText(stats),
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: const Center(
              heightFactor: 1,
              child: Text('📋 複製文字', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final player = _store.playerById(_playerId) ?? _store.me;
        final stats = _statsFor(player);
        final wide = isWideLayout(context);
        final preview = _Preview(
          cardKey: _cardKey,
          format: _format,
          tiltable: _style == FlexStyle.holo && !_capturing,
          tilt: _tilt,
          onTilt: (tilt) => setState(() => _tilt = tilt),
          child: FlexCard(style: _style, template: _template, format: _format, stats: stats, animate: !_capturing),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('炫耀一下', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(child: PixelTag('DEMO LAB')),
              ),
            ],
          ),
          body: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: preview),
                    SizedBox(
                      width: 440,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 24, 32),
                        children: _controls(context, player, stats, actions: _actions(stats)),
                      ),
                    ),
                  ],
                )
              // 手機：預覽固定在上面，下面的選項捲動，邊選邊看得到效果。
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.48, child: preview),
                    Container(height: 3, color: PixelColors.ink),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: _controls(context, player, stats),
                      ),
                    ),
                  ],
                ),
          // 手機：分享按鈕固定在最下面，不用捲就按得到；提示訊息會浮在它上面。
          bottomNavigationBar: wide
              ? null
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    color: PixelColors.paper,
                    border: Border(top: BorderSide(color: PixelColors.ink, width: 3)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: _actions(stats)),
                  ),
                ),
        );
      },
    );
  }

  /// [actions]：寬螢幕時把分享按鈕放在尺寸說明下面；手機版的按鈕固定在畫面最下面，不放這裡。
  List<Widget> _controls(BuildContext context, Player player, BragStats stats, {Widget? actions}) {
    final notMe = !player.isMe;
    return [
      if (_store.phase == ChallengePhase.notStarted)
        const _Notice('挑戰還沒開始，還沒有戰績。右上角 🧪 →「換一天看看」換到挑戰中再來看。')
      else if (notMe && _playerId != widget.playerId && !_statsFor(_store.me).hasRecords)
        _Notice('你還沒有打卡紀錄，先用示範隊友「${player.profile.name}」的戰績看效果。'),
      const SectionTitle(tag: 'STYLE', title: '風格'),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final style in FlexStyle.values) ...[
            if (style != FlexStyle.values.first) const SizedBox(width: 10),
            Expanded(
              child: _StyleOption(
                style: style,
                selected: _style == style,
                onTap: () => setState(() {
                  _style = style;
                  _tilt = Offset.zero;
                }),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 20),
      const SectionTitle(tag: 'BRAG', title: '炫耀什麼'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final template in FlexTemplate.values)
            _Chip(
              label: '${template.emoji} ${template.label}',
              selected: _template == template,
              onTap: () => setState(() => _template = template),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const SectionTitle(tag: 'SIZE', title: '尺寸'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final format in FlexFormat.values)
            _Chip(label: format.label, selected: _format == format, onTap: () => setState(() => _format = format)),
        ],
      ),
      const SizedBox(height: 6),
      Text(switch (_format) {
        FlexFormat.story => 'IG／Threads 限動，1080×1920。',
        FlexFormat.post => 'IG、Threads 貼文，1080×1350。',
        FlexFormat.sticker => '去背的 PNG：在 IG 限動先放自己的照片，再把貼紙貼上去（像 Strava）。',
      }, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PixelColors.muted)),
      if (actions != null) ...[const SizedBox(height: 22), actions],
      const SizedBox(height: 22),
      const SectionTitle(tag: 'TEXT', title: '文字版（Discord／LINE）'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        color: PixelColors.sand.withValues(alpha: 0.6),
        child: SelectableText(
          flexShareText(_template, stats),
          style: const TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 24),
      const SectionTitle(tag: 'DEMO', title: '看誰的戰績'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final other in _store.players)
            _Chip(
              label: other.isMe ? '${other.profile.avatar} 我' : '${other.profile.avatar} ${other.profile.name}',
              selected: other.id == player.id,
              onTap: () => setState(() => _playerId = other.id),
            ),
        ],
      ),
      const SizedBox(height: 6),
      const Text('＊Demo 才能看隊友的卡。正式版只會分享自己的戰績。', style: TextStyle(fontSize: 11, color: PixelColors.muted)),
    ];
  }
}

/// 預覽區：灰白格子代表透明，卡片等比例縮到放得下。
class _Preview extends StatelessWidget {
  const _Preview({
    required this.cardKey,
    required this.format,
    required this.tiltable,
    required this.tilt,
    required this.onTilt,
    required this.child,
  });

  final GlobalKey cardKey;
  final FlexFormat format;
  final bool tiltable;
  final Offset tilt;
  final ValueChanged<Offset> onTilt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _Checker(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: GestureDetector(
            onPanUpdate: tiltable
                ? (details) => onTilt(
                    Offset(
                      (tilt.dx + details.delta.dx / 300).clamp(-0.45, 0.45),
                      (tilt.dy + details.delta.dy / 300).clamp(-0.45, 0.45),
                    ),
                  )
                : null,
            onPanEnd: tiltable ? (_) => onTilt(Offset.zero) : null,
            child: TweenAnimationBuilder<Offset>(
              tween: Tween(end: tilt),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (context, value, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(-value.dy)
                  ..rotateY(value.dx),
                child: child,
              ),
              child: FittedBox(
                child: RepaintBoundary(key: cardKey, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Checker extends CustomPainter {
  const _Checker();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFEDE6D2);
    final dark = Paint()..color = const Color(0xFFDCD3BA);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = ((y / cell).floor().isEven ? 0.0 : cell); x < size.width; x += cell * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => false;
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({required this.style, required this.selected, required this.onTap});

  final FlexStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = style == FlexStyle.holo;
    return PixelBox(
      color: selected ? PixelColors.yellow : PixelColors.paper,
      pressed: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: dark ? null : PixelColors.ink,
              gradient: dark
                  ? const LinearGradient(
                      colors: [Color(0xFF2A1659), Color(0xFFFFCC33), Color(0xFF63E6BE), Color(0xFFC59BFF)],
                    )
                  : null,
              borderRadius: dark ? BorderRadius.circular(8) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              dark ? '✦ SSR ✦' : '★ 8-BIT ★',
              style: TextStyle(
                color: dark ? Colors.white : PixelColors.yellow,
                fontWeight: FontWeight.w900,
                fontStyle: dark ? FontStyle.italic : FontStyle.normal,
                shadows: dark ? const [Shadow(color: Colors.black54, blurRadius: 6)] : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(style.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          Text(
            style.caption,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PixelColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      color: selected ? PixelColors.yellow : PixelColors.paper,
      pressed: selected,
      depth: 3,
      borderWidth: 2,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PixelBox(
        color: PixelColors.orange,
        depth: 0,
        padding: const EdgeInsets.all(10),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
