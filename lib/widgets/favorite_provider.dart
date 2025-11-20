import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../utils/static.dart';

class FavoritesNotifier extends ChangeNotifier implements ReassembleHandler {
  static const String defaultGroupName = '最愛';

  Map<String, List<String>> _favoriteGroups = {};
  List<String> _groupOrder = [];

  FavoritesNotifier() {
    _loadFavorites();
  }

  void _loadFavorites() {
    _favoriteGroups =
        Static.localStorage.getFavoriteGroupsForCity(Static.localStorage.city);
    _groupOrder = Static.localStorage
        .getFavoriteGroupOrderForCity(Static.localStorage.city);
    if (!_favoriteGroups.containsKey(defaultGroupName)) {
      _favoriteGroups[defaultGroupName] = [];
    }
  }

  Map<String, List<String>> get favoriteGroups => _favoriteGroups;

  List<String> getGroupOrder() {
    final currentGroupKeys = _favoriteGroups.keys.toSet();
    final orderedGroupKeys =
        _groupOrder.where((key) => currentGroupKeys.contains(key)).toList();
    final newKeys =
        currentGroupKeys.where((key) => !_groupOrder.contains(key)).toList();

    if (orderedGroupKeys.contains(defaultGroupName)) {
      orderedGroupKeys.remove(defaultGroupName);
    }
    if (newKeys.contains(defaultGroupName)) {
      newKeys.remove(defaultGroupName);
    }

    return [defaultGroupName, ...orderedGroupKeys, ...newKeys];
  }

  bool isFavorite(String plate) {
    return _favoriteGroups.values.any((plates) => plates.contains(plate));
  }

  Set<String> getGroupsForPlate(String plate) {
    return _favoriteGroups.entries
        .where((entry) => entry.value.contains(plate))
        .map((entry) => entry.key)
        .toSet();
  }

  void updatePlateGroups(String plate, Set<String> selectedGroups) {
    _favoriteGroups.forEach((groupName, plates) {
      plates.remove(plate);
    });

    for (var groupName in selectedGroups) {
      if (_favoriteGroups.containsKey(groupName)) {
        _favoriteGroups[groupName]!.add(plate);
      }
    }
    _saveAndNotify();
  }

  void toggleFavorite(String plate) {
    final favoriteGroup = _favoriteGroups[defaultGroupName] ?? [];
    if (favoriteGroup.contains(plate)) {
      favoriteGroup.remove(plate);
    } else {
      favoriteGroup.add(plate);
    }
    _favoriteGroups[defaultGroupName] = favoriteGroup;
    _saveAndNotify();
  }

  void addGroup(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || _favoriteGroups.containsKey(trimmedName)) return;
    _favoriteGroups[trimmedName] = [];
    _groupOrder.add(trimmedName);
    _saveAndNotify();
  }

  void removeGroup(String name) {
    if (name == defaultGroupName) return;
    _favoriteGroups.remove(name);
    _groupOrder.remove(name);
    _saveAndNotify();
  }

  void renameGroup(String oldName, String newName) {
    final trimmedNewName = newName.trim();
    if (oldName == defaultGroupName ||
        trimmedNewName.isEmpty ||
        _favoriteGroups.containsKey(trimmedNewName)) return;

    final plates = _favoriteGroups[oldName] ?? [];
    _favoriteGroups.remove(oldName);
    _favoriteGroups[trimmedNewName] = plates;

    final index = _groupOrder.indexOf(oldName);
    if (index != -1) {
      _groupOrder[index] = trimmedNewName;
    }
    _saveAndNotify();
  }

  void reorderGroup(int oldIndex, int newIndex) {
    var currentOrder = getGroupOrder();

    if (oldIndex == 0 || newIndex == 0) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final String item = currentOrder.removeAt(oldIndex);
    currentOrder.insert(newIndex, item);

    _groupOrder = currentOrder;
    _saveAndNotify();
  }

  void addPlateToGroup(String plate, String groupName) {
    if (!_favoriteGroups.containsKey(groupName)) return;
    final group = _favoriteGroups[groupName]!;
    if (!group.contains(plate)) {
      group.add(plate);
      _saveAndNotify();
    }
  }

  void removePlateFromGroup(String plate, String groupName) {
    if (!_favoriteGroups.containsKey(groupName)) return;
    _favoriteGroups[groupName]?.remove(plate);
    _saveAndNotify();
  }

  void _saveAndNotify() {
    Static.localStorage
        .setFavoriteGroupsForCity(Static.localStorage.city, _favoriteGroups);
    Static.localStorage.setFavoriteGroupOrderForCity(
        Static.localStorage.city, getGroupOrder());
    notifyListeners();
  }

  @override
  void reassemble() {
    _loadFavorites();
    notifyListeners();
  }
}
