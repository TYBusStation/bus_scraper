// lib/pages/map_route_selection_page.dart

import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../static.dart';
import '../widgets/searchable_list.dart';

class RouteDirectionSelection {
  bool go;
  bool back;

  RouteDirectionSelection({this.go = false, this.back = false});

  bool get isSelected => go || back;
}

class MapRouteSelectionPage extends StatefulWidget {
  // [MODIFIED] 參數恢復為只接收路線選擇
  final Map<String, RouteDirectionSelection> initialSelections;

  const MapRouteSelectionPage({
    super.key,
    required this.initialSelections,
  });

  @override
  State<MapRouteSelectionPage> createState() => _MapRouteSelectionPageState();
}

class _MapRouteSelectionPageState extends State<MapRouteSelectionPage> {
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
    _displayedRoutes = Static.routeData;
  }

  Future<void> _onSwitchChanged(bool value) async {
    if (_showAllRoutes == value) return;

    setState(() {
      _showAllRoutes = value;
      if (!value) {
        _displayedRoutes = Static.routeData;
      }
    });

    if (value) {
      if (Static.allRouteData != null) {
        setState(() {
          _displayedRoutes = Static.allRouteData!;
        });
      } else {
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
                              Row(
                                children: [
                                  const Icon(Icons.departure_board,
                                      size: 20, color: Colors.green),
                                  const SizedBox(width: 8),
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
