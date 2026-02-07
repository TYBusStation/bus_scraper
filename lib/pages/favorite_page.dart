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

  Future<void> _showGroupHistoryTimeDialog(
      BuildContext context, String title, List<String> plates) async {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesNotifier>(
      builder: (context, notifier, child) {
        return Column(
          children: [
            _buildTopBar(context, notifier),
            const Divider(height: 1),
            Expanded(
              child: notifier.data.isEmpty
                  ? const EmptyStateIndicator(
                      icon: Icons.folder_open, title: "尚無群組資料")
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () => _showAddDialog(context, [], notifier),
            icon: const Icon(Icons.create_new_folder),
            label: const Text('新增群組'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showExportDialog(context, notifier),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('匯出'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context, notifier),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('匯入'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final plates = notifier.getAllPlatesInNode(content);
    final bool isList = content is List;

    return Card(
      margin: EdgeInsets.only(left: (depth - 1) * 12.0, top: 4, bottom: 4),
      elevation: isList ? 1 : 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: FilledButton.icon(
          onPressed: () =>
              _showActionsDialog(context, plates, title, currentPath, notifier),
          icon: const Icon(Icons.more_horiz_rounded, size: 16),
          label: const Text('群組操作'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: theme.textTheme.labelMedium,
          ),
        ),
        children: [
          if (content is Map || (isList && content.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showAddDialog(context, currentPath, notifier),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('新增子群組'),
                ),
              ),
            ),
          if (content is Map)
            ...content.entries.map((e) => _buildRecursiveNode(
                context, e.key, e.value, currentPath, notifier, depth + 1))
          else if (isList) ...[
            if (content.isEmpty)
              const ListTile(
                dense: true,
                title: Text("此群組尚無車輛",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ...content.map((p) => _buildCarItem(p.toString())),
          ],
        ],
      ),
    );
  }

  void _showActionsDialog(BuildContext context, List<String> plates,
      String title, List<String> path, FavoritesNotifier notifier) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        const compactDensity = VisualDensity(horizontal: -4, vertical: -4);
        const contentPadding =
            EdgeInsets.symmetric(horizontal: 16, vertical: 4);

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          contentPadding: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.folder_shared_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('群組: $title',
                      style: const TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (plates.isNotEmpty) ...[
                _buildCompactListTile(ctx,
                    icon: Icons.directions_bus_rounded,
                    title: '群組即時動態', onTap: () async {
                  if (await _confirmPerformance(context, plates.length)) {
                    if (!context.mounted) return;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MultiLiveOsmPage(
                                title: "$title 即時動態", plates: plates)));
                  }
                }),
                _buildCompactListTile(ctx,
                    icon: Icons.history_rounded,
                    title: '群組歷史軌跡',
                    onTap: () =>
                        _showGroupHistoryTimeDialog(context, title, plates)),
                _buildCompactListTile(ctx,
                    icon: Icons.timeline_rounded,
                    title: '群組最後軌跡',
                    onTap: () => _showLastPosition(context, title, plates)),
                const Divider(height: 1, thickness: 0.5),
              ],
              _buildCompactListTile(ctx,
                  icon: Icons.edit_outlined,
                  title: '重新命名',
                  onTap: () => _showRenameDialog(context, path, notifier)),
              _buildCompactListTile(ctx,
                  icon: Icons.delete_outline,
                  title: '刪除群組',
                  color: Colors.red,
                  onTap: () => _showDeleteConfirm(context, path, notifier)),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
          ],
        );
      },
    );
  }

  Widget _buildCompactListTile(
    BuildContext dialogCtx, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, size: 20, color: color),
      minLeadingWidth: 24,
      title: Text(title, style: TextStyle(fontSize: 14, color: color)),
      onTap: () {
        Navigator.pop(dialogCtx);
        onTap();
      },
    );
  }

  void _showExportDialog(BuildContext context, FavoritesNotifier notifier) {
    int vehicleCount = 0;
    void count(dynamic node) {
      if (node is List)
        vehicleCount += node.length;
      else if (node is Map) node.values.forEach(count);
    }

    notifier.data.values.forEach(count);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("匯出"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("將目前的收藏結構轉換為 JSON 匯出。"),
            const SizedBox(height: 16),
            Text("統計：${notifier.data.length} 個群組，共 $vehicleCount 台車輛",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: const JsonEncoder.withIndent('    ')
                      .convert(notifier.data)));
              Navigator.pop(context);
              FormatterUtils.showSnackbar(context, '已複製 JSON 到剪貼簿');
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text("匯出"),
          ),
        ],
      ),
    );
  }

  dynamic _processImportData(dynamic data) {
    if (data is Map) {
      return data.map(
          (key, value) => MapEntry(key.toString(), _processImportData(value)));
    } else if (data is List) {
      final uniquePlates = data
          .map((e) => e.toString().toUpperCase().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      uniquePlates.sort();
      return uniquePlates;
    }
    return data;
  }

  Future<void> _showImportDialog(
      BuildContext context, FavoritesNotifier notifier) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('匯入'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("⚠️ 注意：此操作將會取代目前的所有群組。",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: '請在此貼上 JSON 內容',
                    border: OutlineInputBorder(),
                    filled: true,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton.icon(
            onPressed: () async {
              final d = await Clipboard.getData('text/plain');
              if (d?.text != null) controller.text = d!.text!;
            },
            icon: const Icon(Icons.paste_rounded),
            label: const Text('貼上'),
          ),
          FilledButton(
            onPressed: () {
              final String input = controller.text.trim();

              if (input.isEmpty) {
                FormatterUtils.showSnackbar(context, '內容不能為空');
                return;
              }

              try {
                final decoded = jsonDecode(input);

                if (decoded is! Map) {
                  FormatterUtils.showSnackbar(context, '格式錯誤：根節點必須是物件 (Map)');
                  return;
                }

                final processed = _processImportData(decoded);

                notifier.importAll(Map<String, dynamic>.from(processed));

                Navigator.pop(context);
                FormatterUtils.showSnackbar(context, '匯入成功');
              } on FormatException catch (e) {
                debugPrint("JSON Parse Error: $e");
                FormatterUtils.showSnackbar(context, 'JSON 語法錯誤，請檢查符號是否正確');
              } catch (e) {
                debugPrint("Import Error: $e");
                FormatterUtils.showSnackbar(context, '匯入失敗：資料內容格式不符');
              }
            },
            child: const Text('匯入'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, List<String> path,
      FavoritesNotifier notifier) async {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(path.isEmpty ? "新增群組" : "新增子群組"),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: "群組名稱"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(
              onPressed: () {
                if (c.text.trim().isNotEmpty) {
                  notifier.addSubFolder(path, c.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text("新增")),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, List<String> path,
      FavoritesNotifier notifier) async {
    final c = TextEditingController(text: path.last);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("重新命名群組"),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: "新名稱"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("取消")),
          FilledButton(
              onPressed: () {
                if (c.text.trim().isNotEmpty && c.text.trim() != path.last) {
                  notifier.renameNode(path, c.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text("儲存")),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirm(BuildContext context, List<String> path,
      FavoritesNotifier notifier) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("確認刪除"),
        content: Text("確定要刪除群組「${path.last}」及其包含的所有內容嗎？"),
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

  Future<void> _showLastPosition(
      BuildContext context, String title, List<String> plates) async {
    if (await _confirmPerformance(context, plates.length)) {
      if (!context.mounted) return;
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
                    title: "$title 軌跡",
                    cars: cars,
                    startTime: start,
                    endTime: end)));
      } else {
        FormatterUtils.showSnackbar(context, "找不到相關車輛資料");
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      FormatterUtils.showSnackbar(context, "載入失敗：$e");
    }
  }

  Widget _buildCarItem(String plate) {
    final car = Static.carData.firstWhere((c) => c.plate == plate,
        orElse: () => Car(
            plate: plate, type: Type.unknown, rawType: "未知", lastSeen: null));
    return CarListItem(car: car);
  }
}
