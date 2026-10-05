/// 個人設定：在教學（Setup）裡填，用來產生自己的儀表板。
class Profile {
  const Profile({
    this.name = defaultName,
    this.avatar = '😀',
    this.weightKg,
    this.nourishChoice = const {},
    this.bedtime,
    this.wakeTime,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] as String? ?? defaultName,
        avatar: json['avatar'] as String? ?? '😀',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        nourishChoice: {...?(json['nourish'] as List<dynamic>?)?.cast<String>()},
        bedtime: json['bedtime'] as int?,
        wakeTime: json['wakeTime'] as int?,
      );

  static const defaultName = '我';

  final String name;
  final String avatar;

  /// 用來算蛋白質（1.2 g/kg）和飲水（30 ml/kg）的目標。
  final double? weightKg;

  /// Nourish 3 選 2 選了哪兩項（項目 id）。挑戰開始後不能再改。
  final Set<String> nourishChoice;

  /// 固定的就寢、起床時間（從午夜起算的分鐘數）。
  final int? bedtime;
  final int? wakeTime;

  bool get nourishReady => nourishChoice.length == 2;
  bool get scheduleReady => bedtime != null && wakeTime != null;

  /// 睡眠機會：就寢到起床有幾分鐘。
  int? get sleepWindow => scheduleReady ? (wakeTime! - bedtime! + 24 * 60) % (24 * 60) : null;

  Map<String, Object?> toJson() => {
        'name': name,
        'avatar': avatar,
        'weightKg': weightKg,
        'nourish': nourishChoice.toList(),
        'bedtime': bedtime,
        'wakeTime': wakeTime,
      };
}

/// 例：23:30
String formatClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// 例：8、7.5
String formatHours(int minutes) => (minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1);
