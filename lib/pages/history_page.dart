// lib/pages/history_page.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../static.dart';
import 'history_osm_page.dart';
import 'segment_details_page.dart';

/// 用於封裝單個連續軌跡段的數據模型
class TrajectorySegment {
  final List<BusPoint> points;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String routeId;
  final int goBack;
  final int dutyStatus;
  final String driverId;

  TrajectorySegment({required this.points})
      : startTime = points.first.dataTime,
        endTime = points.last.dataTime,
        duration = points.last.dataTime.difference(points.first.dataTime),
        // 假設段內所有點的這些屬性都相同
        routeId = points.first.routeId,
        goBack = points.first.goBack,
        dutyStatus = points.first.dutyStatus,
        driverId = points.first.driverId;
}

class HistoryPage extends StatefulWidget {
  final String plate;

  const HistoryPage({super.key, required this.plate});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = false;
  List<BusPoint> _allHistoryData = [];
  List<TrajectorySegment> _segments = [];
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
          _segments = [];
          _error = null;
        });
      }
    }
  }

  List<TrajectorySegment> _processDataIntoSegments(List<BusPoint> points) {
    if (points.length < 2) {
      return [];
    }

    final List<TrajectorySegment> segments = [];
    List<BusPoint> currentSegmentPoints = [points.first];

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final previousPoint = points[i - 1];
      final timeDifference =
          currentPoint.dataTime.difference(previousPoint.dataTime);

      bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
          currentPoint.goBack != previousPoint.goBack ||
          currentPoint.dutyStatus != previousPoint.dutyStatus ||
          currentPoint.driverId != previousPoint.driverId ||
          timeDifference.inMinutes >= 10);

      if (isSegmentEnd) {
        if (currentSegmentPoints.isNotEmpty) {
          segments
              .add(TrajectorySegment(points: List.from(currentSegmentPoints)));
        }
        currentSegmentPoints = [currentPoint];
      } else {
        currentSegmentPoints.add(currentPoint);
      }
    }

    if (currentSegmentPoints.isNotEmpty) {
      segments.add(TrajectorySegment(points: List.from(currentSegmentPoints)));
    }

    return segments;
  }

  Future<void> _fetchHistory() async {
    if (_selectedStartTime.isAfter(_selectedEndTime)) {
      setState(() {
        _error = "錯誤：開始時間不能晚於結束時間。";
        _message = null;
        _allHistoryData = [];
        _segments = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
      _allHistoryData = [];
      _segments = [];
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
            _segments = _processDataIntoSegments(_allHistoryData);
            if (_segments.isEmpty) {
              _message = "資料點過少，無法形成有效軌跡段。";
            }
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
          errorMessage = "無法獲取數據 (狀態碼: ${e.response!.statusCode})。";
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
        title: Text('${widget.plate} 歷史軌跡'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                      label: const Text('完整軌跡'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryOsmPage(
                            plate: widget.plate,
                            points: _allHistoryData.toList(),
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

  Widget _buildResultsArea() {
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
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 60),
              const SizedBox(height: 16),
              Text('查詢失敗',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary, size: 60),
              const SizedBox(height: 16),
              Text(
                _message ?? '沒有可顯示的軌跡段',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      );
    }

    final segments = _segments.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        return _buildSegmentCard(segment);
      },
    );
  }

  /// 為單個軌跡段建立卡片
  Widget _buildSegmentCard(TrajectorySegment segment) {
    final theme = Theme.of(context);
    final route = Static.routeData.firstWhere((r) => r.id == segment.routeId);

    String durationStr = '';
    if (segment.duration.inHours > 0) {
      durationStr += '${segment.duration.inHours}時';
    }
    if (segment.duration.inMinutes.remainder(60) > 0) {
      durationStr += '${segment.duration.inMinutes.remainder(60)}分';
    }
    durationStr += '${segment.duration.inSeconds.remainder(60)}秒';

    // *** 核心修改點：準備駕駛和營運狀態的文字和顏色 ***
    final String driverText = segment.driverId == "0" ? "未知" : segment.driverId;
    final String dutyText = segment.dutyStatus == 0 ? "營運" : "非營運";
    final Color dutyColor = segment.dutyStatus == 0
        ? Colors.green.shade700
        : Colors.orange.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: Icon(Icons.route_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  label: Text("${route.name} (${route.id})",
                      style: theme.textTheme.labelLarge),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "往 ${segment.goBack == 1 ? route.destination : route.departure}",
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildSegmentDetailRow(Icons.timer_outlined, "持續時間", durationStr),
            _buildSegmentDetailRow(Icons.play_circle_outline, "開始",
                Static.displayDateFormat.format(segment.startTime)),
            _buildSegmentDetailRow(Icons.stop_circle_outlined, "結束",
                Static.displayDateFormat.format(segment.endTime)),
            _buildSegmentDetailRow(Icons.scatter_plot_outlined, "軌跡點數",
                "${segment.points.length} 點"),
            // *** 核心修改點：新增駕駛和營運狀態的顯示行 ***
            _buildSegmentDetailRow(
                Icons.person_pin_circle_outlined, "駕駛", driverText),
            _buildSegmentDetailRow(
                segment.dutyStatus == 0
                    ? Icons.work_outline
                    : Icons.work_off_outlined,
                "狀態",
                dutyText,
                valueColor: dutyColor),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.view_list_rounded),
                  label: const Text('查看點位'),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SegmentDetailsPage(
                                plate: widget.plate, segment: segment)));
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('繪製此段'),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HistoryOsmPage(
                                  plate: widget.plate,
                                  points: segment.points.toList(),
                                )));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 修改 _buildSegmentDetailRow 以接受可選的 valueColor
  Widget _buildSegmentDetailRow(IconData icon, String title, String value,
      {Color? valueColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
              width: 70, child: Text(title, style: theme.textTheme.bodyMedium)),
          Expanded(
              child: Text(value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    // 如果提供了 valueColor，則使用它
                    color: valueColor,
                  ))),
        ],
      ),
    );
  }
}
