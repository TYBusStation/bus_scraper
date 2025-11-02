import 'package:bus_scraper/data/bus_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import '../storage/city.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          _buildControls(context),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '顯示所有路線',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: _isLoading ? '正在載入所有路線...' : '切換顯示所有已定義路線',
              child: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _showAllRoutes,
                  onChanged: _isLoading ? null : _onSwitchChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SearchableList<BusRoute>(
      key: ValueKey(_showAllRoutes),
      allItems: _displayedRoutes,
      searchHintText: "搜尋路線名稱、描述或編號",
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
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.departure_board,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.departure,
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                    const Icon(Icons.flag, size: 18, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.destination,
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  route.description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '編號：${route.id}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(Static.city != City.taichung
                            ? "${Static.city.url}/driving-map/${route.id}"
                            : "https://tybusstation.github.io/taichung_bus/");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('公車動態網'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: theme.textTheme.labelMedium,
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
                      icon: const Icon(Icons.directions_bus_filled_outlined,
                          size: 16),
                      label: const Text('查詢車輛'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: theme.textTheme.labelMedium,
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
