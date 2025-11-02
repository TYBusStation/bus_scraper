import 'dart:ui';

import 'package:bus_scraper/static.dart';
import 'package:bus_scraper/storage/city.dart';
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

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
    _loadRemarksIntoController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _loadRemarksIntoController() {
    final remarksMap = Static.localStorage.getRemarksForCity(Static.city);
    final csvText =
        remarksMap.entries.map((e) => '${e.key},${e.value}').join('\n');
    _remarksController.text = csvText;
  }

  String? _formatAndDeduplicateCsvString(String rawText,
      {bool showAlert = false}) {
    final lines = rawText.split('\n');
    final Map<String, Set<String>> entries = {};
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      final parts = trimmedLine.split(',');
      if (parts.length < 2) continue;
      final driverId = parts[0].trim();
      if (driverId.isEmpty) continue;
      final remark = parts.sublist(1).join(',').trim();
      entries.putIfAbsent(driverId, () => {}).add(remark);
    }

    final duplicatesWithDifferentRemarks = entries.entries
        .where((e) => e.value.length > 1)
        .map((e) => '駕駛長編號「${e.key}」存在多個不同的備註：\n- ${e.value.join('\n- ')}')
        .toList();

    if (duplicatesWithDifferentRemarks.isNotEmpty) {
      if (showAlert && mounted) {
        _showDuplicateWarningDialog(duplicatesWithDifferentRemarks);
      }
      return null;
    }

    final uniqueEntries = entries.entries.map((e) {
      return [e.key, e.value.first];
    }).toList();

    uniqueEntries.sort((a, b) => a[0].compareTo(b[0]));
    return uniqueEntries.map((e) => '${e[0]},${e[1]}').join('\n');
  }

  void _formatTextInController() {
    final formattedText = _formatAndDeduplicateCsvString(
        _remarksController.text,
        showAlert: true);
    if (formattedText != null) {
      _remarksController.text = formattedText;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('駕駛長備註已格式化'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _saveRemarks() {
    final formattedText = _formatAndDeduplicateCsvString(
        _remarksController.text,
        showAlert: true);

    if (formattedText == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('儲存失敗：請先解決有衝突的重複備註。'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _remarksController.text = formattedText;
    final remarksMap = _parseCsvToMap(formattedText);
    Static.localStorage.setRemarksForCity(Static.city, remarksMap);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('駕駛長備註已保存'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  void _showDuplicateWarningDialog(List<String> issues) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('發現重複備註'),
            ],
          ),
          content: SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: ListBody(
                children: [
                  const Text('以下駕駛長編號擁有多個不同的備註，請手動修正後再儲存：'),
                  const SizedBox(height: 12),
                  ...issues
                      .map((issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(issue,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  void _showForceRestartDialog(City newCity) {
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
                  Text('城市已切換為「${newCity.name}」。'),
                  const SizedBox(height: 16),
                  const Text(
                    '為確保所有資料正確載入，請重新整理網頁或重新開啟程式。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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
        return ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            ExpansionTile(
              title: const Text('主題與色系'),
              subtitle: Text('當前：${notifier.theme.uiName}'),
              leading: const Icon(Icons.display_settings),
              shape: Border.all(color: Colors.transparent),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                SegmentedButton<AppTheme>(
                  segments: AppTheme.values
                      .map((e) => ButtonSegment(
                          value: e, label: Text(e.uiName), icon: e.icon))
                      .toList(),
                  selected: {notifier.theme},
                  onSelectionChanged: (value) => notifier.setTheme(value.first),
                ),
                ListTile(
                  leading: const Icon(Icons.colorize),
                  title: const Text('自訂強調色'),
                  trailing: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: theme.colorScheme.primary,
                      child: const SizedBox(width: 40, height: 40),
                    ),
                  ),
                  onTap: () => _showColorPickerDialog(context, notifier),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('動態軌跡時間'),
              subtitle:
                  Text('顯示過去 ${Static.localStorage.liveTrackDuration} 分鐘的軌跡'),
              leading: const Icon(Icons.timeline),
              shape: Border.all(color: Colors.transparent),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: Static.localStorage.liveTrackDuration.toDouble(),
                        min: 3,
                        max: 30,
                        divisions: 27,
                        label: '${Static.localStorage.liveTrackDuration} 分鐘',
                        onChanged: (double value) {
                          setState(() {
                            Static.localStorage.liveTrackDuration =
                                value.round();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${Static.localStorage.liveTrackDuration} 分鐘',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('當前城市'),
              subtitle: Text(Static.city.name),
              leading: const Icon(Icons.location_city),
              shape: Border.all(color: Colors.transparent),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                SegmentedButton<City>(
                  segments: City.values.map((city) {
                    return ButtonSegment<City>(
                      value: city,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: city.icon,
                          ),
                          const SizedBox(width: 8),
                          Text(city.name),
                        ],
                      ),
                    );
                  }).toList(),
                  selected: {Static.city},
                  onSelectionChanged: (Set<City> newSelection) {
                    final newValue = newSelection.first;
                    if (newValue != Static.city) {
                      setState(() {
                        Static.localStorage.city = newValue;
                      });
                      _showForceRestartDialog(newValue);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
            ExpansionTile(
              title: const Text('駕駛長備註'),
              subtitle: Text('編輯 ${Static.city.name} 的備註'),
              leading: const Icon(Icons.edit_note),
              initiallyExpanded: false,
              shape: Border.all(color: Colors.transparent),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: _remarksController,
                  maxLines: 10,
                  minLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '駕駛長編號,備註',
                    hintText: '12345,備註1\n67890,備註2',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      child: const Text('格式化'),
                      onPressed: _formatTextInController,
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      child: const Text('儲存'),
                      onPressed: _saveRemarks,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
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
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
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
          FilledButton(
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
