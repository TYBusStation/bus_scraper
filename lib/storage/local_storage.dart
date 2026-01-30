import 'dart:ui';

import 'package:bus_scraper/storage/storage.dart';

import 'app_theme.dart';
import 'city.dart';

class LocalStorage {
  // 儲存鍵值
  static const String _favoriteTreeKey = "favorite_tree";
  static const String _favoriteGroupsKey = 'favorite_groups_by_city';
  static const String _veryOldFavoritePlatesKey = 'favorite_plates';
  static const String defaultGroupName = '最愛';

  // --- 系統設定 ---

  AppTheme get appTheme => AppTheme.values.byName(
      StorageHelper.get<String>('app_theme', AppTheme.followSystem.name));

  set appTheme(AppTheme value) =>
      StorageHelper.set<String>('app_theme', value.name);

  City get city => City.values.byName(
      StorageHelper.get<String>('selected_city', City.defaultCity.code));

  set city(City value) =>
      StorageHelper.set<String>('selected_city', value.code);

  Color get accentColor =>
      Color(StorageHelper.get<int>('accent_color', 0xFFD0BCFF));

  set accentColor(Color? value) =>
      StorageHelper.set<int?>('accent_color', value?.toARGB32());

  int get liveTrackDuration =>
      StorageHelper.get<int>('live_track_duration', 10);

  set liveTrackDuration(int value) =>
      StorageHelper.set<int>('live_track_duration', value);

  // --- 巢狀收藏地圖 (Nested Map) ---

  /// 獲取巢狀地圖，若無則從舊版扁平格式遷移
  Map<String, dynamic> getFavoriteMap(City city) {
    final allTrees =
        StorageHelper.get<Map<String, dynamic>>(_favoriteTreeKey, {});

    // 1. 檢查是否有新版巢狀資料
    if (allTrees.containsKey(city.code)) {
      return _makeMutable(allTrees[city.code]);
    }

    // 2. 遷移邏輯：從舊版格式遷移
    final allOldGroups =
        StorageHelper.get<Map<String, dynamic>>(_favoriteGroupsKey, {});
    Map<String, dynamic> migratedData = {};

    if (allOldGroups.containsKey(city.code)) {
      // 遷移舊版群組 (Map<String, List>)
      migratedData = _makeMutable(allOldGroups[city.code]);
    }

    // 3. 處理極舊版車牌清單 (List) 並合併進「最愛」群組
    final veryOldPlates =
        StorageHelper.get<List<dynamic>?>(_veryOldFavoritePlatesKey);
    if (veryOldPlates != null && veryOldPlates.isNotEmpty) {
      final List<String> plateList = List<String>.from(veryOldPlates);
      final List<String> currentFavorite =
          List<String>.from(migratedData[defaultGroupName] ?? []);

      migratedData[defaultGroupName] =
          (Set<String>.from(currentFavorite)..addAll(plateList)).toList();

      // 清除極舊版資料標記
      StorageHelper.set<List<dynamic>?>(_veryOldFavoritePlatesKey, null);
    }

    if (migratedData.isNotEmpty) {
      setFavoriteMap(city, migratedData); // 存入新格式
      return migratedData;
    }

    return {};
  }

  void setFavoriteMap(City city, Map<String, dynamic> data) {
    final allTrees =
        StorageHelper.get<Map<String, dynamic>>(_favoriteTreeKey, {});
    final mutableAll = Map<String, dynamic>.from(allTrees);
    mutableAll[city.code] = data;
    StorageHelper.set<Map<String, dynamic>>(_favoriteTreeKey, mutableAll);
  }

  /// 遞歸確保所有層級皆為可變的 Growable List/Map
  dynamic _makeMutable(dynamic input) {
    if (input is Map) {
      return input.map((k, v) => MapEntry(k.toString(), _makeMutable(v)));
    } else if (input is List) {
      return input.map((e) => _makeMutable(e)).toList();
    }
    return input;
  }

  // --- 駕駛長備註 ---

  Map<String, String> getRemarksForCity(City city) {
    final data =
        StorageHelper.get<Map<String, dynamic>>('driver_remarks_by_city', {});
    return data.containsKey(city.code)
        ? Map<String, String>.from(data[city.code])
        : {};
  }

  void setRemarksForCity(City city, Map<String, String> cityRemarks) {
    final data =
        StorageHelper.get<Map<String, dynamic>>('driver_remarks_by_city', {});
    final allRemarks = Map<String, dynamic>.from(data);
    allRemarks[city.code] = cityRemarks;
    StorageHelper.set<Map<String, dynamic>>(
        'driver_remarks_by_city', allRemarks);
  }

  String? get lastShownVersion =>
      StorageHelper.get<String?>('last_shown_version');

  set lastShownVersion(String? value) =>
      StorageHelper.set<String?>('last_shown_version', value);
}
