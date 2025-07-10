// lib/pages/route_page.dart

import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../widgets/searchable_list.dart';
import 'route_vehicles_page.dart'; // 導入新頁面

// 將 RoutePage 轉換為 StatefulWidget 以管理 switch 狀態
class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  bool _showAllRoutes = false; // 用於管理 switch 狀態的變數，預設為 false (不顯示所有路線)
  bool _isLoading = false; // 用於管理是否正在從 API 載入資料
  late List<BusRoute> _displayedRoutes = Static.routeData; // 明確型別

  @override
  void initState() {
    super.initState();
    // 初始化時，預設顯示「營運中 + 特殊」路線
    _displayedRoutes = Static.routeData;
  }

  // 當 switch 狀態改變時呼叫此方法
  Future<void> _onSwitchChanged(bool value) async {
    if (_showAllRoutes == value) return; // 如果當前值已經是目標值，則不做任何操作
    setState(() {
      _showAllRoutes = value;
      if (!value)
        _displayedRoutes = Static.routeData; // 如果切換回不顯示所有路線，則直接使用快取的特殊路線
    });

    if (value) {
      // 如果用戶切換到「顯示所有路線」
      // 檢查 Static 中是否已有快取
      if (Static.allRouteData != null) {
        // 如果有快取，直接使用快取資料更新列表
        setState(() {
          _displayedRoutes = Static.allRouteData!;
        });
      } else {
        // 如果沒有快取，則顯示載入動畫並從 API 獲取
        setState(() {
          _isLoading = true; // 開始載入
        });
        // 呼叫 Static 中的方法獲取所有路線資料 (此方法內含快取邏輯)
        final allRoutes = await Static.fetchAllRoutes();
        // 獲取完畢後，更新列表並關閉載入動畫
        // 確保 widget 仍然存在於 widget tree 中
        if (mounted) {
          setState(() {
            _displayedRoutes = allRoutes;
            _isLoading = false; // 結束載入
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題以便在整個 build 方法中使用
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // 使用 Column 將 Switch 控制項和列表組合起來
    return Column(
      children: [
        // 在列表上方新增 Switch 控制項
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '顯示所有路線',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _isLoading ? '正在載入所有路線...' : '',
              child: Switch(
                value: _showAllRoutes,
                // 當 Switch 被點擊時，呼叫 _onSwitchChanged 方法
                // 如果正在載入中，則禁用 Switch
                onChanged: _isLoading ? null : _onSwitchChanged,
              ),
            ),
          ],
        ),
        // 使用 Expanded 讓列表填滿剩餘空間
        Expanded(
          // 根據 _isLoading 狀態決定顯示載入動畫還是列表
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SearchableList<BusRoute>(
                  // 核心修改：列表的資料來源現在是 state 中的 _displayedRoutes
                  allItems: _displayedRoutes,
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
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.name,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
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
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Icon(Icons.arrow_forward, size: 18),
                                ),
                                const Icon(Icons.flag,
                                    size: 20, color: Colors.red),
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
                                        "${Static.govWebUrl}/driving-map/${route.id}");
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
                                  icon: const Icon(
                                      Icons.directions_bus_filled_outlined),
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
                    // 若有 EmptyStateIndicator 請改用該元件
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 100,
                            color: colorScheme.primary.withOpacity(0.7)),
                        const SizedBox(height: 16),
                        Text(
                          "找不到符合的路線",
                          style: textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
