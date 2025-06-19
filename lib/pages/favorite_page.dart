// lib/pages/favorites_page.dart

import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';
import 'multi_live_osm_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        final List<Car> favoriteCars = Static.carData
            .where((car) => notifier.isFavorite(car.plate))
            .toList();

        final Widget body;

        if (favoriteCars.isEmpty) {
          body = const EmptyStateIndicator(
            icon: Icons.star_border_rounded,
            title: "尚未收藏任何車輛",
            subtitle: "請至「所有車輛」頁面點擊星星圖示\n將您關心的車輛加入收藏",
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FilledButton.icon(
                  onPressed: () {
                    final List<String> favoritePlates =
                        favoriteCars.map((car) => car.plate).toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MultiLiveOsmPage(
                          plates: favoritePlates,
                        ),
                      ),
                    );
                  },
                  label: const Text('顯示所有收藏動態'),
                  icon: const Icon(Icons.map_outlined),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: SearchableList<Car>(
                  allItems: favoriteCars,
                  searchHintText: "在收藏中搜尋車牌",
                  filterCondition: (car, text) =>
                      car.plate.toUpperCase().contains(text.toUpperCase()),
                  sortCallback: (a, b) => a.plate.compareTo(b.plate),
                  itemBuilder: (context, car) {
                    return CarListItem(car: car, showLiveButton: true);
                  },
                  emptyStateWidget: const EmptyStateIndicator(
                    icon: Icons.manage_search_rounded,
                    title: "在收藏中找不到車牌",
                    subtitle: "請嘗試使用不同的關鍵字搜尋",
                  ),
                ),
              ),
            ],
          );
        }

        // 使用 Scaffold 包裝，以便添加 AppBar 和 FloatingActionButton
        return body;
      },
    );
  }
}
