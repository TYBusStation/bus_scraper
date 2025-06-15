import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 我們需要在 Consumer 內部監聽 notifier，所以不需要在外部獲取
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        // 從所有車輛中篩選出被收藏的車輛
        final List<Car> favoriteCars = Static.carData
            .where((car) => notifier.isFavorite(car.plate))
            .toList();

        // 1. 使用 EmptyStateIndicator 處理「尚未收藏任何車輛」的初始狀態
        if (favoriteCars.isEmpty) {
          return const EmptyStateIndicator(
            icon: Icons.star_border_rounded,
            title: "尚未收藏任何車輛",
            subtitle: "請至「所有車輛」頁面點擊星星圖示\n將您關心的車輛加入收藏",
          );
        }

        // 2. 如果有收藏的車輛，則顯示可搜尋的列表
        return SearchableList<Car>(
          allItems: favoriteCars,
          searchHintText: "在收藏中搜尋車牌",
          // 過濾和排序邏輯與 CarsPage 保持一致
          filterCondition: (car, text) =>
              car.plate.toUpperCase().contains(text.toUpperCase()),
          sortCallback: (a, b) => a.plate.compareTo(b.plate),

          // 3. 同樣使用重構後的 CarListItem
          // 在收藏頁，我們也顯示「即時動態」按鈕，保持操作一致性。
          itemBuilder: (context, car) {
            return CarListItem(car: car, showLiveButton: true);
          },

          // 4. 使用 EmptyStateIndicator 處理「在收藏中搜尋不到」的狀態
          emptyStateWidget: const EmptyStateIndicator(
            icon: Icons.manage_search_rounded,
            title: "在收藏中找不到車牌",
            subtitle: "請嘗試使用不同的關鍵字搜尋",
          ),
        );
      },
    );
  }
}
