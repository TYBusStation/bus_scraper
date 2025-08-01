// lib/pages/driver_plates_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/vehicle_history.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart'; // 【核心修改】導入 SearchableList

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
  final _displayDateFormat = DateFormat('yyyy/MM/dd');

  bool _hasSearched = false;
  Future<List<PlateDrivingDates>>? _searchFuture;
  String? _promptMessage;

  @override
  void initState() {
    super.initState();
    _driverIdController =
        TextEditingController(text: widget.initialDriverId ?? '');
    _startDate = widget.initialStartDate ??
        DateTime.now().subtract(const Duration(days: 7));
    _endDate = widget.initialEndDate ?? DateTime.now();

    _promptMessage = "輸入駕駛員 ID 並選擇日期範圍後\n點擊查詢按鈕";
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

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
    if (_driverIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入駕駛員 ID')),
      );
      return;
    }
    setState(() {
      _hasSearched = true;
      _promptMessage = null;
      final finalEndDate =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      _searchFuture = Static.findDriverDrivingDates(
        driverId: _driverIdController.text,
        startDate: _startDate,
        endDate: finalEndDate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputCard(),
          const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            TextField(
              controller: _driverIdController,
              readOnly: isReadOnly,
              decoration: InputDecoration(
                isDense: true,
                labelText: "駕駛員 ID",
                hintText: "如：120031",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_search_outlined),
                filled: isReadOnly,
                fillColor: isReadOnly
                    ? theme.colorScheme.surfaceVariant.withOpacity(0.3)
                    : null,
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
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
              label: const Text("查詢駕駛車輛"),
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
      icon: Icons.person_search_outlined,
      title: title,
      subtitle: _promptMessage ?? '',
    );
  }

  // 【核心修改】使用 SearchableList 來顯示結果
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
        // 將結果列表包裹在 SearchableList 中
        return SearchableList<PlateDrivingDates>(
          allItems: records,
          searchHintText: "搜尋車牌（如：KKA-3822）",
          // 過濾條件：檢查輸入的文字是否存在於車牌號碼中
          filterCondition: (record, text) {
            return record.plate.toUpperCase().contains(text.toUpperCase());
          },
          // 排序回呼：可以按車牌號碼排序
          sortCallback: (a, b) => a.plate.compareTo(b.plate),
          // 每個項目的建立器
          itemBuilder: (context, record) {
            final car = Static.carData.firstWhere(
              (c) => c.plate == record.plate,
            );

            return CarListItem(
              car: car,
              showLiveButton: true,
              drivingDates: record.dates,
              driverId: _driverIdController.text,
              // 移除預設的水平邊距，使其與 SearchableList 的邊距一致
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            );
          },
          // 搜尋無結果時的提示
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
