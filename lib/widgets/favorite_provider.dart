import 'package:flutter/foundation.dart';

import '../utils/static.dart';

class FavoritesNotifier extends ChangeNotifier {
  Map<String, dynamic> _data = {};

  FavoritesNotifier() {
    _load();
  }

  void _load() {
    _data = Static.localStorage.getFavoriteMap(Static.city);
    notifyListeners();
  }

  Map<String, dynamic> get data => _data;

  bool isFavorite(String plate) {
    return _containsPlate(_data, plate);
  }

  bool _containsPlate(dynamic node, String plate) {
    if (node is List) {
      return node.contains(plate);
    } else if (node is Map) {
      for (var value in node.values) {
        if (_containsPlate(value, plate)) return true;
      }
    }
    return false;
  }

  List<String> getAllPlatesInNode(dynamic node) {
    if (node is List) {
      return List<String>.from(node);
    } else if (node is Map) {
      final Set<String> results = {};
      for (var value in node.values) {
        results.addAll(getAllPlatesInNode(value));
      }
      return results.toList();
    }
    return [];
  }

  void addSubFolder(List<String> path, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    if (path.isEmpty) {
      if (!_data.containsKey(trimmed)) {
        _data[trimmed] = <String>[];
      }
    } else {
      _performActionAtPath(path, (parent, key) {
        var content = parent[key];

        if (content is List) {
          parent[key] = <String, dynamic>{
            trimmed: <String>[],
          };
        } else if (content is Map) {
          if (!content.containsKey(trimmed)) {
            content[trimmed] = <String>[];
          }
        }
      });
    }
    _save();
  }

  void deleteNode(List<String> path) {
    if (path.isEmpty) return;

    final String keyToDelete = path.last;
    final List<String> parentPath = path.sublist(0, path.length - 1);

    if (parentPath.isEmpty) {
      _data.remove(keyToDelete);
    } else {
      _performActionAtPath(parentPath, (parent, key) {
        final parentMap = parent[key];
        if (parentMap is Map) {
          parentMap.remove(keyToDelete);
        }
      });
    }
    _save();
  }

  void renameNode(List<String> path, String newName) {
    final trimmed = newName.trim();
    if (path.isEmpty || trimmed.isEmpty) return;

    final String oldKey = path.last;
    final List<String> parentPath = path.sublist(0, path.length - 1);

    if (parentPath.isEmpty) {
      final content = _data.remove(oldKey);
      _data[trimmed] = content;
    } else {
      _performActionAtPath(parentPath, (parent, key) {
        final parentMap = parent[key];
        if (parentMap is Map) {
          final content = parentMap.remove(oldKey);
          parentMap[trimmed] = content;
        }
      });
    }
    _save();
  }

  void updatePlateLocations(String plate, List<List<String>> targetPaths) {
    _removePlateFromAll(_data, plate);

    for (final path in targetPaths) {
      _performActionAtPath(path, (parent, key) {
        if (parent[key] is List) {
          final List list = parent[key];
          if (!list.contains(plate)) {
            list.add(plate);
            list.sort((a, b) => a.toString().compareTo(b.toString()));
          }
        }
      });
    }
    _save();
  }

  void _removePlateFromAll(dynamic node, String plate) {
    if (node is List) {
      node.remove(plate);
    } else if (node is Map) {
      for (var value in node.values) {
        _removePlateFromAll(value, plate);
      }
    }
  }

  void _performActionAtPath(List<String> path, Function(Map, String) action) {
    if (path.isEmpty) return;

    Map current = _data;
    for (int i = 0; i < path.length - 1; i++) {
      final key = path[i];
      if (current[key] is Map) {
        current = current[key];
      } else {
        return;
      }
    }
    action(current, path.last);
  }

  void importAll(Map<String, dynamic> json) {
    _data = json;
    _save();
  }

  void _save() {
    Static.localStorage.setFavoriteMap(Static.city, _data);
    notifyListeners();
  }
}
