import 'dart:ui';

import 'app_theme.dart'; // 假設您的 AppTheme enum 在此
import 'storage.dart';    // 假設您的 StorageHelper 在此

class LocalStorage {
  AppTheme get appTheme => AppTheme.values.byName(
      StorageHelper.get<String>('app_theme', AppTheme.followSystem.name));

  set appTheme(AppTheme value) => StorageHelper.set('app_theme', value.name);

  Color get accentColor =>
      Color(StorageHelper.get<int>('accent_color', 0xFFD0BCFF));

  set accentColor(Color? value) =>
      StorageHelper.set<int?>('accent_color', value?.toARGB32());

  List<String> get favoritePlates {
    return StorageHelper.get('favorite_plates', []).cast<String>();
  }

  set favoritePlates(List<String> plates) {
    StorageHelper.set<List<String>>('favorite_plates', plates);
  }
  
  String? get lastShownVersion =>
      StorageHelper.get<String?>('last_shown_version');

  set lastShownVersion(String? value) =>
      StorageHelper.set<String?>('last_shown_version', value);

  Map<String, String> get driverRemarks {
    // 從存儲中讀取 Map，如果不存在則返回一個空 Map
    final data = StorageHelper.get<Map>('driver_remarks', {});
    // 將 Map<dynamic, dynamic> 安全地轉換為 Map<String, String>
    return Map<String, String>.from(data);
  }

  set driverRemarks(Map<String, String> remarks) {
    StorageHelper.set<Map<String, String>>('driver_remarks', remarks);
  }
}