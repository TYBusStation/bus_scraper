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
    // 同樣使用 Consumer 來監聽收藏狀態的變化
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        // --- 核心邏輯：從所有車輛中篩選出被收藏的車輛 ---
        final List<Car> favoriteCars = Static.carData
            .where((car) => notifier.isFavorite(car.plate))
            .toList();

        // 如果收藏列表是空的，直接顯示一個提示畫面
        if (favoriteCars.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border,
                    size: 100, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 10),
                const Text(
                  "尚未收藏任何車輛",
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  "請至「車輛」頁面點擊星星圖示加入收藏",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // 如果有收藏的車輛，則使用 SearchableList 顯示它們
        return SearchableList<Car>(
          // 資料來源是篩選過的 favoriteCars
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
          itemBuilder: (context, car) {
            // 這裡的 isFavorite 永遠是 true，但為了程式碼一致性還是保留
            final bool isFavorite = notifier.isFavorite(car.plate);
            return ListTile(
              leading: FavoriteButton(
                plate: car.plate,
                notifier: notifier,
              ),
              title: Text(
                car.plate,
                style: const TextStyle(fontSize: 18),
              ),
              subtitle: Text(
                car.type.chinese,
                style: const TextStyle(fontSize: 16),
              ),
              trailing: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryPage(plate: car.plate),
                    ),
                  );
                },
                style:
                    FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
                child: const Text('歷史位置', style: TextStyle(fontSize: 16)),
              ),
            );
          },
          // 當在收藏中搜尋不到結果時的提示
          emptyStateWidget: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    size: 100, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 10),
                const Text(
                  "在您的收藏中找不到符合的車牌",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
