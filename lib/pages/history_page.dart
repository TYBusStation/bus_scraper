// lib/pages/history_page.dart

import 'package:bus_scraper/data/bus_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../static.dart';
import 'history_osm_page.dart';
import 'segment_details_page.dart';

// TrajectorySegment class and HistoryPage StatefulWidget remain unchanged...
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
        routeId = points.first.routeId,
        goBack = points.first.goBack,
        dutyStatus = points.first.dutyStatus,
        driverId = points.first.driverId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrajectorySegment &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          routeId == other.routeId &&
          driverId == other.driverId;

  @override
  int get hashCode => startTime.hashCode ^ routeId.hashCode ^ driverId.hashCode;
}

class HistoryPage extends StatefulWidget {
  final String plate;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final String? initialDriverId;
  final String? initialRouteId;

  const HistoryPage({
    super.key,
    required this.plate,
    this.initialStartTime,
    this.initialEndTime,
    this.initialDriverId,
    this.initialRouteId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // ... all methods until _buildSegmentCard remain unchanged ...
  bool _isLoading = false;
  List<BusPoint> _allHistoryData = [];
  List<TrajectorySegment> _segments = [];
  String? _error;
  String? _message;

  late DateTime _selectedStartTime;
  late DateTime _selectedEndTime;

  List<TrajectorySegment> _filteredSegments = [];

  List<BusRoute> _availableRoutes = [];
  List<String> _availableDrivers = [];

  List<String> _selectedRouteIds = [];
  List<String> _selectedDriverIds = [];

  @override
  void initState() {
    super.initState();

    _selectedStartTime = widget.initialStartTime ??
        DateTime.now().subtract(const Duration(hours: 1));
    _selectedEndTime = widget.initialEndTime ?? DateTime.now();

    if (widget.initialDriverId != null) {
      _selectedDriverIds = [widget.initialDriverId!];
    }

    if (widget.initialRouteId != null) {
      _selectedRouteIds = [widget.initialRouteId!];
    }

    _message = "請選擇時間範圍後點擊查詢。";
  }

  Future<void> _pickDateTime(BuildContext context, bool isStartTime) async {
    final DateTime initialDate =
        isStartTime ? _selectedStartTime : _selectedEndTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 6, 8),
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
          _clearDataAndFilters();
        });
      }
    }
  }

  void _clearDataAndFilters() {
    setState(() {
      _allHistoryData = [];
      _segments = [];
      _filteredSegments = [];
      _error = null;
      _selectedRouteIds = [];
      _selectedDriverIds = [];
      _availableDrivers = [];
      _availableRoutes = [];
    });
  }

  List<TrajectorySegment> _processDataIntoSegments(List<BusPoint> points) {
    if (points.isEmpty) return [];
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
        _clearDataAndFilters();
      });
      return;
    }

    final routesToKeep = List<String>.from(_selectedRouteIds);
    final driversToKeep = List<String>.from(_selectedDriverIds);

    setState(() {
      _isLoading = true;
      _message = null;
      _error = null;
      _allHistoryData = [];
      _segments = [];
      _filteredSegments = [];
      _availableRoutes = [];
      _availableDrivers = [];
    });

    try {
      final String formattedStartTime =
          Static.apiDateFormat.format(_selectedStartTime);
      final String formattedEndTime =
          Static.apiDateFormat.format(_selectedEndTime);
      final url = Uri.parse(
          "${Static.apiBaseUrl}/${Static.localStorage.city}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      final response = await Static.dio.getUri(url);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;

        if (decodedData.isEmpty) {
          setState(() {
            _message = "找不到車牌 ${widget.plate} 在此時間範圍內的資料。";
            _isLoading = false;
          });
          return;
        }

        final allHistoryData =
            decodedData.map((item) => BusPoint.fromJson(item)).toList();
        final segments = _processDataIntoSegments(allHistoryData);
        final uniqueRouteIds = segments.map((s) => s.routeId).toSet();

        final fetchFutures = uniqueRouteIds
            .map((id) async => await Static.getRouteById(id))
            .toList();
        final List<BusRoute> fetchedRoutes = await Future.wait(fetchFutures);

        setState(() {
          _allHistoryData = allHistoryData;
          _segments = segments;
          _availableRoutes = fetchedRoutes;
          _availableRoutes.sort((a, b) => Static.compareRoutes(a.name, b.name));
          _availableDrivers = segments.map((s) => s.driverId).toSet().toList();
          _availableDrivers.sort();
          _selectedRouteIds = routesToKeep;
          _selectedDriverIds = driversToKeep;
          _applyFilters();
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
          final errorDetail = e.response?.data['detail'] ?? '伺服器未提供詳細錯誤訊息';
          errorMessage =
              "無法獲取數據 (狀態碼: ${e.response!.statusCode}) - $errorDetail";
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

  void _applyFilters() {
    setState(() {
      _filteredSegments = _segments.where((segment) {
        final routeMatch = _selectedRouteIds.isEmpty ||
            _selectedRouteIds.contains(segment.routeId);
        final driverMatch = _selectedDriverIds.isEmpty ||
            _selectedDriverIds.contains(segment.driverId);
        return routeMatch && driverMatch;
      }).toList();
    });
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
            if (_segments.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildFilterDropdowns(),
            ],
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
                      onPressed: _filteredSegments.isEmpty
                          ? null
                          : () {
                              final filteredSet = _filteredSegments.toSet();

                              final backgroundSegments = _segments
                                  .where((segment) =>
                                      !filteredSet.contains(segment))
                                  .toList();

                              final bool isFiltered =
                                  _filteredSegments.length !=
                                          _segments.length ||
                                      _selectedRouteIds.isNotEmpty ||
                                      _selectedDriverIds.isNotEmpty;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryOsmPage(
                                    plate: widget.plate,
                                    segments: _filteredSegments,
                                    backgroundSegments:
                                        backgroundSegments.isNotEmpty
                                            ? backgroundSegments
                                            : null,
                                    isFiltered: isFiltered,
                                  ),
                                ),
                              );
                            },
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

  Widget _buildFilterDropdowns() {
    return Row(
      children: [
        Expanded(
          child: _buildMultiSelectFilterChip(
            icon: Icons.route_outlined,
            label: '路線',
            allOptions: {
              for (var route in _availableRoutes)
                route.id: "${route.name} (${route.id})\n${route.description}",
              for (var segment in _segments)
                if (!_availableRoutes.any((r) => r.id == segment.routeId) &&
                    !Static.routeData.any((r) => r.id == segment.routeId))
                  segment.routeId: '未知路線 (${segment.routeId})'
            },
            selectedOptions: _selectedRouteIds,
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedRouteIds = newSelection;
                _applyFilters();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMultiSelectFilterChip(
            icon: Icons.person_pin_circle_outlined,
            label: '駕駛',
            allOptions: {
              for (var driverId in _availableDrivers)
                driverId: Static.getDriverText(driverId)
            },
            selectedOptions: _selectedDriverIds,
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedDriverIds = newSelection;
                _applyFilters();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectFilterChip({
    required IconData icon,
    required String label,
    required Map<String, String> allOptions,
    required List<String> selectedOptions,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    String getDisplayName(String key) {
      return allOptions[key] ?? key;
    }

    String displayText = selectedOptions.isEmpty
        ? '所有$label'
        : (selectedOptions.length == 1
            ? getDisplayName(selectedOptions.first).split('\n').first
            : '${selectedOptions.length} 個$label');

    return InkWell(
      onTap: () async {
        final List<String>? result = await _showMultiSelectDialog(
          title: '選擇$label',
          items: allOptions,
          initialSelectedValues: selectedOptions,
        );

        if (result != null) {
          onSelectionChanged(result);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        child: Text(displayText,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Future<List<String>?> _showMultiSelectDialog({
    required String title,
    required Map<String, String> items,
    required List<String> initialSelectedValues,
  }) async {
    final tempSelectedValues = Set<String>.from(initialSelectedValues);

    return showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: items.entries.map((entry) {
                      final key = entry.key;
                      final value = entry.value;
                      return CheckboxListTile(
                        title: Text(value,
                            style: Theme.of(context).textTheme.bodyMedium),
                        value: tempSelectedValues.contains(key),
                        onChanged: (bool? isChecked) {
                          setStateDialog(() {
                            if (isChecked == true) {
                              tempSelectedValues.add(key);
                            } else {
                              tempSelectedValues.remove(key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                ),
                FilledButton(
                  child: const Text('確定'),
                  onPressed: () {
                    Navigator.pop(context, tempSelectedValues.toList());
                  },
                ),
              ],
            );
          },
        );
      },
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

    if (_filteredSegments.isEmpty && _segments.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_off_outlined,
                  color: Theme.of(context).colorScheme.secondary, size: 60),
              const SizedBox(height: 16),
              Text(
                '無符合篩選的結果',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '請嘗試調整路線或駕駛員篩選條件。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final segments = _filteredSegments.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        return _buildSegmentCard(segment);
      },
    );
  }

  Widget _buildSegmentCard(TrajectorySegment segment) {
    final theme = Theme.of(context);
    final route = Static.getRouteByIdSync(segment.routeId);

    String durationStr = '';
    if (segment.duration.inHours > 0) {
      durationStr += '${segment.duration.inHours}時';
    }
    if (segment.duration.inMinutes.remainder(60) > 0) {
      durationStr += '${segment.duration.inMinutes.remainder(60)}分';
    }
    durationStr += '${segment.duration.inSeconds.remainder(60)}秒';

    final String driverText = Static.getDriverText(segment.driverId);
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: Icon(Icons.route_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  label: Text("${route.name} (${route.id})",
                      style: theme.textTheme.labelMedium),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
                ),
                Chip(
                  avatar: Icon(Icons.swap_horiz,
                      size: 18, color: theme.colorScheme.primary),
                  label: Text(
                      "往 ${route.destination.isNotEmpty && route.departure.isNotEmpty ? (segment.goBack == 1 ? route.destination : route.departure) : '未知'}",
                      style: theme.textTheme.labelMedium),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
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
                                  segments: [segment],
                                  isFiltered: true, // 繪製單段時，視為篩選過的
                                  backgroundSegments: null,
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
                    color: valueColor,
                  ))),
        ],
      ),
    );
  }
}
