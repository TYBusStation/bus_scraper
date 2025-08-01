// lib/pages/route_search_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_route.dart';
import '../data/vehicle_history.dart';
import '../pages/route_vehicles_page.dart';
import '../static.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';
import 'history_page.dart';

// 輔助類，將完整的路線資訊和歷史記錄綁定在一起
class BusRouteWithHistory {
  final BusRoute route;
  final VehicleRouteHistory history;

  BusRouteWithHistory({required this.route, required this.history});
}

class RouteSearchPage extends StatefulWidget {
  final String plate;

  const RouteSearchPage({super.key, required this.plate});

  @override
  State<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends State<RouteSearchPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final _displayDateFormat = DateFormat('yyyy/MM/dd');

  bool _hasSearched = false;
  Future<List<VehicleRouteHistory>>? _searchFuture;
  String? _promptMessage = "請選擇日期範圍後點擊查詢";

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2025, 6, 8),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = pickedDate;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
        if (_hasSearched) {
          _hasSearched = false;
          _promptMessage = "日期已更新，請重新點擊「查詢」。";
        }
      });
    }
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _promptMessage = null;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = Static.findVehicleRoutes(
        plate: widget.plate,
        startDate: _startDate,
        endDate: finalEndDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 路線查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlCard(),
            Expanded(
              child: _hasSearched ? _buildResultsList() : _buildPromptArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _buildDatePicker(
                        label: "起始日期",
                        value: _startDate,
                        onPressed: () => _selectDate(context, true))),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildDatePicker(
                        label: "結束日期",
                        value: _endDate,
                        onPressed: () => _selectDate(context, false))),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text("查詢路線"),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
      {required String label,
      required DateTime value,
      required VoidCallback onPressed}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  DateFormat('yyyy/MM/dd').format(value),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_month_outlined, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptArea() {
    final title = _promptMessage?.contains("更新") ?? false ? "請重新查詢" : "開始查詢";
    return EmptyStateIndicator(
      icon: Icons.search_rounded,
      title: title,
      subtitle: _promptMessage ?? '',
    );
  }

  Widget _buildResultsList() {
    return FutureBuilder<List<VehicleRouteHistory>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateIndicator(
              icon: Icons.error_outline_rounded,
              title: '查詢失敗',
              subtitle: snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateIndicator(
              icon: Icons.alt_route_rounded,
              title: '查無資料',
              subtitle: '在此日期區間內找不到任何行駛路線記錄');
        }

        final routesHistory = snapshot.data!;

        return FutureBuilder<List<BusRouteWithHistory>>(
          future: Future.wait(routesHistory.map((history) async {
            final routeDetails = await Static.getRouteById(history.routeId);
            return BusRouteWithHistory(route: routeDetails, history: history);
          })),
          builder: (context, processedSnapshot) {
            if (processedSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!processedSnapshot.hasData) {
              return const EmptyStateIndicator(
                  icon: Icons.bus_alert_rounded, title: '無法載入路線資訊');
            }

            final List<BusRouteWithHistory> allItems = processedSnapshot.data!;

            return SearchableList<BusRouteWithHistory>(
              allItems: allItems,
              searchHintText: "搜尋路線名稱、描述或編號...",
              filterCondition: (item, text) {
                return text
                    .toUpperCase()
                    .split(" ")
                    .where((token) => token.isNotEmpty)
                    .every(
                      (token) => [
                        item.route.id,
                        item.route.name,
                        item.route.description,
                        item.route.departure,
                        item.route.destination,
                      ].any((str) => str.toUpperCase().contains(token)),
                    );
              },
              sortCallback: (a, b) =>
                  Static.compareRoutes(a.route.name, b.route.name),
              itemBuilder: (context, item) {
                final BusRoute route = item.route;
                final VehicleRouteHistory routeInfo = item.history;
                final theme = Theme.of(context);
                final textTheme = theme.textTheme;
                final colorScheme = theme.colorScheme;

                return Card(
                  elevation: 2,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(route.departure,
                                      style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold))
                                ])),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(Icons.arrow_forward, size: 18)),
                            const Icon(Icons.flag, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(route.destination,
                                      style: textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold))
                                ])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 【核心修改】補回路線描述
                        Text(
                          route.description,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text('編號：${route.id}',
                            style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(
                                    "${Static.govWebUrl}/driving-map/${route.id}");
                                if (await canLaunchUrl(url))
                                  await launchUrl(url);
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
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          RouteVehiclesPage(route: route))),
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
                        const SizedBox(height: 12),
                        Divider(
                            height: 1,
                            color: theme.dividerColor.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: routeInfo.dates.map((date) {
                            // 【核心修改】統一日期晶片的風格
                            return ActionChip(
                              label: Text(date),
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontSize: 12,
                              ),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              onPressed: () {
                                final selectedDate = DateTime.parse(date);
                                final startTime = DateTime(selectedDate.year,
                                    selectedDate.month, selectedDate.day);
                                final endTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                ).add(const Duration(days: 1));

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryPage(
                                      plate: widget.plate,
                                      initialStartTime: startTime,
                                      initialEndTime: endTime,
                                      initialRouteId: route.id,
                                    ),
                                  ),
                                );
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            );
                          }).toList(),
                        )
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
          },
        );
      },
    );
  }
}
