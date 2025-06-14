// lib/pages/driver_plates_page.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/theme_provider.dart';

class DrivingRecord {
  final Car car;
  final List<String> dates;

  DrivingRecord({required this.car, required this.dates});
}

class DriverPlatesPage extends StatefulWidget {
  const DriverPlatesPage({super.key});

  @override
  State<DriverPlatesPage> createState() => _DriverPlatesPageState();
}

class _DriverPlatesPageState extends State<DriverPlatesPage> {
  final _driverIdController = TextEditingController();

  // 【修改 1】狀態變數直接使用 DateTime，並初始化為今天的日期
  // 我們不再需要時間部分，但 DateTime 仍是處理日期的標準方式
  DateTime _startDate =
      DateTime.now().subtract(const Duration(days: 7)); // 預設查詢過去一週
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  String? _errorMessage;

  List<DrivingRecord> _foundRecords = [];

  bool _hasSearched = false;

  // 用於發送給 API 的格式
  final DateFormat _apiDateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");

  // 【修改 2】用於在 UI 上顯示日期的格式，移除了時間
  final DateFormat _displayDateFormat = DateFormat('yyyy/MM/dd');

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  // 【修改 3】簡化日期選擇邏輯，只選擇日期
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart ? _startDate : _endDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
    );

    // 移除了 showTimePicker 的部分
    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          // 如果開始日期在結束日期之後，自動調整結束日期
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          // 如果結束日期在開始日期之前，自動調整開始日期
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _fetchPlatesByDriver() async {
    FocusScope.of(context).unfocus();

    if (_driverIdController.text.isEmpty) {
      setState(() {
        _errorMessage = "請輸入駕駛員 ID。";
        _foundRecords = [];
        _hasSearched = true;
      });
      return;
    }

    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _errorMessage = "錯誤：開始日期不能晚於結束日期。";
        _foundRecords = [];
        _hasSearched = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundRecords = [];
      _hasSearched = true;
    });

    try {
      // 【修改 4】在發送 API 請求前，將日期轉換為完整的時間範圍
      // 開始時間：選定日期的 00:00:00
      final apiStartTime =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      // 結束時間：選定結束日期的隔天 00:00:00，這樣才能包含結束日期的所有時間
      final apiEndTime = DateTime(_endDate.year, _endDate.month, _endDate.day)
          .add(const Duration(days: 1));

      final queryParameters = {
        'driver_id': _driverIdController.text,
        // 使用格式化的時間範圍發送請求
        'start_time': _apiDateFormat.format(apiStartTime),
        'end_time': _apiDateFormat.format(apiEndTime),
      };

      final response = await Static.dio.get(
        '${Static.apiBaseUrl}/tools/find_driver_dates',
        queryParameters: queryParameters,
      );

      final List<dynamic> responseData = response.data;
      final carMap = {for (var car in Static.carData) car.plate: car};

      setState(() {
        _foundRecords = responseData
            .map((item) {
              final String plate = item['plate'];
              final List<String> dates = List<String>.from(item['dates'] ?? []);
              final Car? car = carMap[plate];
              if (car != null && dates.isNotEmpty) {
                return DrivingRecord(car: car, dates: dates);
              }
              return null;
            })
            .where((record) => record != null)
            .cast<DrivingRecord>()
            .toList();

        if (_foundRecords.isEmpty) {
          _errorMessage = "在此條件下找不到任何車牌紀錄。";
        }
      });
    } on DioException catch (e) {
      String message;
      if (e.response != null) {
        final errorDetail = e.response?.data['detail'] ?? '伺服器未提供詳細錯誤訊息';
        message = "錯誤 ${e.response?.statusCode}: $errorDetail";
      } else {
        message = "網路或連線錯誤，請檢查您的網路連線。";
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "發生未預期的錯誤: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) =>
          SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputCard(),
              const SizedBox(height: 24),
              _buildResultArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _driverIdController,
              decoration: const InputDecoration(
                labelText: "駕駛員 ID",
                hintText: "如：120031",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 20),
            // 【修改 5】調用新的日期選擇器 UI 元件
            _buildDatePicker(
              label: "起始日期",
              value: _startDate,
              onPressed: () => _selectDate(context, true),
            ),
            const SizedBox(height: 12),
            _buildDatePicker(
              label: "結束日期",
              value: _endDate,
              onPressed: () => _selectDate(context, false),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _fetchPlatesByDriver,
              icon: _isLoading
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search_rounded),
              label: const Text("查詢"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 【修改 6】重構日期選擇器 UI 元件，以反映其只選擇日期的功能
  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    // 使用新的日期格式
    final displayText = _displayDateFormat.format(value);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined, // 使用更符合日期的圖標
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(Icons.edit_calendar_outlined, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("正在查詢，請稍候..."),
          ],
        ),
      ));
    }

    if (_hasSearched) {
      if (_errorMessage != null) {
        return _buildInfoMessage(
          icon: Icons.error_outline_rounded,
          iconColor: theme.colorScheme.error,
          title: "查詢失敗",
          message: _errorMessage!,
        );
      }
      if (_foundRecords.isEmpty) {
        return _buildInfoMessage(
          icon: Icons.sentiment_dissatisfied_outlined,
          iconColor: theme.colorScheme.primary,
          title: "查無結果",
          message: "找不到符合條件的車輛紀錄。",
        );
      }
    } else {
      return _buildInfoMessage(
        icon: Icons.search_off_rounded,
        iconColor: theme.colorScheme.secondary,
        title: "開始查詢",
        message: "請輸入駕駛員 ID 並選擇日期範圍\n然後點擊查詢按鈕",
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(
            "查詢結果 (${_foundRecords.length} 筆)",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foundRecords.length,
          itemBuilder: (context, index) {
            final record = _foundRecords[index];
            return CarListItem(
              car: record.car,
              showLiveButton: true,
              drivingDates: record.dates,
              driverId: _driverIdController.text,
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoMessage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 64),
            const SizedBox(height: 20),
            Text(title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
