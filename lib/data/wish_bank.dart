import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';

/// 願望商城裡的一個願望。
class Wish {
  const Wish({required this.id, required this.emoji, required this.title, required this.price});

  factory Wish.fromJson(Map<String, dynamic> json) => Wish(
        id: json['id'] as String,
        emoji: json['emoji'] as String? ?? '🎁',
        title: json['title'] as String? ?? '',
        price: json['price'] as int? ?? 1,
      );

  final String id;
  final String emoji;
  final String title;

  /// 要幾顆星星。
  final int price;

  Map<String, Object?> toJson() => {'id': id, 'emoji': emoji, 'title': title, 'price': price};
}

/// 一筆兌換紀錄。連願望當時的樣子一起存，之後刪掉或改價也不影響。
class Redemption {
  const Redemption({
    required this.wishId,
    required this.date,
    required this.stars,
    required this.emoji,
    required this.title,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) => Redemption(
        wishId: json['wish'] as String,
        date: parseDateKey(json['date'] as String),
        stars: json['stars'] as int,
        emoji: json['emoji'] as String? ?? '🎁',
        title: json['title'] as String? ?? '',
      );

  final String wishId;
  final DateTime date;

  /// 花了幾顆星星。
  final int stars;
  final String emoji;
  final String title;

  Map<String, Object?> toJson() => {
        'wish': wishId,
        'date': dateKey(date),
        'stars': stars,
        'emoji': emoji,
        'title': title,
      };
}

/// 願望撲滿：願望清單和兌換紀錄存在手機本機（key 都是 `wishes.` 開頭）。
/// 賺到的星星是從打卡紀錄算出來的（見 models/stars.dart），這裡只記花掉的。
class WishBank extends ChangeNotifier {
  WishBank._(this._prefs);

  static Future<WishBank> load() async {
    final bank = WishBank._(await SharedPreferences.getInstance());
    if (bank._restore()) await bank._saveWishes();
    return bank;
  }

  static const _wishesKey = 'wishes.list';
  static const _redeemedKey = 'wishes.redeemed';
  static const _bonusKey = 'wishes.demoBonus';

  static const maxPrice = 999;

  /// Demo：第一次打開時先放的範例願望。
  static const sampleWishes = [
    Wish(id: 'bag', emoji: '👜', title: '想買的包包', price: 30),
    Wish(id: 'feast', emoji: '🍣', title: '犒賞自己一頓大餐', price: 20),
    Wish(id: 'massage', emoji: '💆', title: '去按摩放鬆', price: 15),
  ];

  final SharedPreferences _prefs;

  List<Wish> _wishes = [];
  List<Redemption> _redemptions = [];
  int _demoBonus = 0;

  List<Wish> get wishes => List.unmodifiable(_wishes);

  /// 兌換紀錄，依兌換順序由舊到新。
  List<Redemption> get redemptions => List.unmodifiable(_redemptions);

  /// 已經花掉幾顆星星。
  int get spent => _redemptions.fold(0, (sum, r) => sum + r.stars);

  /// Demo 用：直接塞進撲滿的星星（不是打卡賺的）。
  int get demoBonus => _demoBonus;

  /// 撲滿裡還有幾顆：賺到的（[earned]）＋ Demo 加碼 − 花掉的。
  int balance(int earned) => earned + _demoBonus - spent;

  bool canRedeem(Wish wish, int earned) => balance(earned) >= wish.price;

  int timesRedeemed(String wishId) => _redemptions.where((r) => r.wishId == wishId).length;

  Future<Wish> addWish({required String emoji, required String title, required int price}) async {
    final wish = Wish(
      id: 'w${_nextNumber()}',
      emoji: emoji,
      title: title.trim(),
      price: price.clamp(1, maxPrice),
    );
    _wishes.add(wish);
    notifyListeners();
    await _saveWishes();
    return wish;
  }

  Future<void> removeWish(String id) async {
    _wishes.removeWhere((wish) => wish.id == id);
    notifyListeners();
    await _saveWishes();
  }

  /// 用星星兌換。星星不夠就回傳 false，什麼都不做。
  Future<bool> redeem(Wish wish, {required int earned, required DateTime date}) async {
    if (!canRedeem(wish, earned)) return false;
    _redemptions.add(Redemption(
      wishId: wish.id,
      date: dateOnly(date),
      stars: wish.price,
      emoji: wish.emoji,
      title: wish.title,
    ));
    notifyListeners();
    await _prefs.setString(_redeemedKey, jsonEncode([for (final r in _redemptions) r.toJson()]));
    return true;
  }

  Future<void> addDemoBonus(int stars) async {
    _demoBonus += stars;
    notifyListeners();
    await _prefs.setInt(_bonusKey, _demoBonus);
  }

  /// Demo 用：清掉兌換紀錄和加碼，願望回到範例的三個。
  Future<void> resetDemo() async {
    _resetFields();
    notifyListeners();
    await _saveWishes();
    await _prefs.remove(_redeemedKey);
    await _prefs.remove(_bonusKey);
  }

  /// 重新讀一次本機資料（例如別的畫面改過）。
  void reload() {
    _restore();
    notifyListeners();
  }

  int _nextNumber() {
    var max = 0;
    for (final wish in _wishes) {
      final n = wish.id.startsWith('w') ? int.tryParse(wish.id.substring(1)) : null;
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  Future<void> _saveWishes() =>
      _prefs.setString(_wishesKey, jsonEncode([for (final wish in _wishes) wish.toJson()]));

  /// 讀本機資料。回傳 true 代表放了範例願望、還沒存（第一次打開或資料壞掉）。
  bool _restore() {
    final wishes = _prefs.getString(_wishesKey);
    try {
      _wishes = wishes == null
          ? [...sampleWishes]
          : [for (final json in jsonDecode(wishes) as List<dynamic>) Wish.fromJson(json as Map<String, dynamic>)];
      final redeemed = _prefs.getString(_redeemedKey);
      _redemptions = redeemed == null
          ? []
          : [
              for (final json in jsonDecode(redeemed) as List<dynamic>)
                Redemption.fromJson(json as Map<String, dynamic>),
            ];
      _demoBonus = _prefs.getInt(_bonusKey) ?? 0;
      return wishes == null;
    } on FormatException {
      // 本機資料壞掉時就從頭開始，不要讓畫面打不開。
      _resetFields();
      return true;
    } on TypeError {
      _resetFields();
      return true;
    }
  }

  void _resetFields() {
    _wishes = [...sampleWishes];
    _redemptions = [];
    _demoBonus = 0;
  }
}
