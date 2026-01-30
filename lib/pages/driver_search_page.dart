import 'package:bus_scraper/widgets/ui_utils.dart';
import 'package:flutter/material.dart';

import '../data/vehicle_history.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/empty_state_indicator.dart';
import 'history_page.dart';

class DriverSearchPage extends StatefulWidget {
  final String plate;

  const DriverSearchPage({super.key, required this.plate});

  @override
  State<DriverSearchPage> createState() => _DriverSearchPageState();
}

class _DriverSearchPageState extends State<DriverSearchPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  bool _hasSearched = false;
  bool _needsRefresh = false;
  Future<List<DriverDateInfo>>? _searchFuture;

  static Future<List<DriverDateInfo>> findDriversForVehicle({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/tools/find_vehicle_drivers/$plate")
        .replace(
      queryParameters: {
        if (startDate != null)
          'start_time': FormatterUtils.apiTimeFormat.format(startDate),
        if (endDate != null)
          'end_time': FormatterUtils.apiTimeFormat.format(endDate),
      },
    );

    final response = await Static.dio.getUri(uri);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => DriverDateInfo.fromJson(json))
          .toList();
    }
    return [];
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _hasSearched = true;
      _needsRefresh = false;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = findDriversForVehicle(
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
        title: Text('${widget.plate} 駕駛長查詢'),
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
              label: const Text("查詢駕駛長"),
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
    return FutureBuilder<List<DriverDateInfo>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateIndicator(
              icon: Icons.error_outline_rounded,
              title: '查詢失敗',
              subtitle: FormatterUtils.getErrorMessage(snapshot.error));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateIndicator(
            icon: Icons.sentiment_dissatisfied_outlined,
            title: "查無結果",
            subtitle: "找不到符合條件的駕駛紀錄。",
          );
        }

        final drivers = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driverInfo = drivers[index];
            final theme = Theme.of(context);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_pin_rounded,
                              size: 22, color: Colors.blueGrey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              FormatterUtils.getDriverText(driverInfo.driverId),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.5)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: driverInfo.dates.map((date) {
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
                                    initialDriverId: driverInfo.driverId,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
