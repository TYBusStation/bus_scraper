// lib/pages/route_page.dart

import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';
import 'route_vehicles_page.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  bool _showAllRoutes = false;
  bool _isLoading = false;
  late List<BusRoute> _displayedRoutes;

  @override
  void initState() {
    super.initState();
    _displayedRoutes = Static.routeData;
  }

  Future<void> _onSwitchChanged(bool value) async {
    if (_showAllRoutes == value) return;

    setState(() {
      _showAllRoutes = value;
      _isLoading = true;
    });

    if (value) {
      final allRoutes = await Static.fetchAllRoutes();
      if (mounted) {
        setState(() {
          _displayedRoutes = allRoutes;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _displayedRoutes = Static.routeData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          _buildControls(context),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  /// 建立頂部的控制項 (Switch)
  Widget _buildControls(BuildContext context) {
    return Card(
      elevation: 1,
      // 【核心修改】將 margin 壓到最小
      margin: const EdgeInsets.only(top: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '顯示所有路線',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _isLoading ? '正在載入所有路線...' : '切換顯示所有已定義路線',
              child: Switch(
                value: _showAllRoutes,
                onChanged: _isLoading ? null : _onSwitchChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立主要內容區域 (搜尋列表或載入動畫)
  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SearchableList<BusRoute>(
      key: ValueKey(_showAllRoutes),
      allItems: _displayedRoutes,
      searchHintText: "搜尋路線名稱、描述或編號...",
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
      itemBuilder: (context, route) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final colorScheme = theme.colorScheme;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.departure_board,
                        size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.departure,
                            style: textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward, size: 18),
                    ),
                    const Icon(Icons.flag, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.destination,
                            style: textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(Static.localStorage.city !=
                                "taichung"
                            ? "${Static.govWebUrl}/driving-map/${route.id}"
                            : "https://tybusstation.github.io/taichung_bus/");
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
                    FilledButton.icon(
                      onPressed: () {
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
      emptyStateWidget: const EmptyStateIndicator(
        icon: Icons.search_off,
        title: "找不到符合的路線",
        subtitle: "請嘗試更改搜尋關鍵字",
      ),
    );
  }
}
