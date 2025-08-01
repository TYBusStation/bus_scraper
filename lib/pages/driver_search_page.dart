// lib/pages/driver_search_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/vehicle_history.dart';
import '../pages/driver_plates_page.dart';
import '../static.dart';
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
  final _displayDateFormat = DateFormat('yyyy/MM/dd');

  bool _hasSearched = false;
  Future<List<DriverDateInfo>>? _searchFuture;
  String? _promptMessage = "請選擇日期範圍後點擊查詢"; // 初始提示

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
        // 【核心修改】如果已經查詢過，則提示需要重新查詢
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
      _promptMessage = null; // 清除提示
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = Static.findDriversForVehicle(
        plate: widget.plate,
        startDate: _startDate,
        endDate: finalEndDate,
      );
    });
  }

  void _navigateToDriverPlatesPage(String driverId, String date) {
    final selectedDate = DateTime.parse(date);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverPlatesPage(
          initialDriverId: driverId,
          initialStartDate: selectedDate,
          initialEndDate: selectedDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 的駕駛查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlCard(),
            const SizedBox(height: 8),
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
              label: const Text("查詢駕駛"),
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
              subtitle: snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateIndicator(
              icon: Icons.person_off_rounded,
              title: '查無資料',
              subtitle: '在此日期區間內找不到任何駕駛記錄');
        }

        final drivers = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driverInfo = drivers[index];
            final theme = Theme.of(context);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(Icons.person_pin_rounded,
                                size: 24, color: Colors.blueGrey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Static.getDriverText(driverInfo.driverId),
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
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
                                horizontal: 8, vertical: 2),
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
