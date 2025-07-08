import 'package:bus_scraper/static.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../storage/app_theme.dart';
import '../widgets/theme_provider.dart';

// 【修改】將頁面轉換為 StatefulWidget 以管理 TextEditingController
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 【新增】為駕駛員備註編輯框創建一個 Controller
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    // 初始化 Controller
    _remarksController = TextEditingController();
    // 從 LocalStorage 加載現有數據並填充到編輯框中
    _loadRemarksIntoController();
  }

  @override
  void dispose() {
    // 【重要】在頁面銷毀時，務必釋放 Controller 以避免內存洩漏
    _remarksController.dispose();
    super.dispose();
  }

  /// 從 LocalStorage 加載數據，並將其轉換為 CSV 格式的字串顯示在編輯框中
  void _loadRemarksIntoController() {
    final remarksMap = Static.localStorage.driverRemarks;
    // 將 Map 轉換為 CSV 字符串
    final csvText =
        remarksMap.entries.map((e) => '${e.key},${e.value}').join('\n');
    _remarksController.text = csvText;
  }

  /// 格式化編輯框中的文本
  void _formatTextInController() {
    final formattedText = _formatCsvString(_remarksController.text);
    _remarksController.text = formattedText;
  }

  /// 保存數據
  void _saveRemarks() {
    // 【要求】保存時自動格式化
    final formattedText = _formatCsvString(_remarksController.text);
    _remarksController.text = formattedText; // 將格式化後的文本更新回 UI

    // 將格式化的 CSV 文本解析回 Map<String, String>
    final remarksMap = _parseCsvToMap(formattedText);

    // 使用 LocalStorage 進行保存
    Static.localStorage.driverRemarks = remarksMap;

    // 顯示一個提示，告知用戶保存成功
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('駕駛員備註已保存'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          showCloseIcon: true,
        ),
      );
    }
  }

  /// 核心邏輯：將凌亂的 CSV 文本格式化
  String _formatCsvString(String rawText) {
    final lines = rawText.split('\n');
    final validEntries = <List<String>>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue; // 跳過空行

      final parts = trimmedLine.split(',');
      if (parts.length < 2) continue; // 跳過格式不正確的行

      final driverId = parts[0].trim();
      if (driverId.isEmpty) continue; // 跳過沒有駕駛員 ID 的行

      // 處理備註中可能包含逗號的情況
      final remark = parts.sublist(1).join(',').trim();
      validEntries.add([driverId, remark]);
    }

    // 按駕駛員 ID 進行排序，使格式更整潔
    validEntries.sort((a, b) => a[0].compareTo(b[0]));

    // 將處理好的條目重新組合成 CSV 字符串
    return validEntries.map((e) => '${e[0]},${e[1]}').join('\n');
  }

  /// 核心邏輯：將 CSV 文本解析為 Map
  Map<String, String> _parseCsvToMap(String csvText) {
    final remarksMap = <String, String>{};
    final lines = csvText.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final parts = trimmedLine.split(',');
      if (parts.length < 2) continue;

      final driverId = parts[0].trim();
      final remark = parts.sublist(1).join(',').trim();

      if (driverId.isNotEmpty) {
        remarksMap[driverId] = remark;
      }
    }
    return remarksMap;
  }

  @override
  Widget build(BuildContext context) {
    // Consumer 仍然用於處理主題變更，這部分邏輯不變
    return Consumer<ThemeChangeNotifier>(
      builder: (context, notifier, child) {
        final theme = Theme.of(context);

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            // 主題與色系區塊 (保持不變)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('主題與色系'),
                leading: const Icon(Icons.display_settings),
                shape: Border.all(color: Colors.transparent),
                children: [
                  SegmentedButton(
                    segments: AppTheme.values
                        .map((e) => ButtonSegment(
                            value: e, label: Text(e.uiName), icon: e.icon))
                        .toList(),
                    selected: {notifier.theme},
                    onSelectionChanged: (value) {
                      notifier.setTheme(value.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.colorize),
                    title: const Text('自訂強調色'),
                    trailing: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: theme.colorScheme.primary,
                        child: const SizedBox(width: 48, height: 48),
                      ),
                    ),
                    onTap: () {
                      _showColorPickerDialog(context, notifier);
                    },
                  )
                ],
              ),
            ),

            // 【新增】駕駛員備註編輯區塊
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('駕駛員備註'),
                leading: const Icon(Icons.edit_note),
                initiallyExpanded: false,
                // 默認不展開
                shape: Border.all(color: Colors.transparent),
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _remarksController,
                      maxLines: 10, // 允許多行輸入
                      minLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '駕駛員ID,備註',
                        hintText: '12345,備註1\n67890,備註2',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.format_align_left),
                        label: const Text('格式化'),
                        onPressed: _formatTextInController,
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('儲存'),
                        onPressed: _saveRemarks,
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            )
          ],
        );
      },
    );
  }

  // 顏色選擇對話框邏輯 (保持不變)
  void _showColorPickerDialog(
      BuildContext context, ThemeChangeNotifier notifier) {
    Color pickerColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('請選擇強調色'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  dialogSetState(() {
                    pickerColor = color;
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.setAccentColor(null);
              Navigator.of(context).pop();
            },
            child: const Text('預設'),
          ),
          TextButton(
            onPressed: () {
              notifier.setAccentColor(pickerColor);
              Navigator.of(context).pop();
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
