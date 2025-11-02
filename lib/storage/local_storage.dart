import 'dart:ui';

import 'package:bus_scraper/storage/storage.dart';

import '../widgets/favorite_provider.dart';
import 'app_theme.dart';
import 'city.dart';

class LocalStorage {
  AppTheme get appTheme => AppTheme.values.byName(
      StorageHelper.get<String>('app_theme', AppTheme.followSystem.name));

  set appTheme(AppTheme value) =>
      StorageHelper.set<String>('app_theme', value.name);

  City get city {
    return City.values.byName(
        StorageHelper.get<String>('selected_city', City.defaultCity.code));
  }

  set city(City value) {
    StorageHelper.set<String>('selected_city', value.code);
  }

  Color get accentColor =>
      Color(StorageHelper.get<int>('accent_color', 0xFFD0BCFF));

  set accentColor(Color? value) =>
      StorageHelper.set<int?>('accent_color', value?.toARGB32());

  static const String _liveTrackDurationKey = 'live_track_duration';

  int get liveTrackDuration =>
      StorageHelper.get<int>(_liveTrackDurationKey, 10);

  set liveTrackDuration(int value) =>
      StorageHelper.set<int>(_liveTrackDurationKey, value);

  static const String _favoriteGroupsKey = 'favorite_groups_by_city';
  static const String _veryOldFavoritePlatesKey = 'favorite_plates';

  Map<String, List<String>> getFavoriteGroupsForCity(City city) {
    final allCityGroups =
        StorageHelper.get<Map<String, dynamic>>(_favoriteGroupsKey, {});
    bool needsSave = false;

    final veryOldFavorites =
        StorageHelper.get<List<dynamic>?>(_veryOldFavoritePlatesKey);
    if (veryOldFavorites != null && veryOldFavorites.isNotEmpty) {
      final typedPlateList = veryOldFavorites.cast<String>();

      for (final targetCity in City.values) {
        final cityCode = targetCity.code;
        final cityGroups = allCityGroups[cityCode] != null
            ? Map<String, dynamic>.from(allCityGroups[cityCode])
            : <String, dynamic>{};

        final defaultGroupPlates = Set<String>.from(
            cityGroups[FavoritesNotifier.defaultGroupName] ?? []);
        defaultGroupPlates.addAll(typedPlateList);
        cityGroups[FavoritesNotifier.defaultGroupName] =
            defaultGroupPlates.toList();

        allCityGroups[cityCode] = cityGroups;
      }

      needsSave = true;
      StorageHelper.set<List<dynamic>?>(_veryOldFavoritePlatesKey, null);
    }

    if (needsSave) {
      StorageHelper.set<Map<String, dynamic>>(
          _favoriteGroupsKey, allCityGroups);
    }

    final currentCityGroups = allCityGroups[city.code];
    if (currentCityGroups == null) {
      return {FavoritesNotifier.defaultGroupName: []};
    }

    final typedCityGroups = Map<String, List<String>>.from(
      (currentCityGroups as Map).map(
        (key, value) =>
            MapEntry(key as String, List<String>.from(value as List)),
      ),
    );

    if (!typedCityGroups.containsKey(FavoritesNotifier.defaultGroupName)) {
      typedCityGroups[FavoritesNotifier.defaultGroupName] = [];
    }

    return typedCityGroups;
  }

  void setFavoriteGroupsForCity(City city, Map<String, List<String>> groups) {
    final allCityGroups =
        StorageHelper.get<Map<String, dynamic>>(_favoriteGroupsKey, {});
    final mutableAllGroups = Map<String, dynamic>.from(allCityGroups);
    mutableAllGroups[city.code] = groups;
    StorageHelper.set<Map<String, dynamic>>(
        _favoriteGroupsKey, mutableAllGroups);
  }

  List<String> get favoritePlates {
    final groups = getFavoriteGroupsForCity(city);
    return groups[FavoritesNotifier.defaultGroupName] ?? [];
  }

  set favoritePlates(List<String> plates) {
    final groups = getFavoriteGroupsForCity(city);
    groups[FavoritesNotifier.defaultGroupName] = plates;
    setFavoriteGroupsForCity(city, groups);
  }

  String? get lastShownVersion =>
      StorageHelper.get<String?>('last_shown_version');

  set lastShownVersion(String? value) =>
      StorageHelper.set<String?>('last_shown_version', value);

  Map<String, String> getRemarksForCity(City city) {
    final data =
        StorageHelper.get<Map<String, dynamic>>('driver_remarks_by_city', {});
    if (data.containsKey(city.code)) {
      return Map<String, String>.from(data[city.code]);
    }
    return {};
  }

  void setRemarksForCity(City city, Map<String, String> cityRemarks) {
    final data =
        StorageHelper.get<Map<String, dynamic>>('driver_remarks_by_city', {});
    Map<String, Map<String, String>> allRemarks = {city.code: cityRemarks};
    data.forEach((cityCode, remarksObject) {
      if (cityCode != city.code) {
        allRemarks[cityCode] = Map<String, String>.from(remarksObject);
      }
    });
    StorageHelper.set<Map<String, Map<String, String>>>(
        'driver_remarks_by_city', allRemarks);
  }
}
