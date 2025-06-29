// lib/providers/favorites_provider.dart

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../static.dart'; // 假設 Static 類別在此路徑

// 1. 建立一個專門管理收藏的 Notifier
class FavoritesNotifier extends ChangeNotifier implements ReassembleHandler {
  // 私有變數，儲存收藏列表的快取
  List<String> _favoritePlates = [];

  // 初始化時，從 localStorage 讀取初始收藏列表
  FavoritesNotifier(List<String> initialList) {
    _favoritePlates = initialList;
  }

  void setFavoritePlates(List<String> list) {
    _favoritePlates = list;
    notifyListeners(); // 新增：確保外部變動時 UI 會更新
  }

  // 提供一個 getter 讓外部可以安全地讀取收藏列表
  List<String> get favoritePlates => _favoritePlates;

  bool isFavorite(String plate) {
    return _favoritePlates.contains(plate);
  }

  // 切換收藏狀態的核心方法
  void toggleFavorite(String plate) {
    if (isFavorite(plate)) {
      // 如果已收藏，則從快取和 localStorage 中移除
      _favoritePlates.remove(plate);
    } else {
      // 如果未收藏，則加入到快取和 localStorage
      _favoritePlates.add(plate);
    }
    Static.localStorage.favoritePlates = _favoritePlates;

    // 通知所有監聽者狀態已改變，需要重繪
    notifyListeners();
  }

  @override
  void reassemble() {
    setFavoritePlates(Static.localStorage.favoritePlates);
  }
}
