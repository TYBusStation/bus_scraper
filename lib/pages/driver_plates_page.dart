// lib/pages/driver_plates_page.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/theme_provider.dart';

// 移除了 ThemeProvider，因為頁面本身不應該負責提供主題。
// 主題應該由 App 的頂層（如 MaterialApp）提供。

class DriverPlatesPage extends StatefulWidget {
  const DriverPlatesPage({super.key});

  @override
  State<DriverPlatesPage> createState() => _DriverPlatesPageState();
}

class _DriverPlatesPageState extends State<DriverPlatesPage> {
  final _driverIdController = TextEditingController();

  // --- 【修改點 2】設定初始時間 ---
  // 預設查詢過去 24 小時的範圍
  DateTime _startTime = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endTime = DateTime.now();

  bool _isLoading = false;
  String? _errorMessage;
  List<Car> _foundCars = [];

  // 狀態變數，用於控制初始提示的顯示
  bool _hasSearched = false;

  final DateFormat _apiDateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  final DateFormat _displayDateFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _driverIdController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    final DateTime initialDate = isStart ? _startTime : _endTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: isStart ? '選擇開始時間' : '選擇結束時間',
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startTime = newDateTime;
            if (_startTime.isAfter(_endTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            _endTime = newDateTime;
            if (_endTime.isBefore(_startTime)) {
              _startTime = _endTime.subtract(const Duration(hours: 1));
            }
          }
        });
      }
    }
  }

  Future<void> _fetchPlatesByDriver() async {
    // 點擊查詢時，收起鍵盤，提升體驗
    FocusScope.of(context).unfocus();

    if (_driverIdController.text.isEmpty) {
      setState(() {
        _errorMessage = "請輸入駕駛員 ID。";
        _foundCars = [];
        _hasSearched = true;
      });
      return;
    }

    if (_startTime.isAfter(_endTime)) {
      setState(() {
        _errorMessage = "錯誤：開始時間不能晚於結束時間。";
        _foundCars = [];
        _hasSearched = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundCars = [];
      _hasSearched = true;
    });

    try {
      final queryParameters = {
        'driver_id': _driverIdController.text,
        'start_time': _apiDateFormat.format(_startTime),
        'end_time': _apiDateFormat.format(_endTime),
      };

      // 注意: Dio 的 baseUrl 已經在 Static.dio 中設定，這裡只需要路徑
      final response = await Static.dio.get(
        '${Static.apiBaseUrl}/tools/find_plates_by_driver',
        // 移除了 Static.apiBaseUrl
        queryParameters: queryParameters,
      );

      final List<dynamic> platesData = response.data;

      setState(() {
        // --- 【修改點 1】效能優化 ---
        // 使用預先處理好的 Map 來查找，更高效
        _foundCars = platesData
            .cast<String>()
            .map((plate) =>
                Static.carData.firstWhere((car) => car.plate == plate))
            .whereType<Car>() // 過濾 null 並轉換類型
            .toList();

        if (_foundCars.isEmpty) {
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
    // 直接使用 Scaffold，而不是 SingleChildScrollView
    // 這樣可以有一個固定的 AppBar，並讓內容區滾動
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) =>
          SingleChildScrollView(
        // 在這裡使用 SingleChildScrollView
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

  // --- 【修改點 3】美化後的 UI 元件 ---

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      // 使用更現代的 Card 邊框
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
                hintText: "例如: 120031",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 20),
            _buildDateTimePicker(
              label: "起始時間",
              value: _startTime,
              onPressed: () => _selectDateTime(context, true),
            ),
            const SizedBox(height: 12),
            _buildDateTimePicker(
              label: "結束時間",
              value: _endTime,
              onPressed: () => _selectDateTime(context, false),
            ),
            const SizedBox(height: 24),
            // 美化查詢按鈕
            FilledButton.icon(
              onPressed: _isLoading ? null : _fetchPlatesByDriver,
              icon: _isLoading
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildDateTimePicker({
    required String label,
    required DateTime value, // 改為非 nullable，因為已有初始值
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final displayText = _displayDateFormat.format(value);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // 使用次級容器顏色作為背景，使其與 Card 背景區分
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  label == "起始時間"
                      ? Icons.schedule_outlined
                      : Icons.update_outlined,
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

    // 只有在查詢後才顯示錯誤或空狀態
    if (_hasSearched) {
      if (_errorMessage != null) {
        return _buildInfoMessage(
          icon: Icons.error_outline_rounded,
          iconColor: theme.colorScheme.error,
          title: "查詢失敗",
          message: _errorMessage!,
        );
      }
      if (_foundCars.isEmpty) {
        return _buildInfoMessage(
          icon: Icons.sentiment_dissatisfied_outlined,
          iconColor: theme.colorScheme.primary,
          title: "查無結果",
          message: "找不到符合條件的車輛紀錄。",
        );
      }
    } else {
      // 首次進入頁面的提示
      return _buildInfoMessage(
        icon: Icons.search_off_rounded,
        iconColor: theme.colorScheme.secondary,
        title: "開始查詢",
        message: "請輸入駕駛員 ID 並選擇時間範圍，然後點擊查詢按鈕。",
      );
    }

    // 成功找到結果的列表
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(
            "查詢結果 (${_foundCars.length} 筆)",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _foundCars.length,
          itemBuilder: (context, index) {
            final car = _foundCars[index];
            return CarListItem(
              car: car,
              showLiveButton: true,
            );
          },
        ),
      ],
    );
  }

  // 統一的資訊提示 Widget
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
