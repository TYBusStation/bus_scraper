// lib/pages/history_page.dart

// ... (其他程式碼保持不變) ...
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../static.dart';
import 'history_osm_page.dart';

class HistoryPage extends StatefulWidget {
  final String plate;

  const HistoryPage({super.key, required this.plate});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = false;
  List<BusPoint> _allHistoryData = [];
  String? _error;
  String? _message;

  DateTime _selectedStartTime =
      DateTime.now().subtract(const Duration(hours: 1));
  DateTime _selectedEndTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _message = "請選擇時間範圍後點擊查詢。";
  }

  Future<void> _pickDateTime(BuildContext context, bool isStartTime) async {
    final DateTime initialDate =
        isStartTime ? _selectedStartTime : _selectedEndTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 6, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: isStartTime ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: isStartTime ? '選擇開始時間' : '選擇結束時間',
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
          if (isStartTime) {
            _selectedStartTime = newDateTime;
            if (_selectedStartTime.isAfter(_selectedEndTime)) {
              _selectedEndTime =
                  _selectedStartTime.add(const Duration(minutes: 1));
            }
          } else {
            _selectedEndTime = newDateTime;
            if (_selectedEndTime.isBefore(_selectedStartTime)) {
              _selectedStartTime =
                  _selectedEndTime.subtract(const Duration(minutes: 1));
            }
          }
          _message = "時間已更新，請點擊查詢。";
          _allHistoryData = [];
          _error = null;
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    if (_selectedStartTime.isAfter(_selectedEndTime)) {
      setState(() {
        _error = "錯誤：開始時間不能晚於結束時間。";
        _message = null;
        _allHistoryData = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
      _allHistoryData = [];
    });

    try {
      final String formattedStartTime =
          Static.dateFormat.format(_selectedStartTime);
      final String formattedEndTime =
          Static.dateFormat.format(_selectedEndTime);
      final url = Uri.parse(
          "${Static.apiBaseUrl}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      final response = await Static.dio.getUri(url);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;
        setState(() {
          if (decodedData.isEmpty) {
            _message = "找不到車牌 ${widget.plate} 在此時間範圍內的資料。";
          } else {
            _allHistoryData =
                decodedData.map((item) => BusPoint.fromJson(item)).toList();
          }
          _isLoading = false;
        });
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: "API returned status code ${response.statusCode}",
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errorMessage;
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          errorMessage = "沒有找到任何歷史軌跡資料。";
        } else {
          String errorDetail = e.response!.data.toString();
          if (errorDetail.length > 200) {
            errorDetail = "${errorDetail.substring(0, 200)}...";
          }
          errorMessage =
              "無法獲取數據 (狀態碼: ${e.response!.statusCode})。\n詳情: $errorDetail";
        }
      } else {
        errorMessage = "網路請求失敗: ${e.message}";
      }
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "發生未知錯誤: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 歷史位置'),
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainer, // 讓 AppBar 與背景稍微區分
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildControlPanel(), // 美化後的控制面板
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  /// 美化後的控制面板
  Widget _buildControlPanel() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 時間選擇
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePickerButton(
                    context: context,
                    isStart: true,
                    time: _selectedStartTime,
                    onPressed: () => _pickDateTime(context, true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward_rounded),
                ),
                Expanded(
                  child: _buildDateTimePickerButton(
                    context: context,
                    isStart: false,
                    time: _selectedEndTime,
                    onPressed: () => _pickDateTime(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 操作按鈕
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('查詢'),
                    onPressed: _isLoading ? null : _fetchHistory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_allHistoryData.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.map_outlined),
                      label: Text('地圖 (${_allHistoryData.length})'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryOsmPage(
                            plate: widget.plate,
                            points: _allHistoryData.reversed.toList(),
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 輔助建立日期時間按鈕的 Widget
  Widget _buildDateTimePickerButton({
    required BuildContext context,
    required bool isStart,
    required DateTime time,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStart ? "開始時間" : "結束時間",
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              Static.displayDateFormatNoSec.format(time),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// 美化後的結果顯示區
  Widget _buildResultsArea() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 60),
              const SizedBox(height: 16),
              Text('查詢失敗',
                  style: textTheme.headlineSmall
                      ?.copyWith(color: colorScheme.error)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center, style: textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_allHistoryData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 60),
              const SizedBox(height: 16),
              Text(
                _message ?? '沒有資料',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: _allHistoryData.length,
      itemBuilder: (context, index) {
        final dataPoint = _allHistoryData[index];
        final route =
            Static.routeData.firstWhere((r) => r.id == dataPoint.routeId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 頂部：時間和操作按鈕
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Static.displayDateFormat.format(dataPoint.dataTime),
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.explore_outlined),
                          color: colorScheme.secondary,
                          tooltip: '在地圖上繪製此點',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryOsmPage(
                                plate: widget.plate,
                                points: [dataPoint],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.map_sharp),
                          color: Colors.blueAccent,
                          tooltip: '在 Google Map 上查看',
                          onPressed: () async => await launchUrl(Uri.parse(
                              "https://www.google.com/maps?q=${dataPoint.lat},${dataPoint.lon}(${route.name} | ${dataPoint.goBack == 1 ? "去程" : "返程"} | ${Static.displayDateFormat.format(dataPoint.dataTime)})")),
                        ),
                      ],
                    )
                  ],
                ),
                const Divider(height: 12),
                // 中部：路線和方向
                Wrap(
                  spacing: 8.0,
                  runSpacing: 6.0,
                  children: [
                    // *** 修改點 3: 使用 _buildInfoChip 替換所有 _buildInfoChipForPanel ***
                    _buildInfoChip(
                      icon: Icons.route_outlined,
                      label: "${route.name} (${route.id})",
                    ),
                    _buildInfoChip(
                      icon: Icons.description_outlined,
                      label: route.description,
                    ),
                    _buildInfoChip(
                      icon: Icons.swap_horiz,
                      label:
                          "往 ${dataPoint.goBack == 1 ? route.destination : route.departure}",
                    ),
                    _buildInfoChip(
                      icon: dataPoint.dutyStatus == 0
                          ? Icons.work_outline
                          : Icons.work_off_outlined,
                      label: dataPoint.dutyStatus == 0 ? "營運" : "非營運",
                      color: dataPoint.dutyStatus == 0
                          ? Colors.green
                          : Colors.orange,
                    ),
                    _buildInfoChip(
                      icon: Icons.person_pin_circle_outlined,
                      label:
                          "駕駛：${dataPoint.driverId == "0" ? "未知" : dataPoint.driverId}",
                    ),
                    _buildInfoChip(
                      icon: Icons.gps_fixed,
                      label:
                          "${dataPoint.lat.toStringAsFixed(5)}, ${dataPoint.lon.toStringAsFixed(5)}",
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 輔助建立資訊 Chip 的 Widget
  Widget _buildInfoChip(
      {required IconData icon, required String label, Color? color}) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon,
          size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
      label: Text(label, style: theme.textTheme.labelMedium),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
