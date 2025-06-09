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
/// 【修改】：將導航功能從整個卡片點擊改為由獨立的按鈕觸發。
class CarListItem extends StatelessWidget {
  const CarListItem({
    super.key,
    required this.car,
    required this.showLiveButton,
  });

  /// 要顯示的車輛資料。
  final Car car;

  /// 是否顯示「即時動態」按鈕。
  final bool showLiveButton;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 從 Provider 中獲取 FavoritesNotifier，以便傳遞給 FavoriteButton
    final favoritesNotifier = context.watch<FavoritesNotifier>();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 【修改】：移除了外層的 InkWell，卡片本身不再響應點擊事件。
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          // 收藏按鈕
          leading: FavoriteButton(
            plate: car.plate,
            notifier: favoritesNotifier,
          ),
          // 車牌
          title: Text(
            car.plate,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          // 車輛類型
          subtitle: Text(
            car.type.chinese,
            style: textTheme.bodyLarge,
          ),
          // 【修改】：右側的操作按鈕現在是一個包含多個按鈕的 Row
          trailing: Row(
            mainAxisSize: MainAxisSize.min, // 讓 Row 只佔用其子項所需的最小寬度
            children: [
              // 歷史紀錄按鈕
              _buildHistoryButton(context),
              // 如果需要，顯示即時動態按鈕
              if (showLiveButton) ...[
                const SizedBox(width: 4), // 在按鈕之間增加一點間距
                _buildLiveButton(context),
              ],
            ],
          ),
          // ListTile 本身也不再需要 onTap
        ),
      ),
    );
  }

  /// 建立一個「歷史紀錄」按鈕。
  Widget _buildHistoryButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.history_rounded), // 使用圓角圖示，風格統一
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

  /// 建立一個風格化的「即時動態」按鈕。
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
