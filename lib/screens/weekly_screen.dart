import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/challenge_store.dart';
import '../data/photo_store.dart';
import '../models/challenge.dart';
import '../models/rules.dart';
import '../widgets/keycap.dart';
import '../widgets/pixel_text.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/responsive.dart';
import '../widgets/section_title.dart';
import 'photo_wall_screen.dart';

/// 本週任務：每週回顧三題＋這週的一張照片。從首頁的「本週任務」卡或照片牆進來。
class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key, required this.store, this.date});

  final ChallengeStore store;

  /// 要看哪一週（那週的任何一天）；不給就是今天這週。
  final DateTime? date;

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  static final _review = itemById('review');
  static final _noticed = itemById('noticed');

  late final DateTime _date = widget.store.challenge.clamp(widget.date ?? widget.store.today);
  late final _answers = [
    for (var i = 0; i < _review.prompts.length; i++)
      TextEditingController(text: _noteAt(i)),
  ];
  bool _busy = false;

  ChallengeStore get _store => widget.store;

  String _noteAt(int i) {
    final notes = _store.entryOn(_review, _date).notes;
    return i < notes.length ? notes[i] : '';
  }

  @override
  void dispose() {
    for (final controller in _answers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final answers = [for (final controller in _answers) controller.text];
    await _store.saveNotes(_review, _date, answers);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final ref = await PhotoStore.pick(source: source, key: 'W${dateKey(weekStart(_date))}');
      if (ref != null) await _store.setPhoto(_date, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final challenge = _store.challenge;
          final week = challenge.weekOf(_date);
          final inWeek = week.where(challenge.contains).toList();
          final editable = _store.canLogOn(inWeek.first);
          final photo = _store.photoOn(_date);
          final answered = _store.progress(_review).value;
          final noticedThisWeek = [
            for (final day in inWeek)
              if (!day.isAfter(_store.today))
                if (_store.entryOn(_noticed, day).notes case [final note, ...] when note.isNotEmpty) (day, note),
          ];

          final review = [
            Row(
              children: [
                PixelTag('WEEK ${challenge.weekNumber(_date)}', dot: 3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${formatShortDate(inWeek.first)} – ${formatShortDate(inWeek.last)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                PixelText('$answered/${_review.prompts.length}', dot: 3),
              ],
            ),
            const SizedBox(height: 6),
            const Text('建議週日寫，一週寫一次就好；不給隊友看。', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
            if (noticedThisWeek.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionTitle(tag: 'NOTES', title: '這週注意到的事'),
              const SizedBox(height: 8),
              PixelBox(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (day, note) in noticedThisWeek)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${formatShortDate(day)}　$note',
                          style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SectionTitle(tag: 'REVIEW', title: '${_review.emoji} ${_review.title}'),
            for (var i = 0; i < _review.prompts.length; i++) ...[
              const SizedBox(height: 12),
              Text('${i + 1}. ${_review.prompts[i]}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(controller: _answers[i], minLines: 2, maxLines: 5, enabled: editable),
            ],
          ];

          final photoSection = [
            const SectionTitle(tag: 'PHOTO', title: '📷 每週一張照片'),
            const SizedBox(height: 6),
            const Text('留一張代表這週生活的照片，不用證明什麼。', style: TextStyle(fontSize: 12, color: PixelColors.muted)),
            const SizedBox(height: 12),
            _PhotoFrame(photo: photo, week: challenge.weekNumber(_date)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: Keycap(
                      onTap: editable && !_busy ? () => _pickPhoto(ImageSource.gallery) : null,
                      child: const Center(
                        child: Text('🖼️ 從相簿選', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: Keycap(
                      onTap: editable && !_busy ? () => _pickPhoto(ImageSource.camera) : null,
                      child: const Center(
                        child: Text('📸 拍一張', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (photo != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: editable ? () => _store.setPhoto(_date, null) : null,
                  child: const Text('拿掉這張'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            PixelBox(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PhotoWallScreen(store: _store)),
              ),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                  PixelTag('WALL'),
                  SizedBox(width: 10),
                  Expanded(child: Text('看照片牆', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 64,
              child: Keycap(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _save();
                  navigator.pop();
                },
                faceColor: PixelColors.yellow,
                child: const Center(
                  child: Text('存好了 ✓', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ];

          const padding = EdgeInsets.fromLTRB(16, 16, 16, 32);
          return Scaffold(
            appBar: AppBar(title: const Text('本週任務', style: TextStyle(fontWeight: FontWeight.w900))),
            body: Center(
              child: isWideLayout(context)
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: ListView(padding: padding, children: review)),
                          Expanded(child: ListView(padding: padding, children: photoSection)),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: padding,
                        children: [...review, const SizedBox(height: 26), ...photoSection],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// 照片框：有照片就顯示，沒有就是一個空的像素相框。
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.photo, required this.week});

  final String? photo;
  final int week;

  @override
  Widget build(BuildContext context) {
    final image = PhotoStore.image(photo);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: ShapeDecoration(
          color: image == null ? PixelColors.sand : PixelColors.ink,
          shape: const PixelBorder(),
          image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelText('WEEK $week', dot: 3, color: PixelColors.muted),
                    const SizedBox(height: 8),
                    const Text('這週還沒有照片', style: TextStyle(fontWeight: FontWeight.w800, color: PixelColors.muted)),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
