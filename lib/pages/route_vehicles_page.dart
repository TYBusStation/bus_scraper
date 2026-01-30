import 'package:bus_scraper/utils/api_utils.dart';
import 'package:bus_scraper/widgets/ui_utils.dart';
import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../data/car.dart';
import '../data/vehicle_history.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class RouteVehiclesPage extends StatefulWidget {
  final BusRoute route;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const RouteVehiclesPage({
    super.key,
    required this.route,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<RouteVehiclesPage> createState() => _RouteVehiclesPageState();
}

class _RouteVehiclesPageState extends State<RouteVehiclesPage> {
  late DateTime _startDate;
  late DateTime _endDate;

  bool _hasSearched = false;
  bool _needsRefresh = false;
  Future<List<VehicleDrivingDates>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ??
        DateTime.now().subtract(const Duration(days: 7));
    _endDate = widget.initialEndDate ?? DateTime.now();

    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerSearch();
      });
    }
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _needsRefresh = false;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = ApiUtils.findVehiclesOnRoute(
        routeId: widget.route.id,
        startDate: _startDate,
        endDate: finalEndDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.route.name} 行駛車輛查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlCard(),
            const SizedBox(height: 4),
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
                      maxDuration: const Duration(days: 14),
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
                      maxDuration: const Duration(days: 14),
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
              label: const Text("查詢車輛"),
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
    final displayText = FormatterUtils.displayDateFormat.format(value);

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
                  displayText,
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
    final subtitle = _needsRefresh ? "時間已更新，請點擊查詢。" : "請選擇日期範圍後\n點擊查詢按鈕";

    return EmptyStateIndicator(
      icon: Icons.directions_bus_filled_outlined,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildResultsList() {
    return FutureBuilder<List<VehicleDrivingDates>>(
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
            subtitle: "找不到符合條件的車輛紀錄。",
          );
        }

        final records = snapshot.data!;
        return SearchableList<VehicleDrivingDates>(
          allItems: records,
          searchHintText: "搜尋車牌 (支援 Regex)",
          filterCondition: (record, text) {
            // 目標：record.plate (String)
            final tokens =
                text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
            return tokens.every((token) {
              try {
                return RegExp(token, caseSensitive: false)
                    .hasMatch(record.plate);
              } catch (_) {
                return record.plate.toUpperCase().contains(token.toUpperCase());
              }
            });
          },
          sortCallback: (a, b) => a.plate.compareTo(b.plate),
          emptyStateWidget: const EmptyStateIndicator(
            icon: Icons.search_off,
            title: "找不到符合的車輛",
            subtitle: "請嘗試更改搜尋關鍵字",
          ),
          itemBuilder: (context, record) {
            final car = Static.carData.firstWhere(
              (c) => c.plate == record.plate,
              orElse: () => Car(
                  plate: record.plate,
                  type: Type.unknown,
                  lastSeen: DateTime(0, 0, 0),
                  rawType: ''),
            );
            return CarListItem(
              car: car,
              drivingDates: record.dates,
              routeId: widget.route.id,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            );
          },
        );
      },
    );
  }
}
