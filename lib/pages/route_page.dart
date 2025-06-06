import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../widgets/searchable_list.dart'; // 導入新的通用元件
import '../widgets/theme_provider.dart';

// RoutePage 現在是一個 StatelessWidget，因為所有狀態都由 SearchableListPage 管理
class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 直接返回配置好的 SearchableListPage
    return SearchableList<BusRoute>(
      // 1. 提供完整的路線資料
      allItems: Static.routeData,
      // 2. 設定搜尋框的提示文字 (優化了提示，使其更符合搜尋邏輯)
      searchHintText: "搜尋路線名稱、描述或編號",
      // 3. 定義過濾條件
      filterCondition: (route, text) {
        // 使用者輸入的每個關鍵字 (以空格分隔) 都必須在路線的某個屬性中找到
        return text
            .toUpperCase()
            .split(" ")
            .where((token) => token.isNotEmpty) // 避免因多餘空格產生空字串
            .every((token) =>
                route.name.toUpperCase().contains(token) ||
                route.description.toUpperCase().contains(token) ||
                route.id.toUpperCase().contains(token));
      },
      // 4. 定義如何排序
      sortCallback: (a, b) => Static.compareRoutes(a.name, b.name),
      // 5. 定義如何建立每個列表項
      itemBuilder: (context, route) {
        return ListTile(
          title: Text(
            route.name,
            style: const TextStyle(fontSize: 18),
          ),
          subtitle: Text(
            "${route.description}\n編號：${route.id}",
            style: const TextStyle(fontSize: 16),
          ),
          trailing: FilledButton(
            onPressed: () async => await launchUrl(Uri.parse(
                "https://ebus.tycg.gov.tw/ebus/driving-map/${route.id}")),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
            child: const Text('公車動態網', style: TextStyle(fontSize: 16)),
          ),
        );
      },
      // 6. 提供搜尋不到結果時的顯示內容
      emptyStateWidget: ThemeProvider(
        builder: (BuildContext context, ThemeData themeData) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off,
                  size: 100, color: themeData.colorScheme.primary),
              const SizedBox(height: 10),
              const Text(
                "找不到符合的路線",
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
