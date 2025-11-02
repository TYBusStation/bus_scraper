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
              icon: const Icon(Icons.check, size: 18),
              label: const Text('完成'),
              onPressed: () => Navigator.pop(context, _selections),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('顯示所有路線', style: textTheme.bodyMedium),
                const SizedBox(width: 4),
                Tooltip(
                  message: _isLoading ? '正在載入所有路線...' : '',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SearchableList<BusRoute>(
                    allItems: _displayedRoutes,
                    searchHintText: '搜尋路線名稱、描述或編號',
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
                            horizontal: 8, vertical: 4),
                        color: selection.isSelected
                            ? colorScheme.primaryContainer.withOpacity(0.5)
                            : null,
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.departure_board,
                                      size: 18, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      route.departure,
                                      style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 6.0),
                                    child: Icon(Icons.arrow_forward, size: 16),
                                  ),
                                  const Icon(Icons.flag,
                                      size: 18, color: Colors.red),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      route.destination,
                                      style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold),
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
                              const Divider(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      title: Text(
                                        '往 ${route.destination}',
                                        style: textTheme.bodySmall,
                                      ),
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
                                      title: Text(
                                        '往 ${route.departure}',
                                        style: textTheme.bodySmall,
                                      ),
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
                              size: 80,
                              color: colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(height: 12),
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
