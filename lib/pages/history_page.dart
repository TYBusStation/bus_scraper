import 'package:bus_scraper/data/bus_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../data/trajectory_segment.dart';
import '../static.dart';
import '../widgets/empty_state_indicator.dart';
import 'history_osm_page.dart';
import 'segment_details_page.dart';

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
  bool _isLoading = false;
  List<BusPoint> _allHistoryData = [];
  List<TrajectorySegment> _segments = [];
  String? _error;
  String? _message;

  late DateTime _startTime;
  late DateTime _endTime;

  List<TrajectorySegment> _filteredSegments = [];

  List<BusRoute> _availableRoutes = [];
  List<String> _availableDrivers = [];

  List<String> _selectedRouteIds = [];
  List<String> _selectedDriverIds = [];

  @override
  void initState() {
    super.initState();

    _startTime = widget.initialStartTime ??
        DateTime.now().subtract(const Duration(hours: 1));
    _endTime = widget.initialEndTime ?? DateTime.now();

    if (widget.initialDriverId != null) {
      _selectedDriverIds = [widget.initialDriverId!];
    }
    if (widget.initialRouteId != null) {
      _selectedRouteIds = [widget.initialRouteId!];
    }
    _message = "請選擇時間範圍後點擊查詢。";

    if (widget.initialStartTime != null && widget.initialEndTime != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchHistory();
      });
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

      bool driverChanged = Static.city.hasDriverInfo &&
          currentPoint.driverId != previousPoint.driverId;

      bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
          currentPoint.goBack != previousPoint.goBack ||
          currentPoint.dutyStatus != previousPoint.dutyStatus ||
          driverChanged ||
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
      final String formattedStartTime = Static.apiTimeFormat.format(_startTime);
      final String formattedEndTime = Static.apiTimeFormat.format(_endTime);
      final url = Uri.parse(
          "${Static.apiBaseUrl}/${Static.city.code}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

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

        final List<String> availableDrivers = Static.city.hasDriverInfo
            ? segments
                .map((s) => s.driverId)
                .whereType<String>()
                .toSet()
                .toList()
            : [];
        availableDrivers.sort();

        setState(() {
          _allHistoryData = allHistoryData;
          _segments = segments;
          _availableRoutes = fetchedRoutes;
          _availableRoutes.sort((a, b) => Static.compareRoutes(a.name, b.name));
          _availableDrivers = availableDrivers;
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
        final driverMatch = !Static.city.hasDriverInfo ||
            _selectedDriverIds.isEmpty ||
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
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDateTimePickerButton(
                    context: context,
                    isStart: true,
                    time: _startTime,
                    onPressed: () => Static.selectDateTime(
                      context: context,
                      isStart: true,
                      currentRange:
                          DateTimeRange(start: _startTime, end: _endTime),
                      lastSelectableDate:
                          DateTime.now().add(const Duration(days: 1)),
                      pickTime: true,
                      maxDuration: const Duration(days: 2),
                      onDateTimeChanged: (range) => setState(() {
                        _startTime = range.start;
                        _endTime = range.end;
                        _message = "時間已更新，請點擊查詢。";
                        _clearDataAndFilters();
                      }),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.arrow_forward_rounded, size: 20),
                ),
                Expanded(
                  child: _buildDateTimePickerButton(
                    context: context,
                    isStart: false,
                    time: _endTime,
                    onPressed: () => Static.selectDateTime(
                      context: context,
                      isStart: false,
                      currentRange:
                          DateTimeRange(start: _startTime, end: _endTime),
                      lastSelectableDate:
                          DateTime.now().add(const Duration(days: 1)),
                      pickTime: true,
                      maxDuration: const Duration(days: 2),
                      onDateTimeChanged: (range) => setState(() {
                        _startTime = range.start;
                        _endTime = range.end;
                        _message = "時間已更新，請點擊查詢。";
                        _clearDataAndFilters();
                      }),
                    ),
                  ),
                ),
              ],
            ),
            if (_segments.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildFilterDropdowns(),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('查詢'),
                    onPressed: _isLoading ? null : _fetchHistory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_allHistoryData.isNotEmpty) ...[
                  const SizedBox(width: 8),
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
        if (Static.city.hasDriverInfo) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _buildMultiSelectFilterChip(
              icon: Icons.person_pin_circle_outlined,
              label: '駕駛長',
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
          isDense: true,
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        child: Text(displayText, style: Theme.of(context).textTheme.bodySmall),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: items.entries.map((entry) {
                      final key = entry.key;
                      final value = entry.value;
                      return CheckboxListTile(
                        dense: true,
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
                  onPressed: () => Navigator.pop(context, null),
                ),
                FilledButton(
                  child: const Text('確定'),
                  onPressed: () =>
                      Navigator.pop(context, tempSelectedValues.toList()),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStart ? "開始時間" : "結束時間",
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 1),
            Text(
              Static.displayTimeFormatNoSec.format(time),
              style: theme.textTheme.bodyMedium
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
      return EmptyStateIndicator(
        icon: Icons.error_outline,
        title: '查詢失敗',
        subtitle: _error!,
        iconColor: Theme.of(context).colorScheme.error,
      );
    }

    if (_segments.isEmpty) {
      return EmptyStateIndicator(
        icon: Icons.info_outline,
        title: _message ?? '請點擊查詢以載入歷史軌跡',
      );
    }

    if (_filteredSegments.isEmpty && _segments.isNotEmpty) {
      return const EmptyStateIndicator(
        icon: Icons.filter_alt_off_outlined,
        title: '無符合篩選的結果',
        subtitle: '請嘗試調整路線或駕駛長篩選條件。',
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
    final dutyStatusInfo = Static.getDutyStatusInfo(segment.dutyStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  avatar: Icon(Icons.route_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  label: Text("${route.name} (${route.id})",
                      style: theme.textTheme.labelSmall),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  avatar: Icon(Icons.swap_horiz,
                      size: 16, color: theme.colorScheme.primary),
                  label: Text(
                      "往 ${Static.getBusDirectionName(route, segment.goBack)}",
                      style: theme.textTheme.labelSmall),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
                ),
              ],
            ),
            const Divider(height: 12),
            _buildSegmentDetailRow(Icons.timer_outlined, "持續時間", durationStr),
            _buildSegmentDetailRow(Icons.play_circle_outline, "開始",
                Static.displayTimeFormat.format(segment.startTime)),
            _buildSegmentDetailRow(Icons.stop_circle_outlined, "結束",
                Static.displayTimeFormat.format(segment.endTime)),
            _buildSegmentDetailRow(Icons.scatter_plot_outlined, "軌跡點數",
                "${segment.points.length} 點"),
            if (Static.city.hasDriverInfo)
              _buildSegmentDetailRow(
                  Icons.person_pin_circle_outlined, "駕駛長", driverText),
            _buildSegmentDetailRow(
                dutyStatusInfo.text == "營運"
                    ? Icons.work_outline
                    : Icons.work_off_outlined,
                "狀態",
                dutyStatusInfo.text,
                valueColor: dutyStatusInfo.color),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.view_list_rounded, size: 16),
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
                  icon: const Icon(Icons.explore_outlined, size: 16),
                  label: const Text('繪製此段'),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HistoryOsmPage(
                                  plate: widget.plate,
                                  segments: [segment],
                                  isFiltered: true,
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
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
              width: 60, child: Text(title, style: theme.textTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
