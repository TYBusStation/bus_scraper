import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../widgets/searchable_list.dart';

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題以便在整個 build 方法中使用
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return SearchableList<BusRoute>(
      allItems: Static.routeData,
      searchHintText: "搜尋路線名稱、描述或編號（如：1）",
      filterCondition: (route, text) {
        return text
            .toUpperCase()
            .split(" ")
            .where((token) => token.isNotEmpty)
            .every((token) => [
                  route.id,
                  route.name,
                  route.description,
                  route.departure,
                  route.destination,
                ].any((str) => str.toUpperCase().contains(token)));
      },
      sortCallback: (a, b) => Static.compareRoutes(a.name, b.name),

      // 5. 定義如何建立每個列表項 (美化核心)
      itemBuilder: (context, route) {
        // 使用 Card 來提升視覺層次感
        return Card(
          elevation: 2, // 輕微的陰影
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 路線名稱，使用較大的標題樣式
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 使用 Chip 顯示路線編號，更美觀
                    Text(
                      route.name,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    // 使用帶有圖示的按鈕，更直觀
                    FilledButton.icon(
                      onPressed: () async => await launchUrl(Uri.parse(
                          "https://ebus.tycg.gov.tw/ebus/driving-map/${route.id}")),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('公車動態'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 起站與終站，使用 Row 和 Icon 視覺化呈現
                Row(
                  children: [
                    const Icon(Icons.departure_board,
                        size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    // 使用 Flexible 避免文字過長導致排版錯誤
                    Flexible(
                      child: Text(
                        route.departure,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward, size: 18),
                    ),
                    const Icon(Icons.flag, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        route.destination,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  route.description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '編號：${route.id}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },

      // 6. 提供搜尋不到結果時的顯示內容 (移除不必要的 ThemeProvider)
      emptyStateWidget: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 100, color: colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              "找不到符合的路線",
              style: textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
