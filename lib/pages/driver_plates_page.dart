import 'package:bus_scraper/widgets/ui_utils.dart';
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

    _driverIdController.addListener(_onDriverIdChanged);

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
    _driverIdController.removeListener(_onDriverIdChanged);
    _driverIdController.dispose();
    super.dispose();
  }

  void _onDriverIdChanged() {
    if (mounted) setState(() {});
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

    final response = await Static.dio.getUri(uri);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => PlateDrivingDates.fromJson(json))
          .toList();
    }
    return [];
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    if (_driverIdController.text.isEmpty) {
      FormatterUtils.showSnackbar(context, '請先輸入駕駛長編號');
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

    final String currentId = _driverIdController.text.trim();
    final remarksMap = Static.localStorage.getRemarksForCity(Static.city);
    final String? remark = currentId.isNotEmpty ? remarksMap[currentId] : null;
    final bool hasRemark = remark != null && remark.isNotEmpty;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: hasRemark
                      ? theme.colorScheme.secondaryContainer.withOpacity(0.4)
                      : theme.colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasRemark
                        ? theme.colorScheme.secondary.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hasRemark ? Icons.sticky_note_2 : Icons.notes,
                      size: 16,
                      color: hasRemark
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentId.isEmpty
                            ? "請輸入編號以查看備註"
                            : (hasRemark ? "備註：$remark" : "暫無備註"),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hasRemark
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.outline,
                          fontWeight:
                          hasRemark ? FontWeight.w600 : FontWeight.normal,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: "起始",
                    value: _startDate,
                    onPressed: () =>
                        UiUtils.selectRangeDateTime(
                          context: context,
                          isStart: true,
                          currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                          pickTime: false,
                          maxDuration: const Duration(days: 30),
                          onDateTimeChanged: (range) =>
                              setState(() {
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
                    onPressed: () =>
                        UiUtils.selectRangeDateTime(
                          context: context,
                          isStart: false,
                          currentRange:
                          DateTimeRange(start: _startDate, end: _endDate),
                          pickTime: false,
                          maxDuration: const Duration(days: 30),
                          onDateTimeChanged: (range) =>
                              setState(() {
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

  Widget _buildDatePicker({required String label,
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
    _needsRefresh
        ? "時間已更新，請點擊查詢按鈕"
        : "輸入駕駛長編號並選擇日期範圍後\n點擊查詢按鈕";

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
        return SearchableList<PlateDrivingDates>(
          allItems: records,
          searchHintText: "搜尋車牌（支援 Regex）",
          filterCondition: (record, text) {
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
              orElse: () =>
                  Car(
                      plate: record.plate,
                      type: Type.unknown,
                      lastSeen: DateTime(0, 0, 0),
                      rawType: ''),
            );

            return CarListItem(
              car: car,
              drivingDates: record.dates,
              driverId: _driverIdController.text,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            );
          },
        );
      },
    );
  }
}
