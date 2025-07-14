import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/driving_record_list.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/theme_provider.dart';

class DriverPlatesPage extends StatefulWidget {
  const DriverPlatesPage({super.key});

  @override
  State<DriverPlatesPage> createState() => _DriverPlatesPageState();
}

class _DriverPlatesPageState extends State<DriverPlatesPage> {
  final _driverIdController = TextEditingController();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  final _displayDateFormat = DateFormat('yyyy/MM/dd');

  bool _hasSearched = false;
  String _currentDriverId = '';

  // 【新增】1. 用於顯示提示訊息的狀態變數
  String? _promptMessage;

  @override
  void initState() {
    super.initState();
    // 【新增】2. 初始化頁面時設定預設的提示訊息
    _promptMessage = "請輸入駕駛員 ID 並選擇日期範圍\n然後點擊查詢按鈕\n(註：ID 前方若有 0 可能需去除)";
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
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
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
        // 【修改】3. 日期變更後，隱藏舊結果並顯示提示
        _hasSearched = false;
        _promptMessage = "日期已更新，請重新點擊「查詢」。";
      });
    }
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus();
    if (_driverIdController.text.isEmpty) {
      // 可以在此處增加一個提示，如果需要的話
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先輸入駕駛員 ID'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _hasSearched = true;
      _currentDriverId = _driverIdController.text;
      // 【修改】4. 查詢時清除提示訊息，以便顯示結果列表
      _promptMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputCard(),
            const SizedBox(height: 8),
            Expanded(
              // 【修改】5. 根據 _hasSearched 狀態決定顯示列表還是提示
              child: _hasSearched
                  ? DrivingRecordList(
                      key: ValueKey('driver_$_currentDriverId'),
                      queryType: QueryType.byDriver,
                      queryValue: _currentDriverId,
                      startDate: _startDate,
                      endDate: _endDate,
                      driverIdForListItem: _currentDriverId,
                    )
                  : _buildPromptArea(), // 顯示提示訊息的區域
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _driverIdController,
              // 【新增】6. 當文字變更時，如果已經有查詢結果，則提示使用者重新查詢
              onChanged: (value) {
                if (_hasSearched) {
                  setState(() {
                    _hasSearched = false;
                    _promptMessage = "駕駛員 ID 已變更，請重新點擊「查詢」。";
                  });
                }
              },
              decoration: const InputDecoration(
                isDense: true,
                labelText: "駕駛員 ID",
                hintText: "如：120031",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search_outlined),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDatePicker(
                    label: "結束日期",
                    value: _endDate,
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text("查詢"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final displayText = _displayDateFormat.format(value);

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
                  displayText,
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

  // 【修改】7. 將 _buildInitialMessage 更名為 _buildPromptArea 並使其動態化
  Widget _buildPromptArea() {
    // 根據是否有提示訊息決定標題
    final title = _promptMessage?.contains("更新") ?? false ? "請重新查詢" : "開始查詢";

    return EmptyStateIndicator(
      icon: Icons.person_search_outlined,
      title: title,
      // 直接使用 _promptMessage 狀態變數
      subtitle: _promptMessage ?? '',
    );
  }
}
