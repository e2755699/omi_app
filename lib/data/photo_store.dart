import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 每週照片的存放：手機存成 App 自己的檔案，網頁版存成 data URL。
/// 回傳的字串就放在照片項目的 notes[0]。
abstract final class PhotoStore {
  static final _picker = ImagePicker();

  /// 讓使用者從相簿選或拍一張，存起來後回傳參照；取消就回傳 null。
  static Future<String?> pick({required ImageSource source, required String key}) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (kIsWeb) return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    await dir.create(recursive: true);
    // 檔名加時間，換照片時舊的快取才不會黏著。
    final file = File('${dir.path}/$key-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 刪掉之前存的檔案（網頁版的 data URL 沒有檔案可刪）。
  static Future<void> delete(String? ref) async {
    if (ref == null || kIsWeb || ref.startsWith('data:')) return;
    try {
      final file = File(ref);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // 刪不掉就算了，不影響紀錄。
    }
  }

  static ImageProvider? image(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    if (ref.startsWith('data:')) {
      final comma = ref.indexOf(',');
      if (comma < 0) return null;
      return MemoryImage(base64Decode(ref.substring(comma + 1)));
    }
    if (kIsWeb) return null;
    return FileImage(File(ref));
  }
}
