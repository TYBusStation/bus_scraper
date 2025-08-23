// lib/widgets/car_list_item.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../pages/driver_search_page.dart';
import '../pages/history_page.dart';
import '../pages/live_osm_page.dart';
import '../pages/route_search_page.dart';
import '../static.dart';
import 'favorite_button.dart';
import 'favorite_provider.dart';

/// 一個可重用的 Widget，用於顯示單一車輛的資訊卡片。
///
/// 封裝了卡片樣式、車牌資訊、收藏按鈕和一個提供多種操作的按鈕。
class CarListItem extends StatelessWidget {
  const CarListItem({
    super.key,
    required this.car,
    required this.showLiveButton,
    this.drivingDates,
    this.driverId,
    this.routeId,
    this.margin, // 【核心修改】新增可選的 margin 參數
  });

  final Car car;
  final bool showLiveButton;
  final List<String>? drivingDates;
  final String? driverId;
  final String? routeId;
  final EdgeInsetsGeometry? margin; // 【核心修改】定義 margin 屬性

  // 顯示操作選項的對話框
  void _showActionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('車輛操作: ${car.plate}'),
          contentPadding: const EdgeInsets.only(top: 12.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showLiveButton)
                ListTile(
                  leading: const Icon(Icons.directions_bus_rounded),
                  title: const Text('即時動態'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LiveOsmPage(plate: car.plate)),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('行駛記錄'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => HistoryPage(plate: car.plate)),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_search_rounded),
                title: const Text('查詢駕駛'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverSearchPage(plate: car.plate),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.route_rounded),
                title: const Text('查詢路線'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RouteSearchPage(plate: car.plate),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final favoritesNotifier = context.watch<FavoritesNotifier>();

    final bool hasDates = drivingDates != null && drivingDates!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      // 【核心修改】使用傳入的 margin，若為 null 則使用預設值
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FavoriteButton(
                    plate: car.plate,
                    notifier: favoritesNotifier,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.plate,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          car.typeDisplayName,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "最後上線：${Static.displayDateFormat.format(car.lastSeen)}",
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showActionsDialog(context),
                    icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    label: const Text('操作'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
              if (hasDates) ...[
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: drivingDates!
                      .map((date) => ActionChip(
                            label: Text(date),
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 12,
                            ),
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            onPressed: () {
                              final selectedDate = DateTime.parse(date);
                              final startTime = DateTime(selectedDate.year,
                                  selectedDate.month, selectedDate.day);
                              final endTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              ).add(const Duration(days: 1));

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryPage(
                                    plate: car.plate,
                                    initialStartTime: startTime,
                                    initialEndTime: endTime,
                                    initialDriverId: driverId,
                                    initialRouteId: routeId,
                                  ),
                                ),
                              );
                            },
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
