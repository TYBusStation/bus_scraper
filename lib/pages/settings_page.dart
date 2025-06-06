import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart'; // *** 新增：導入 provider 套件 ***

import '../storage/app_theme.dart';
import '../widgets/theme_provider.dart'; // 這裡的 ThemeProvider 僅用於獲取 of() 方法和類型

class SettingsPage extends StatelessWidget {
  // *** 修改：改為 StatelessWidget，因為我們不再需要管理本地狀態 ***
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // *** 核心修改：使用 Consumer 來監聽全局 ThemeChangeNotifier 的變化 ***
    // Consumer 會在 notifier.notifyListeners() 被調用時自動重繪其 builder 內的內容。
    return Consumer<ThemeChangeNotifier>(
      builder: (context, notifier, child) {
        // 獲取當前的主題，用於顯示顏色等
        final theme = Theme.of(context);

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('主題與色系'),
                initiallyExpanded: true,
                leading: const Icon(Icons.display_settings),
                shape: Border.all(color: Colors.transparent),
                children: [
                  SegmentedButton(
                      segments: AppTheme.values
                          .map((e) => ButtonSegment(
                              value: e, label: Text(e.uiName), icon: e.icon))
                          .toList(),
                      // 從 notifier 直接讀取當前主題，確保 UI 同步
                      selected: {notifier.theme},
                      onSelectionChanged: (value) {
                        final theme = value.first;
                        // 直接呼叫 notifier 的方法來更新全局主題，不需要 setState
                        notifier.setTheme(theme);
                      }),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.colorize),
                    title: const Text('自訂強調色'),
                    trailing: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        // 直接使用來自主題的強調色，確保顏色總是正確的
                        color: theme.colorScheme.primary,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                    onTap: () {
                      _showColorPickerDialog(context, notifier);
                    },
                  )
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 將對話框邏輯提取為一個獨立的方法，使 build 方法更乾淨
  void _showColorPickerDialog(
      BuildContext context, ThemeChangeNotifier notifier) {
    // 臨時變數，用於在對話框中追蹤用戶選擇的顏色
    Color pickerColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('請選擇強調色'),
        content: SingleChildScrollView(
          // *** 使用 StatefulBuilder 來管理對話框內部的狀態 ***
          // 這讓我們可以在不重繪整個頁面的情況下，即時更新顏色選擇器的預覽
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  // 使用 dialogSetState 來僅僅重繪對話框的內容
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
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 呼叫 notifier 來設定為預設顏色
              notifier.setAccentColor(null);
              Navigator.of(context).pop();
            },
            child: const Text('預設'),
          ),
          TextButton(
            onPressed: () {
              // 呼叫 notifier 來設定用戶選擇的新顏色
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
