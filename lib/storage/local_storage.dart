import 'dart:ui';

import 'package:bus_scraper/storage/storage.dart';

import 'app_theme.dart';
import 'city.dart';

class LocalStorage {
  static const String _favoriteTreeKey = "favorite_tree";
  static const String _favoriteGroupsKey = 'favorite_groups_by_city';
  static const String _veryOldFavoritePlatesKey = 'favorite_plates';
  static const String defaultGroupName = '最愛';

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

  Map<String, dynamic> getFavoriteMap(City city) {
    final allTrees =
        StorageHelper.get<Map<String, dynamic>>(_favoriteTreeKey, {});

    if (allTrees.containsKey(city.code)) {
      return _makeMutable(allTrees[city.code]);
    }

    final allOldGroups =
        StorageHelper.get<Map<String, dynamic>>(_favoriteGroupsKey, {});
    Map<String, dynamic> migratedData = {};

    if (allOldGroups.containsKey(city.code)) {
      migratedData = _makeMutable(allOldGroups[city.code]);
    }

    final veryOldPlates =
        StorageHelper.get<List<dynamic>?>(_veryOldFavoritePlatesKey);
    if (veryOldPlates != null && veryOldPlates.isNotEmpty) {
      final List<String> plateList = List<String>.from(veryOldPlates);
      final List<String> currentFavorite =
          List<String>.from(migratedData[defaultGroupName] ?? []);

      migratedData[defaultGroupName] =
          (Set<String>.from(currentFavorite)..addAll(plateList)).toList();

      StorageHelper.set<List<dynamic>?>(_veryOldFavoritePlatesKey, null);
    }

    if (migratedData.isNotEmpty) {
      setFavoriteMap(city, migratedData);
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

  dynamic _makeMutable(dynamic input) {
    if (input is Map) {
      return input.map((k, v) => MapEntry(k.toString(), _makeMutable(v)));
    } else if (input is List) {
      return input.map((e) => _makeMutable(e)).toList();
    }
    return input;
  }

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
