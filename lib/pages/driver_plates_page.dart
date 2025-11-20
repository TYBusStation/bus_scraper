import 'package:bus_scraper/widgets/ui_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/car.dart';
import '../data/vehicle_history.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class DriverPlatesPage extends StatefulWidget {
  final String? initialDriverId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const DriverPlatesPage({
    super.key,
    this.initialDriverId,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<DriverPlatesPage> createState() => _DriverPlatesPageState();
}

class _DriverPlatesPageState extends State<DriverPlatesPage> {
  late TextEditingController _driverIdController;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _hasSearched = false;

  bool _needsRefresh = false;
  Future<List<PlateDrivingDates>>? _searchFuture;

  @override
  void initState() {
    super.initState();
    _driverIdController =
        TextEditingController(text: widget.initialDriverId ?? '');
    _startDate = widget.initialStartDate ??
        DateTime.now().subtract(const Duration(days: 7));
    _endDate = widget.initialEndDate ?? DateTime.now();

    if (widget.initialDriverId != null &&
        widget.initialStartDate != null &&
        widget.initialEndDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerSearch();
      });
    }
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  static Future<List<PlateDrivingDates>> findDriverDrivingDates({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/tools/find_driver_dates")
        .replace(
      queryParameters: {
        'driver_id': driverId,
        if (startDate != null)
          'start_time': FormatterUtils.apiTimeFormat.format(startDate),
        if (endDate != null)
          'end_time': FormatterUtils.apiTimeFormat.format(endDate),
      },
    );
    Static.log("Fetching plates for driver $driverId from API: $uri");
    try {
      final response = await Static.dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => PlateDrivingDates.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      Static.log("DioError fetching plates for driver $driverId: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching plates for driver $driverId: $e");
    }
    return [];
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    if (_driverIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入駕駛長編號')),
      );
      return;
    }
    setState(() {
      _hasSearched = true;
      _needsRefresh = false;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = findDriverDrivingDates(
        driverId: _driverIdController.text,
        startDate: _startDate,
        endDate: finalEndDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputCard(),
          const SizedBox(height: 4),
          Expanded(
            child: _hasSearched ? _buildResultsList() : _buildPromptArea(),
          ),
        ],
      ),
    );

    if (widget.initialDriverId != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.initialDriverId} 的駕駛車輛')),
        body: body,
      );
    } else {
      return body;
    }
  }

  Widget _buildInputCard() {
    final isReadOnly = widget.initialDriverId != null;
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            TextField(
              controller: _driverIdController,
              readOnly: isReadOnly,
              decoration: InputDecoration(
                isDense: true,
                labelText: "駕駛長編號（如：${Static.city.exDriver}）",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_search_outlined),
                filled: isReadOnly,
                fillColor: isReadOnly
                    ? theme.colorScheme.surfaceVariant.withOpacity(0.3)
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: "起始",
                    value: _startDate,
                    onPressed: () => UiUtils.selectDateTime(
                      context: context,
                      isStart: true,
                      currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                      lastSelectableDate:
                          DateTime.now().add(const Duration(days: 1)),
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
                    onPressed: () => UiUtils.selectDateTime(
                      context: context,
                      isStart: false,
                      currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                      lastSelectableDate:
                          DateTime.now().add(const Duration(days: 1)),
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
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text("查詢駕駛車輛"),
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
    final subtitle =
        _needsRefresh ? "時間已更新，請點擊查詢按鈕" : "輸入駕駛長編號並選擇日期範圍後\n點擊查詢按鈕";

    return EmptyStateIndicator(
      icon: Icons.person_search_outlined,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildResultsList() {
    return FutureBuilder<List<PlateDrivingDates>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateIndicator(
              icon: Icons.error_outline_rounded,
              title: "查詢失敗",
              subtitle: snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateIndicator(
              icon: Icons.no_transfer_rounded,
              title: "查無資料",
              subtitle: "找不到該駕駛在此期間的任何駕駛記錄");
        }

        final records = snapshot.data!;
        return SearchableList<PlateDrivingDates>(
          allItems: records,
          searchHintText: "搜尋車牌（如：${Static.city.exPlate}）",
          filterCondition: (record, text) {
            return record.plate.toUpperCase().contains(text.toUpperCase());
          },
          sortCallback: (a, b) => a.plate.compareTo(b.plate),
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
              showLiveButton: true,
              drivingDates: record.dates,
              driverId: _driverIdController.text,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            );
          },
          emptyStateWidget: const EmptyStateIndicator(
            icon: Icons.search_off,
            title: "找不到符合的車輛",
            subtitle: "請嘗試更改搜尋關鍵字",
          ),
        );
      },
    );
  }
}
