import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/favorite_button.dart';
import '../widgets/searchable_list.dart';
import 'history_page.dart';

class CarsPage extends StatelessWidget {
  const CarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        return SearchableList<Car>(
          allItems: Static.carData,
          searchHintText: "搜尋車牌",
          filterCondition: (car, text) {
            final cleanPlate =
                car.plate.replaceAll(Static.letterNumber, "").toUpperCase();
            final cleanText =
                text.replaceAll(Static.letterNumber, "").toUpperCase();
            return cleanPlate.contains(cleanText);
          },
          sortCallback: (a, b) => a.plate.compareTo(b.plate),

          // 5. 定義如何建立每個列表項 (美化核心)
          itemBuilder: (context, car) {
            // 使用 Card 包裹 ListTile，增加視覺間隔和陰影
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                // 收藏按鈕，維持原樣
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
                onTap: () {
                  // 這裡可以留空，讓 ListTile 捕捉點擊事件並顯示波紋效果
                  // 或許未來可以做成點擊整個項目就跳轉到歷史頁面
                },
              ),
            );
          },

          // 6. 空狀態顯示 (移除不必要的 ThemeProvider)
          emptyStateWidget: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    size: 100, color: colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 16),
                Text(
                  "找不到符合的車牌\n或車牌尚未被記錄",
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
