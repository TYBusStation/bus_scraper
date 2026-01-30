import 'package:flutter/foundation.dart';

import '../utils/static.dart';

class FavoritesNotifier extends ChangeNotifier {
  // 核心資料結構：Map<String, dynamic>
  // Value 為 Map 代表子資料夾，Value 為 List<String> 代表車牌清單
  Map<String, dynamic> _data = {};

  FavoritesNotifier() {
    _load();
  }

  /// 從 LocalStorage 載入資料
  void _load() {
    _data = Static.localStorage.getFavoriteMap(Static.city);
    notifyListeners();
  }

  Map<String, dynamic> get data => _data;

  // --- 查詢邏輯 ---

  /// 遞歸檢查車牌是否在任何一個層級中
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

  /// 獲取該節點（及所有深層子節點）內的所有車牌
  /// 用於點擊資料夾按鈕時，彙整該群組下所有的公車
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

  // --- 修改邏輯 (依據路徑 Path 操作) ---

  /// 新增子群組
  /// [path] 為父層級路徑，例如 ['桃園客運', '桃園站']
  void addSubFolder(List<String> path, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    if (path.isEmpty) {
      // 根目錄新增：如果不存在，預設為 List (可放車牌的末端節點)
      if (!_data.containsKey(trimmed)) {
        _data[trimmed] = <String>[];
      }
    } else {
      _performActionAtPath(path, (parent, key) {
        var content = parent[key];

        // --- 互斥規則實作 ---
        // 如果目前該層級是 List (裡面可能有車牌)，
        // 但使用者要在那邊「新增子群組」，則強制轉型為 Map (資料夾)。
        // 原本在該層級的車牌會被清空，以確保同一層只能有其中一種。
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

  /// 刪除節點 (資料夾或車牌列表)
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

  /// 重新命名節點
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

  /// 更新車牌存放的位置 (供 FavoriteButton 勾選使用)
  /// [targetPaths] 是一個二維清單，例如 [['桃園客運', '桃園站']]
  void updatePlateLocations(String plate, List<List<String>> targetPaths) {
    // 1. 先從全樹移除該車牌 (確保不會在多個地方重複，除非使用者勾選多個路徑)
    _removePlateFromAll(_data, plate);

    // 2. 根據路徑加入到對應的 List 中
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

  /// 遞歸輔助方法：從整個嵌套地圖中移除某個車牌
  void _removePlateFromAll(dynamic node, String plate) {
    if (node is List) {
      node.remove(plate);
    } else if (node is Map) {
      for (var value in node.values) {
        _removePlateFromAll(value, plate);
      }
    }
  }

  /// 核心輔助方法：導航到路徑的父層級並執行動作
  /// [path] 目標路徑
  /// [action] 回呼函式 (parentMap, keyInParent)
  void _performActionAtPath(List<String> path, Function(Map, String) action) {
    if (path.isEmpty) return;

    Map current = _data;
    // 鑽入直到倒數第二層
    for (int i = 0; i < path.length - 1; i++) {
      final key = path[i];
      if (current[key] is Map) {
        current = current[key];
      } else {
        // 如果路徑中途斷掉，則停止
        return;
      }
    }
    // 執行最後一級的操作
    action(current, path.last);
  }

  // --- 持久化與通知 ---

  /// 取代匯入
  void importAll(Map<String, dynamic> json) {
    _data = json;
    _save();
  }

  void _save() {
    Static.localStorage.setFavoriteMap(Static.city, _data);
    notifyListeners();
  }
}
