// lib/pages/map_route_selection_page.dart

import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../static.dart';
import '../widgets/searchable_list.dart';

/// 用於管理單一路線的去程/返程選擇狀態
class RouteDirectionSelection {
  bool go;
  bool back;

  RouteDirectionSelection({this.go = false, this.back = false});

  bool get isSelected => go || back;
}

class MapRouteSelectionPage extends StatefulWidget {
  final Map<String, RouteDirectionSelection> initialSelections;

  const MapRouteSelectionPage({
    super.key,
    required this.initialSelections,
  });

  @override
  State<MapRouteSelectionPage> createState() => _MapRouteSelectionPageState();
}

class _MapRouteSelectionPageState extends State<MapRouteSelectionPage> {
  // --- 新增狀態變數，與 RoutePage 保持一致 ---
  late Map<String, RouteDirectionSelection> _selections;
  bool _showAllRoutes = false;
  bool _isLoading = false;
  late List<BusRoute> _displayedRoutes;

  @override
  void initState() {
    super.initState();
    // 深拷貝初始選擇
    _selections = widget.initialSelections.map(
      (key, value) => MapEntry(
          key, RouteDirectionSelection(go: value.go, back: value.back)),
    );
    // 預設顯示 Static.routeData
    _displayedRoutes = Static.routeData;
  }

  // --- 新增處理 Switch 變更的邏輯，與 RoutePage 類似 ---
  Future<void> _onSwitchChanged(bool value) async {
    if (_showAllRoutes == value) return;

    setState(() {
      _showAllRoutes = value;
      // 如果關閉 Switch，直接切換回預設路線
      if (!value) {
        _displayedRoutes = Static.routeData;
      }
    });

    if (value) {
      // 如果開啟 Switch
      if (Static.allRouteData != null) {
        // 使用快取
        setState(() {
          _displayedRoutes = Static.allRouteData!;
        });
      } else {
        // 從 API 獲取
        setState(() => _isLoading = true);
        final allRoutes = await Static.fetchAllRoutes();
        if (mounted) {
          setState(() {
            _displayedRoutes = allRoutes;
            _isLoading = false;
          });
        }
      }
    }
  }

  void _toggleSelection(String routeId, {bool? go, bool? back}) {
    setState(() {
      _selections.putIfAbsent(routeId, () => RouteDirectionSelection());
      final selection = _selections[routeId]!;
      if (go != null) selection.go = go;
      if (back != null) selection.back = back;
    });
  }

  void _clearAllSelections() {
    setState(() {
      _selections.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清除所有選擇'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final selectedCount = _selections.values.where((s) => s.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('選擇繪製路線 ($selectedCount)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('完成'),
              onPressed: () => Navigator.pop(context, _selections),
            ),
          ),
        ],
      ),
      // --- 使用 Column 組合 Switch 和列表 ---
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('顯示所有路線', style: textTheme.bodyLarge),
              const SizedBox(width: 8),
              Tooltip(
                message: _isLoading ? '正在載入所有路線...' : '',
                child: Switch(
                  value: _showAllRoutes,
                  onChanged: _isLoading ? null : _onSwitchChanged,
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SearchableList<BusRoute>(
                    allItems: _displayedRoutes,
                    searchHintText: '搜尋路線名稱、描述或編號（如：1）',
                    filterCondition: (route, text) => text
                        .toUpperCase()
                        .split(" ")
                        .where((t) => t.isNotEmpty)
                        .every((token) =>
                            '${route.name} ${route.description} ${route.id} ${route.departure} ${route.destination}'
                                .toUpperCase()
                                .contains(token)),
                    sortCallback: (a, b) =>
                        Static.compareRoutes(a.name, b.name),
                    itemBuilder: (context, route) {
                      final selection =
                          _selections[route.id] ?? RouteDirectionSelection();

                      // --- 模仿 RoutePage 的 Card 樣式 ---
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: selection.isSelected
                            ? colorScheme.primaryContainer.withOpacity(0.5)
                            : null,
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
                                      style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold),
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
                                      style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold),
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
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: Text('往 ${route.destination}'),
                                      value: selection.go,
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (value) =>
                                          _toggleSelection(route.id, go: value),
                                    ),
                                  ),
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: Text('往 ${route.departure}'),
                                      value: selection.back,
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (value) => _toggleSelection(
                                          route.id,
                                          back: value),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    emptyStateWidget: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 100,
                              color: colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(height: 16),
                          Text("找不到符合的路線", style: textTheme.headlineSmall),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
