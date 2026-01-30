import 'dart:convert';

import 'package:bus_scraper/utils/api_utils.dart';
import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:bus_scraper/widgets/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../utils/static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/favorite_provider.dart';
import 'multi_history_osm_page.dart';
import 'multi_live_osm_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  // --- 效能與安全性檢查 ---

  /// 當車輛數超過 20 台時，顯示效能警告對話框
  Future<bool> _confirmPerformance(BuildContext context, int count) async {
    if (count <= 20) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text("效能提醒"),
              ],
            ),
            content: Text("該群組共有 $count 台車輛，在地圖上同時載入大量資料可能會導致操作卡頓甚至閃退。是否繼續？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("繼續"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- 群組歷史軌跡時間選擇對話框 ---

  Future<void> _showGroupHistoryTimeDialog(
      BuildContext context, String title, List<String> plates) async {
    // 效能檢查
    if (!(await _confirmPerformance(context, plates.length))) return;
    if (!context.mounted) return;

    DateTime now = DateTime.now();
    DateTime startTime = now.subtract(const Duration(hours: 1));
    DateTime endTime = now;

    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('$title 歷史軌跡'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTimeBox(context, "開始時間", startTime, () async {
                      await UiUtils.selectRangeDateTime(
                        context: context,
                        isStart: true,
                        currentRange:
                            DateTimeRange(start: startTime, end: endTime),
                        pickTime: true,
                        maxDuration: const Duration(days: 2),
                        onDateTimeChanged: (range) => setState(() {
                          startTime = range.start;
                          endTime = range.end;
                        }),
                      );
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child:
                        Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ),
                  Expanded(
                    child: _buildTimeBox(context, "結束時間", endTime, () async {
                      await UiUtils.selectRangeDateTime(
                        context: context,
                        isStart: false,
                        currentRange:
                            DateTimeRange(start: startTime, end: endTime),
                        pickTime: true,
                        maxDuration: const Duration(days: 2),
                        onDateTimeChanged: (range) => setState(() {
                          startTime = range.start;
                          endTime = range.end;
                        }),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消")),
            FilledButton(
              onPressed: () => Navigator.pop(
                  context, DateTimeRange(start: startTime, end: endTime)),
              child: const Text("查詢"),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      _showTrack(context, title, plates, result.start, result.end);
    }
  }

  Widget _buildTimeBox(
      BuildContext context, String label, DateTime time, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              FormatterUtils.displayTimeFormatNoSec.format(time),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 組件 ---

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        return Column(
          children: [
            _buildTopBar(context, notifier),
            const Divider(),
            Expanded(
              child: notifier.data.isEmpty
                  ? const EmptyStateIndicator(
                      icon: Icons.folder_open, title: "尚無收藏群組")
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 40),
                      children: notifier.data.entries
                          .map((e) => _buildRecursiveNode(
                              context, e.key, e.value, [], notifier, 1))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, FavoritesNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () => _showAddDialog(context, [], notifier),
            icon: const Icon(Icons.create_new_folder),
            label: const Text('新增頂層群組'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(45)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _export(context, notifier),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('匯出'))),
              const SizedBox(width: 12),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _showImportDialog(context, notifier),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('匯入'))),
            ],
          ),
        ],
      ),
    );
  }

  void _showActionsDialog(
      BuildContext context, List<String> plates, String title) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('群組車輛操作: $title'),
          contentPadding: const EdgeInsets.only(top: 8.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                dense: true,
                leading: const Icon(Icons.directions_bus_rounded),
                title: const Text('即時動態'),
                onTap: plates.isEmpty
                    ? null
                    : () async {
                        if (await _confirmPerformance(context, plates.length)) {
                          if (!context.mounted) return;
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MultiLiveOsmPage(
                                      title: "$title 即時動態", plates: plates)));
                        }
                      },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.history_rounded),
                title: const Text('歷史軌跡'),
                onTap: () =>
                    _showGroupHistoryTimeDialog(context, title, plates),
              ),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.timeline_rounded),
                  title: const Text('最後軌跡'),
                  onTap: plates.isEmpty
                      ? null
                      : () {
                          _showLastPosition(context, title, plates);
                        }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecursiveNode(
      BuildContext context,
      String title,
      dynamic content,
      List<String> parentPath,
      FavoritesNotifier notifier,
      int depth) {
    final List<String> currentPath = [...parentPath, title];
    final bool isList = content is List;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.only(left: (depth - 1) * 12.0, top: 6, bottom: 2),
      elevation: isList ? 1 : 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () => _showDeleteConfirm(context, currentPath, notifier),
        ),
        children: [
          _buildActionArea(context, title, content, currentPath, notifier),
          if (isList)
            ...List<String>.from(content).map((p) => _buildCarItem(p))
          else if (content is Map)
            ...content.entries
                .map((e) => _buildRecursiveNode(
                    context, e.key, e.value, currentPath, notifier, depth + 1))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildActionArea(BuildContext context, String title, dynamic content,
      List<String> path, FavoritesNotifier notifier) {
    final plates = notifier.getAllPlatesInNode(content);
    final bool hasVehicles = content is List && content.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: hasVehicles
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showActionsDialog(context, plates, title),
                icon: const Icon(Icons.more_horiz_rounded),
                label: const Text('群組車輛操作'),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddDialog(context, path, notifier),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新增子群組'),
              ),
            ),
    );
  }

  // --- 其他輔助方法 ---

  Future<void> _showDeleteConfirm(BuildContext context, List<String> path,
      FavoritesNotifier notifier) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認刪除"),
        content: Text("確定要刪除「${path.last}」及其所有內容嗎？"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("刪除")),
        ],
      ),
    );
    if (result == true) notifier.deleteNode(path);
  }

  void _export(BuildContext context, FavoritesNotifier notifier) {
    Clipboard.setData(ClipboardData(
        text: const JsonEncoder.withIndent('    ').convert(notifier.data)));
    FormatterUtils.showSnackbar(context, 'JSON 已複製');
  }

  Future<void> _showImportDialog(
      BuildContext context, FavoritesNotifier notifier) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Scaffold(
          appBar: AppBar(
              title: const Text('匯入並取代'),
              leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))),
          body: Padding(
            padding: const EdgeInsets.all(70),
            child: Column(
              children: [
                Expanded(
                    child: TextField(
                        textAlignVertical: TextAlignVertical.top,
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder()))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final d = await Clipboard.getData('text/plain');
                          if (d?.text != null) controller.text = d!.text!;
                        },
                        icon: const Icon(Icons.content_paste),
                        label: const Text('貼上'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                          onPressed: () {
                            try {
                              notifier.importAll(jsonDecode(controller.text));
                              Navigator.pop(context);
                            } catch (e) {
                              FormatterUtils.showSnackbar(context, '格式錯誤');
                            }
                          },
                          child: const Text('匯入並取代')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, List<String> path,
      FavoritesNotifier notifier) async {
    final c = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("新增群組"),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("取消")),
                FilledButton(
                    onPressed: () {
                      notifier.addSubFolder(path, c.text);
                      Navigator.pop(context);
                    },
                    child: const Text("新增")),
              ],
            ));
  }

  Future<void> _showLastPosition(
      BuildContext context, String title, List<String> plates) async {
    if (await _confirmPerformance(context, plates.length)) {
      if (!context.mounted) return;
      await ApiUtils.fetchCarsByPlates(plates);
      _showTrack(context, title, plates, null, null);
    }
  }

  Future<void> _showTrack(BuildContext context, String title,
      List<String> plates, DateTime? start, DateTime? end) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final cars = await ApiUtils.fetchCarsByPlates(plates);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (cars.isNotEmpty) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MultiHistoryOsmPage(
                    title: "$title 歷史軌跡",
                    cars: cars,
                    startTime: start,
                    endTime: end)));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildCarItem(String plate) {
    final car = Static.carData.firstWhere((c) => c.plate == plate,
        orElse: () => Car(
            plate: plate, type: Type.unknown, rawType: "未知", lastSeen: null));
    return CarListItem(car: car);
  }
}
