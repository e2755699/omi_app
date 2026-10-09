import 'dart:math';

import '../models/activity_log.dart';
import '../models/challenge.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/rules.dart';

class _Demo {
  const _Demo(this.id, this.profile, this.rate);

  final String id;
  final Profile profile;

  /// 有多認真：每個項目每天做到的機率。
  final double rate;
}

const _demos = [
  _Demo(
    'an',
    Profile(name: '小安', avatar: '🦊', nourishChoice: {'produce', 'water'}, bedtime: 23 * 60, wakeTime: 7 * 60),
    0.9,
  ),
  _Demo(
    'mia',
    Profile(name: 'Mia', avatar: '🐱', nourishChoice: {'protein', 'water'}, bedtime: 22 * 60 + 30, wakeTime: 6 * 60 + 30),
    0.7,
  ),
  _Demo(
    'zhe',
    Profile(name: '阿哲', avatar: '🐻', nourishChoice: {'produce', 'protein'}, bedtime: 24 * 60 - 30, wakeTime: 7 * 60 + 30),
    0.5,
  ),
  _Demo(
    'ken',
    Profile(name: 'Ken', avatar: '🦁', nourishChoice: {'protein', 'water'}, bedtime: 23 * 60, wakeTime: 7 * 60),
    0.65,
  ),
  _Demo(
    'yu',
    Profile(name: '小雨', avatar: '🐸', nourishChoice: {'produce', 'water'}, bedtime: 23 * 60 + 30, wakeTime: 7 * 60 + 30),
    0.2,
  ),
];

const _noticed = [
  '午餐後散步 10 分鐘，下午精神比較好',
  '睡前不滑手機，比較快睡著',
  '多喝水之後，比較不會想吃零食',
  '早上先運動，一整天心情都不錯',
  '今天壓力大，但還是讀完 20 分鐘',
  '跟家人一起煮飯，蔬菜吃得比平常多',
];

const _weeklyNotes = {
  'review': ['（示範）運動都有照計畫做完', '（示範）週三加班，閱讀斷了一天', '（示範）下週提早排好有氧時間'],
};

/// 示範：第 [day] 天其他隊友給 [playerId] 的加油數。
int demoCheers(String playerId, int day) {
  final random = Random(playerId.codeUnits.fold<int>(day * 131, (seed, unit) => seed * 31 + unit));
  // 讓自己至少收到一個，Demo 的時候才看得到效果。
  return playerId == 'me' ? 1 + random.nextInt(4) : random.nextInt(4);
}

/// 產生示範隊友。用固定的亂數種子，同一天每次打開看到的內容都一樣。
List<Player> buildDemoPlayers(Challenge challenge, DateTime today) => [
      for (final (index, demo) in _demos.indexed)
        Player(id: demo.id, profile: demo.profile, log: _logFor(index, demo, challenge, today)),
    ];

ActivityLog _logFor(int index, _Demo demo, Challenge challenge, DateTime today) {
  final log = ActivityLog();
  final items = activeItems(demo.profile);
  final lastDay = challenge.elapsedDays(today);
  for (var day = 1; day <= lastDay; day++) {
    final date = challenge.dateOfDay(day);
    final random = Random(index * 10007 + day);
    for (final item in items) {
      switch (item.kind) {
        case ItemKind.daily:
          if (random.nextDouble() >= demo.rate) continue;
          log.set(
            item,
            date,
            item.needsWriting
                ? Entry(amount: 1, notes: [_noticed[random.nextInt(_noticed.length)]])
                : const Entry(amount: 1),
          );
        case ItemKind.weeklyAmount:
          final chance = item.id == 'aerobic' ? demo.rate * 0.6 : demo.rate * 0.35;
          if (random.nextDouble() >= chance) continue;
          log.set(item, date, Entry(amount: item.id == 'aerobic' ? 20 + random.nextInt(5) * 10 : 1));
        case ItemKind.weekly:
          // 每週的項目在週日（或挑戰最後一天）做。
          final weekEnd = date.weekday == DateTime.sunday || day == challenge.totalDays;
          if (!weekEnd || random.nextDouble() >= demo.rate) continue;
          if (item.id == 'photo') continue;
          final notes = _weeklyNotes[item.id] ?? const [];
          log.set(item, date, Entry(amount: max(1, notes.length), notes: notes));
      }
    }
  }
  return log;
}
