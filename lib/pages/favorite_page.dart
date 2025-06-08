// lib/pages/favorites_page.dart

import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/favorite_button.dart';
import '../widgets/searchable_list.dart';
import 'history_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題，以便在整個 Widget 中重複使用
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        // --- 核心邏輯：從所有車輛中篩選出被收藏的車輛 ---
        final List<Car> favoriteCars = Static.carData
            .where((car) => notifier.isFavorite(car.plate))
            .toList();

        // --- 美化核心 1: 優化空白狀態的顯示 ---
        // 如果收藏列表是空的，直接顯示一個風格化的提示畫面
        if (favoriteCars.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline_rounded, // 使用圓角圖示，更柔和
                  size: 100,
                  color: colorScheme.primary.withOpacity(0.7), // 使用主題顏色並帶有透明度
                ),
                const SizedBox(height: 16),
                Text(
                  "尚未收藏任何車輛",
                  style: textTheme.headlineSmall, // 使用主題定義的標題樣式
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "請至「車輛」頁面點擊星星圖示加入收藏",
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant, // 使用主題的次要文字顏色
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // 如果有收藏的車輛，則使用 SearchableList 顯示它們
        return SearchableList<Car>(
          allItems: favoriteCars,
          searchHintText: "在收藏中搜尋車牌",
          filterCondition: (car, text) {
            final cleanPlate =
                car.plate.replaceAll(Static.letterNumber, "").toUpperCase();
            final cleanText =
                text.replaceAll(Static.letterNumber, "").toUpperCase();
            return cleanPlate.contains(cleanText);
          },
          sortCallback: (a, b) => a.plate.compareTo(b.plate),

          // --- 美化核心 2: 列表項目與 cars_page.dart 保持一致 ---
          itemBuilder: (context, car) {
            // 使用 Card 包裹 ListTile，增加視覺間隔和陰影
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                // 收藏按鈕，當點擊後會立即將此項目從列表中移除
                leading: FavoriteButton(
                  plate: car.plate,
                  notifier: notifier,
                ),
                // 車牌，使用主題的標題樣式
                title: Text(
                  car.plate,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                // 車輛類型，使用主題的副標題樣式
                subtitle: Text(
                  car.type.chinese,
                  style: textTheme.bodyLarge,
                ),
                trailing: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryPage(plate: car.plate),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: const Text('歷史紀錄'),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                // 增加點擊時的波紋效果
                onTap: () {},
              ),
            );
          },

          // --- 美化核心 3: 優化搜尋無結果的狀態顯示 ---
          emptyStateWidget: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 100,
                  color: colorScheme.primary.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  "在您的收藏中找不到符合的車牌",
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
