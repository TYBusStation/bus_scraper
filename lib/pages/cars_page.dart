import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../utils/static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class CarsPage extends StatelessWidget {
  const CarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Consumer<FavoritesNotifier>(
        builder: (context, notifier, child) {
          return SearchableList<Car>(
            allItems: Static.carData,
            searchHintText: "搜尋車牌（如：${Static.city.exPlate}）",
            filterCondition: (car, text) =>
                car.plate.toUpperCase().contains(text.toUpperCase()),
            sortCallback: (a, b) => a.plate.compareTo(b.plate),
            itemBuilder: (context, car) {
              return CarListItem(car: car, showLiveButton: true);
            },
            emptyStateWidget: const EmptyStateIndicator(
              icon: Icons.search_off_rounded,
              title: "找不到符合的車牌",
              subtitle: "請檢查您的輸入，或該車牌尚未被記錄。",
            ),
          );
        },
      ),
    );
  }
}
