// settings_page.dart

import 'dart:ui'; // 用於 BackdropFilter

import 'package:bus_scraper/static.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../storage/app_theme.dart';
import '../widgets/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _remarksController;
  late String _currentCityForRemarks;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
    _currentCityForRemarks = Static.localStorage.city;
    _loadRemarksIntoController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _loadRemarksIntoController() {
    final remarksMap =
        Static.localStorage.getRemarksForCity(_currentCityForRemarks);
    final csvText =
        remarksMap.entries.map((e) => '${e.key},${e.value}').join('\n');
    _remarksController.text = csvText;
  }

  void _formatTextInController() {
    final formattedText = _formatCsvString(_remarksController.text);
    _remarksController.text = formattedText;
  }

  void _saveRemarks() {
    final formattedText = _formatCsvString(_remarksController.text);
    _remarksController.text = formattedText;
    final remarksMap = _parseCsvToMap(formattedText);
    Static.localStorage.setRemarksForCity(_currentCityForRemarks, remarksMap);

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

  String _formatCsvString(String rawText) {
    final lines = rawText.split('\n');
    final validEntries = <List<String>>[];
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      final parts = trimmedLine.split(',');
      if (parts.length < 2) continue;
      final driverId = parts[0].trim();
      if (driverId.isEmpty) continue;
      final remark = parts.sublist(1).join(',').trim();
      validEntries.add([driverId, remark]);
    }
    validEntries.sort((a, b) => a[0].compareTo(b[0]));
    return validEntries.map((e) => '${e[0]},${e[1]}').join('\n');
  }

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

  void _showForceRestartDialog(String newCityName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('需要重新啟動'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('城市已切換為「$newCityName」。'),
                  const SizedBox(height: 16),
                  const Text(
                    '為確保所有資料正確載入，請重新整理網頁。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: const [],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeChangeNotifier>(
      builder: (context, notifier, child) {
        final theme = Theme.of(context);
        // 獲取當前城市名稱用於顯示
        final currentCityName = Static.availableCities
            .firstWhere((c) => c.code == _currentCityForRemarks,
                orElse: () => Static.availableCities.first)
            .name;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            // 主題與色系區塊
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('主題與色系'),
                subtitle: Text('當前設定：${notifier.theme.uiName}'),
                leading: const Icon(Icons.display_settings),
                shape: Border.all(color: Colors.transparent),
                children: [
                  const SizedBox(height: 12),
                  SegmentedButton<AppTheme>(
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
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 城市選擇區塊
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('當前城市'),
                subtitle: Text(currentCityName),
                // 顯示當前選擇的城市名稱
                leading: const Icon(Icons.location_city),
                shape: Border.all(color: Colors.transparent),
                children: [
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: Static.availableCities.map((city) {
                      return ButtonSegment<String>(
                        value: city.code,
                        label: Text(city.name),
                      );
                    }).toList(),
                    selected: {_currentCityForRemarks},
                    onSelectionChanged: (Set<String> newSelection) {
                      final newValue = newSelection.first;
                      if (newValue != _currentCityForRemarks) {
                        setState(() {
                          Static.localStorage.city = newValue;
                          _currentCityForRemarks = newValue;
                        });

                        final newCityName = Static.availableCities
                            .firstWhere((c) => c.code == newValue)
                            .name;
                        _showForceRestartDialog(newCityName);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 駕駛員備註區塊
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: const Text('駕駛員備註'),
                subtitle: Text('正在編輯 $currentCityName 的備註'),
                // 標題顯示當前城市
                leading: const Icon(Icons.edit_note),
                initiallyExpanded: false,
                shape: Border.all(color: Colors.transparent),
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _remarksController,
                      maxLines: 10,
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
