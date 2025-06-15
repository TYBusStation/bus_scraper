// lib/pages/route_page.dart

import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../widgets/searchable_list.dart';
import 'route_vehicles_page.dart'; // 導入新頁面

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

      // 每個列表項的構建器
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        route.name,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
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
                const SizedBox(height: 12), // 增加一點間距
                // 將兩個按鈕放在一個 Row 中
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 原有的「公車動態」按鈕，可以改為 OutlinedButton 以區分
                    OutlinedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(
                            "https://ebus.tycg.gov.tw/ebus/driving-map/${route.id}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('公車動態網'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 新增的「查詢車輛」按鈕
                    FilledButton.icon(
                      onPressed: () {
                        // 點擊後跳轉到新頁面，並將當前路線對象傳過去
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RouteVehiclesPage(route: route),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_bus_filled_outlined),
                      label: const Text('查詢車輛'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },

      // 提供搜尋不到結果時的顯示內容
      emptyStateWidget: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 100, color: colorScheme.primary.withOpacity(0.7)),
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
