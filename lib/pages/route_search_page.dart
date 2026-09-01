import 'package:bus_scraper/pages/route_timetable_page.dart';
import 'package:bus_scraper/utils/api_utils.dart';
import 'package:bus_scraper/widgets/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_route.dart';
import '../data/vehicle_history.dart';
import '../pages/route_vehicles_page.dart';
import '../storage/city.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';
import 'history_page.dart';

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

  bool _hasSearched = false;
  bool _needsRefresh = false;
  Future<List<BusRouteWithHistory>>? _searchFuture;

  static Future<List<VehicleRouteHistory>> findVehicleRoutes({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/tools/find_vehicle_routes/$plate")
        .replace(queryParameters: {
      if (startDate != null)
        'start_time': FormatterUtils.apiTimeFormat.format(startDate),
      if (endDate != null)
        'end_time': FormatterUtils.apiTimeFormat.format(endDate),
    });

    final response = await Static.dio.getUri(uri);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => VehicleRouteHistory.fromJson(json))
          .toList();
    }
    return [];
  }

  Future<List<BusRouteWithHistory>> _fetchAndProcessRoutes(
      DateTime startDate, DateTime endDate) async {
    final histories = await findVehicleRoutes(
      plate: widget.plate,
      startDate: startDate,
      endDate: endDate,
    );

    if (histories.isEmpty) {
      return [];
    }

    final processedRoutes = await Future.wait(histories.map((history) async {
      final routeDetails = await ApiUtils.getRouteById(history.routeId);
      return BusRouteWithHistory(route: routeDetails, history: history);
    }));

    return processedRoutes;
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _needsRefresh = false;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = _fetchAndProcessRoutes(_startDate, finalEndDate);
    });
  }

  void _onDynamicWebsitePressed(BuildContext context, BusRoute route) async {
    if (Static.city == City.taipei) {
      final nid = route.nid;
      final pnid = route.pnid;

      final bool hasNid = nid != null && nid.isNotEmpty;
      final bool hasPnid = pnid != null && pnid.isNotEmpty;
      final bool areDifferent = hasNid && hasPnid && nid != pnid;

      if (areDifferent) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('選擇要開啟的路線網頁'),
            content: const Text('選擇開啟子路線或主路線網頁'),
            actions: [
              TextButton(
                child: Text("子路線 ($nid)"),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _launchTaipeiUrl(nid);
                },
              ),
              TextButton(
                child: Text('主路線 ($pnid)'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _launchTaipeiUrl(pnid);
                },
              ),
            ],
          ),
        );
      } else if (hasNid) {
        _launchTaipeiUrl(nid);
      } else if (hasPnid) {
        _launchTaipeiUrl(pnid);
      }
    } else {
      final url = Uri.parse(Static.city != City.taichung
          ? "${Static.city.url}/ebus/driving-map/${route.id}"
          : "https://tybusstation.github.io/taichung_bus/");
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  void _launchTaipeiUrl(String routeId) async {
    final url = Uri.parse(
        'https://ebus.gov.taipei/Route/StopsOfRoute?routeid=$routeId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 路線查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: "起始",
                    value: _startDate,
                    onPressed: () => UiUtils.selectRangeDateTime(
                      context: context,
                      isStart: true,
                      currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                      pickTime: false,
                      maxDuration: const Duration(days: 30),
                      onDateTimeChanged: (range) => setState(() {
                        _startDate = range.start;
                        _endDate = range.end;
                        _needsRefresh = true;
                        _hasSearched = false;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDatePicker(
                    label: "結束",
                    value: _endDate,
                    onPressed: () => UiUtils.selectRangeDateTime(
                      context: context,
                      isStart: false,
                      currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                      pickTime: false,
                      maxDuration: const Duration(days: 30),
                      onDateTimeChanged: (range) => setState(() {
                        _startDate = range.start;
                        _endDate = range.end;
                        _needsRefresh = true;
                        _hasSearched = false;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text("查詢路線"),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40)),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  FormatterUtils.displayDateFormat.format(value),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_month_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptArea() {
    final title = _needsRefresh ? "請重新查詢" : "開始查詢";
    final subtitle = _needsRefresh ? "時間已更新，請點擊查詢。" : "請選擇日期範圍後點擊查詢";

    return EmptyStateIndicator(
      icon: Icons.search_rounded,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildResultsList() {
    return FutureBuilder<List<BusRouteWithHistory>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateIndicator(
              icon: Icons.error_outline_rounded,
              title: "查詢失敗",
              subtitle: FormatterUtils.getErrorMessage(snapshot.error));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateIndicator(
            icon: Icons.sentiment_dissatisfied_outlined,
            title: "查無結果",
            subtitle: "找不到符合條件的路線紀錄。",
          );
        }

        final List<BusRouteWithHistory> allItems = snapshot.data!;

        return SearchableList<BusRouteWithHistory>(
          allItems: allItems,
          searchHintText: "搜尋路線、描述或編號 (支援 Regex)",
          filterCondition: (item, text) {
            final r = item.route;
            final content =
                '${r.id} ${r.name} ${r.description} ${r.departure} ${r.destination}';

            final tokens =
                text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
            return tokens.every((token) {
              try {
                return RegExp(token, caseSensitive: false).hasMatch(content);
              } catch (_) {
                return content.toUpperCase().contains(token.toUpperCase());
              }
            });
          },
          sortCallback: (a, b) =>
              FormatterUtils.compareRoutes(a.route.name, b.route.name),
          itemBuilder: (context, item) {
            final BusRoute route = item.route;
            final VehicleRouteHistory routeInfo = item.history;
            final theme = Theme.of(context);
            final textTheme = theme.textTheme;
            final colorScheme = theme.colorScheme;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
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
                            child: Text(route.departure,
                                style: textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold))),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.0),
                            child: Icon(Icons.arrow_forward, size: 16)),
                        const Icon(Icons.flag, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(route.destination,
                                style: textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text('編號：${route.id}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _onDynamicWebsitePressed(context, route),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('公車動態網'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            textStyle: theme.textTheme.labelMedium,
                          ),
                        ),
                        if (Static.city == City.taichung) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      RouteTimetablePage(route: route),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_outlined,
                                size: 16),
                            label: const Text('時刻表'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      RouteVehiclesPage(route: route))),
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
                    const SizedBox(height: 8),
                    Divider(
                        height: 1, color: theme.dividerColor.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: routeInfo.dates.map((date) {
                        return ActionChip(
                          label: Text(date),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 12,
                          ),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          onPressed: () {
                            final selectedDate = DateTime.parse(date);
                            final startTime = DateTime(selectedDate.year,
                                selectedDate.month, selectedDate.day);
                            final endTime =
                                startTime.add(const Duration(days: 1));

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
                              horizontal: 6, vertical: 0),
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
  }
}
