// lib/widgets/car_list_item.dart

import 'package:bus_scraper/pages/live_osm_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../pages/history_page.dart';
import 'favorite_button.dart';
import 'favorite_provider.dart';

/// 一個可重用的 Widget，用於顯示單一車輛的資訊卡片。
///
/// 封裝了卡片樣式、車牌資訊、收藏按鈕和操作按鈕。
class CarListItem extends StatelessWidget {
  const CarListItem({
    super.key,
    required this.car,
    required this.showLiveButton,
    this.drivingDates,
    this.driverId,
    this.routeId, // 【新增】接收 routeId 參數
  });

  /// 要顯示的車輛資料。
  final Car car;

  /// 是否顯示「即時動態」按鈕。
  final bool showLiveButton;

  /// 要顯示的駕駛日期列表 (List<String>)
  final List<String>? drivingDates;

  /// 當前查詢的駕駛員 ID，用於點擊日期時傳遞
  final String? driverId;

  /// 【新增】當前查詢的路線 ID，用於點擊日期時傳遞
  final String? routeId;

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 上層資訊區 ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側收藏按鈕
                  FavoriteButton(
                    plate: car.plate,
                    notifier: favoritesNotifier,
                  ),
                  const SizedBox(width: 16),
                  // 中間的文字資訊
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
                          car.type.chinese,
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  // 右側的操作按鈕
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHistoryButton(context),
                      if (showLiveButton) ...[
                        _buildLiveButton(context),
                      ],
                    ],
                  ),
                ],
              ),
              // --- 下層日期區 ---
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
                                    // 【修改】將 routeId 傳遞過去
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

  Widget _buildHistoryButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.history_rounded),
      tooltip: '歷史紀錄',
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryPage(plate: car.plate),
          ),
        );
      },
    );
  }

  Widget _buildLiveButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.directions_bus_rounded),
      tooltip: '即時動態',
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(10),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => LiveOsmPage(plate: car.plate)),
        );
      },
    );
  }
}
