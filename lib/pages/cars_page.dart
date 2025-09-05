import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class CarsPage extends StatelessWidget {
  const CarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        return SearchableList<Car>(
          allItems: Static.carData,
          searchHintText: "搜尋車牌（如：${Static.getExamplePlate()}）",
          // 優化過濾邏輯，移除所有非英數字符再比較
          filterCondition: (car, text) =>
              car.plate.toUpperCase().contains(text.toUpperCase()),
          sortCallback: (a, b) => a.plate.compareTo(b.plate),

          // 1. 使用重構後的 CarListItem
          // 邏輯非常清晰：列表中的每一項都是一個 CarListItem。
          // 在這個頁面，我們需要顯示「即時動態」按鈕。
          itemBuilder: (context, car) {
            return CarListItem(car: car, showLiveButton: true);
          },

          // 2. 使用重構後的 EmptyStateIndicator 處理搜尋無結果的情況
          emptyStateWidget: const EmptyStateIndicator(
            icon: Icons.search_off_rounded, // 使用圓角圖示，風格更統一
            title: "找不到符合的車牌",
            subtitle: "請檢查您的輸入，或該車牌尚未被記錄。",
          ),
        );
      },
    );
  }
}
