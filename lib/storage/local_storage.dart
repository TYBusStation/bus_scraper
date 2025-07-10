// local_storage.dart

import 'dart:ui';

import 'app_theme.dart'; // 假設您的 AppTheme enum 在此
import 'storage.dart'; // 假設您的 StorageHelper 在此

class LocalStorage {
  // --- 主題設定 ---
  AppTheme get appTheme => AppTheme.values.byName(
      StorageHelper.get<String>('app_theme', AppTheme.followSystem.name));

  set appTheme(AppTheme value) => StorageHelper.set('app_theme', value.name);

  // --- 主題顏色設定 ---
  Color get accentColor =>
      Color(StorageHelper.get<int>('accent_color', 0xFFD0BCFF));

  set accentColor(Color? value) =>
      StorageHelper.set<int?>('accent_color', value?.toARGB32());

  // --- 我的最愛車牌 ---
  List<String> get favoritePlates {
    // 這裡也加上安全的預設值
    final dynamic storedValue = StorageHelper.get('favorite_plates', []);
    if (storedValue is List) {
      return storedValue.cast<String>();
    }
    return [];
  }

  set favoritePlates(List<String> plates) {
    StorageHelper.set<List<String>>('favorite_plates', plates);
  }

  // --- 上次顯示的 App 版本 ---
  String? get lastShownVersion =>
      StorageHelper.get<String?>('last_shown_version');

  set lastShownVersion(String? value) =>
      StorageHelper.set<String?>('last_shown_version', value);

  // --- 當前選擇的城市 ---
  static const String defaultCity = 'taoyuan';

  String get city {
    return StorageHelper.get<String>('selected_city', defaultCity);
  }

  set city(String value) {
    StorageHelper.set<String>('selected_city', value);
  }

  // --- 【核心修改處】駕駛員備註，加入遷移邏輯和 null 安全防護 ---

  /// 獲取所有城市的駕駛員備註。
  /// 【新增遷移邏輯】如果發現舊格式的資料，會自動執行一次性遷移。
  Map<String, Map<String, String>> get _allDriverRemarks {
    // 1. 【關鍵修正】檢查是否存在舊的儲存鍵 'driver_remarks'
    //    在呼叫 get 時，提供一個空的 Map `{}` 作為預設值。
    //    這樣即使儲存中沒有這個鍵，oldRemarks 也會是一個空 Map，而不是 null。
    final oldRemarks = StorageHelper.get<Map>('driver_remarks', {});

    // 現在 oldRemarks 永遠不為 null，可以直接安全地使用 .isNotEmpty
    if (oldRemarks.isNotEmpty) {
      // 2. 如果存在舊資料，執行一次性遷移
      print("LocalStorage: Detected old driver remarks format. Migrating...");

      final oldRemarksTyped = Map<String, String>.from(oldRemarks);

      final newRemarksByCity = _loadRemarksByCity();

      newRemarksByCity
          .putIfAbsent(defaultCity, () => {})
          .addAll(oldRemarksTyped);

      // 3. 將合併後的資料用新的鍵保存回去
      _allDriverRemarks = newRemarksByCity;

      // 4. 【重要】刪除舊的儲存鍵，確保遷移只會執行一次
      StorageHelper.set<Map?>('driver_remarks', null);

      print(
          "LocalStorage: Migration complete. Old data moved to '$defaultCity' city.");

      return newRemarksByCity;
    }

    // 如果沒有舊資料，就正常讀取新格式的資料
    return _loadRemarksByCity();
  }

  /// (內部輔助函式) 從儲存中安全地載入新格式的備註資料
  Map<String, Map<String, String>> _loadRemarksByCity() {
    // 【關鍵修正】同樣地，為新格式的資料也提供一個安全的預設值。
    final data = StorageHelper.get<Map>('driver_remarks_by_city', {});

    final remarksByCity = <String, Map<String, String>>{};
    data.forEach((cityKey, remarksObject) {
      if (cityKey is String && remarksObject is Map) {
        remarksByCity[cityKey] = Map<String, String>.from(remarksObject);
      }
    });
    return remarksByCity;
  }

  /// 儲存所有城市的駕駛員備註。
  set _allDriverRemarks(Map<String, Map<String, String>> remarks) {
    StorageHelper.set<Map<String, Map<String, String>>>(
        'driver_remarks_by_city', remarks);
  }

  /// 輔助方法：獲取特定城市的備註 Map
  Map<String, String> getRemarksForCity(String cityCode) {
    return _allDriverRemarks[cityCode] ?? {};
  }

  /// 輔助方法：為特定城市的特定駕駛員設定備註
  void setRemarkForDriver(String cityCode, String driverId, String remark) {
    final allRemarks = _allDriverRemarks;
    allRemarks.putIfAbsent(cityCode, () => {});
    allRemarks[cityCode]![driverId] = remark;
    _allDriverRemarks = allRemarks;
  }

  /// 輔助方法：移除特定城市的特定駕駛員備註
  void removeRemarkForDriver(String cityCode, String driverId) {
    final allRemarks = _allDriverRemarks;
    allRemarks[cityCode]?.remove(driverId);
    _allDriverRemarks = allRemarks;
  }

  /// 輔助方法：一次性設定某個城市的全部備註 (用於設定頁面)
  void setRemarksForCity(String cityCode, Map<String, String> cityRemarks) {
    final allRemarks = _allDriverRemarks;
    allRemarks[cityCode] = cityRemarks;
    _allDriverRemarks = allRemarks;
  }
}
