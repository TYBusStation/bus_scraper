// lib/pages/multi_live_osm_page.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../static.dart';
import '../utils/map_data_processor.dart';
import '../widgets/base_map_view.dart';

// --- 優化 1: 為地圖顯示資料創建一個封裝類，讓狀態更新更清晰 ---
class _MapDisplayData {
  final List<Polyline> polylines;
  final List<Marker> markers;
  final LatLngBounds? bounds;

  _MapDisplayData({
    required this.polylines,
    required this.markers,
    this.bounds,
  });
}

const Duration _kRefreshInterval = Duration(seconds: 30);

final GlobalKey<BaseMapViewState> _baseMapStateKey =
    GlobalKey<BaseMapViewState>();

class MultiLiveOsmPage extends StatefulWidget {
  final List<String> plates;

  const MultiLiveOsmPage({super.key, required this.plates});

  @override
  State<MultiLiveOsmPage> createState() => _MultiLiveOsmPageState();
}

class _MultiLiveOsmPageState extends State<MultiLiveOsmPage>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchTime;

  final Map<String, List<BusPoint>> _pointsByPlate = {};
  final Map<String, DateTime> _lastPointTimeByPlate = {};

  // 使用 _MapDisplayData 來管理地圖圖層
  _MapDisplayData _mapData = _MapDisplayData(polylines: [], markers: []);

  late final AnimationController _locationAnimationController;
  late final AnimationController _timerAnimationController;

  bool _isFirstLoadComplete = false;
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _locationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _timerAnimationController = AnimationController(
      vsync: this,
      duration: _kRefreshInterval,
    );

    _fetchAndDrawMap(isInitialLoad: true);

    _refreshTimer = Timer.periodic(_kRefreshInterval, (timer) {
      _fetchAndDrawMap();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationAnimationController.dispose();
    _timerAnimationController.dispose();
    super.dispose();
  }

  void _dismissError() {
    setState(() {
      _error = null;
    });
  }

  Future<void> _fetchAndDrawMap({bool isInitialLoad = false}) async {
    if (!isInitialLoad) {
      _dismissError();
    }

    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final endTime = DateTime.now();
      final List<String> errorPlates = [];

      final futures = widget.plates.map((plate) async {
        final lastPointTime = _lastPointTimeByPlate[plate];

        // --- *** 修正點 *** ---
        final DateTime startTime;
        if (isInitialLoad || lastPointTime == null) {
          // 初次載入或無歷史資料，抓取過去 20 分鐘
          startTime = endTime.subtract(const Duration(minutes: 20));
        } else {
          // 增量更新，從最後一個點的時間再往後推一毫秒開始抓取
          startTime = lastPointTime.add(const Duration(milliseconds: 1));
        }
        // --- *** 修正結束 *** ---

        final formattedStartTime = Static.apiDateFormat.format(startTime);
        final formattedEndTime = Static.apiDateFormat.format(endTime);

        final url = Uri.parse(
            "${Static.apiBaseUrl}/bus_data/$plate?start_time=$formattedStartTime&end_time=$formattedEndTime");

        try {
          final response = await Static.dio.getUri(url);
          if (response.statusCode == 200 && response.data != null) {
            final List<dynamic> decodedData = response.data;
            final newPoints =
                decodedData.map((item) => BusPoint.fromJson(item)).toList();
            return {'plate': plate, 'points': newPoints};
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) {
            errorPlates.add(plate);
          }
        }
        return {'plate': plate, 'points': <BusPoint>[]};
      });

      final results = await Future.wait(futures);
      if (!mounted) return;

      for (var result in results) {
        final plate = result['plate'] as String;
        final newPoints = result['points'] as List<BusPoint>;

        if (isInitialLoad) {
          _pointsByPlate[plate] = newPoints;
        } else {
          _pointsByPlate.putIfAbsent(plate, () => []).addAll(newPoints);
          final twentyMinutesAgo =
              DateTime.now().subtract(const Duration(minutes: 20));
          _pointsByPlate[plate]
              ?.removeWhere((p) => p.dataTime.isBefore(twentyMinutesAgo));
        }

        if (_pointsByPlate[plate]?.isNotEmpty ?? false) {
          _lastPointTimeByPlate[plate] = _pointsByPlate[plate]!.last.dataTime;
        }
      }

      final newMapData = _prepareMapData();

      final allPoints =
          _pointsByPlate.values.expand((points) => points).toList();
      String? newError;
      if (allPoints.isEmpty) {
        newError = "過去 20 分鐘内沒有找到任何收藏車輛的軌跡資料。";
      } else if (errorPlates.isNotEmpty) {
        newError = "部分車輛資料獲取失敗: ${errorPlates.join(', ')}";
      }

      setState(() {
        _mapData = newMapData;
        _isLoading = false;
        _lastFetchTime = DateTime.now();
        _error = newError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "發生未知錯誤: $e";
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        _timerAnimationController.forward(from: 0.0);
        if (isInitialLoad) {
          setState(() {
            _isFirstLoadComplete = true;
          });
        }
      }
    }
  }

  _MapDisplayData _prepareMapData() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    final List<LatLng> allPointsForBounds = [];

    final Map<LatLng, Color> pointColorMap = {};
    int globalColorIndex = 0;

    _pointsByPlate.forEach((plate, points) {
      if (points.isEmpty) return;

      final processedData = processBusPoints(points);

      for (final segmentPolyline in processedData.polylines) {
        final segmentColor = BaseMapView
            .segmentColors[globalColorIndex % BaseMapView.segmentColors.length];

        allPolylines.add(
          Polyline(
            points: segmentPolyline.points,
            color: segmentColor,
            strokeWidth: segmentPolyline.strokeWidth,
          ),
        );

        for (final point in segmentPolyline.points) {
          pointColorMap[point] = segmentColor;
        }

        globalColorIndex++;
      }

      for (final point in points) {
        final latLng = LatLng(point.lat, point.lon);
        allPointsForBounds.add(latLng);

        final color = pointColorMap[latLng] ?? BaseMapView.segmentColors.first;
        allMarkers.add(_buildPointMarker(point, color, plate));
      }

      if (points.isNotEmpty) {
        final lastPoint = points.last;
        allMarkers.add(_buildCurrentLocationMarker(lastPoint, plate));
      }
    });

    return _MapDisplayData(
      polylines: allPolylines,
      markers: allMarkers,
      bounds: allPointsForBounds.isNotEmpty
          ? LatLngBounds.fromPoints(allPointsForBounds)
          : null,
    );
  }

  Marker _buildPointMarker(BusPoint point, Color color, String plate) {
    return PointMarker(
      busPoint: point,
      width: 14,
      height: 14,
      child: GestureDetector(
        onTap: () {
          _baseMapStateKey.currentState?.selectPoint(point, plate: plate);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }

  Marker _buildCurrentLocationMarker(BusPoint point, String plate) {
    return Marker(
      point: LatLng(point.lat, point.lon),
      width: 110,
      height: 110,
      alignment: const Alignment(0.0, 0.23),
      child: GestureDetector(
        onTap: () {
          _baseMapStateKey.currentState?.selectPoint(point, plate: plate);
        },
        child: _buildCurrentLocationMarkerContent(point, plate),
      ),
    );
  }

  Widget _buildCurrentLocationMarkerContent(BusPoint point, String plate) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            plate,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.7, end: 0.0)
                    .animate(_locationAnimationController),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.3, end: 1.0)
                      .animate(_locationAnimationController),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withAlpha(128),
                    ),
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6)
                    ]),
              ),
              const Icon(Icons.directions_bus, color: Colors.white, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: const Text('收藏車輛動態'),
      actions: [
        if (_lastFetchTime != null && !_isLoading)
          AnimatedBuilder(
            animation: _timerAnimationController,
            builder: (context, child) {
              final remainingSeconds = (_kRefreshInterval.inSeconds *
                      (1.0 - _timerAnimationController.value))
                  .ceil();
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '上次更新：${_timeFormat.format(_lastFetchTime!)}',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              remainingSeconds.toString().padLeft(2, '0'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontFeatures: [
                                  const FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: _timerAnimationController.value,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
      backgroundColor: theme.colorScheme.surface.withAlpha(220),
      elevation: 1,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(18.0),
        child: Container(
          color: theme.colorScheme.surface.withAlpha(200),
          alignment: Alignment.center,
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'Map data © OpenStreetMap contributors, Imagery © Esri, Maxar, Earthstar Geo',
            style: TextStyle(
              fontSize: 9,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPoints = _pointsByPlate.values.expand((p) => p).toList();

    return Scaffold(
      appBar: _buildAppBar(context),
      body: BaseMapView(
        key: _baseMapStateKey,
        appBarTitle: '',
        hideAppBar: true,
        isLoading: _isLoading,
        error: _error,
        points: allPoints,
        polylines: _mapData.polylines,
        markers: _mapData.markers,
        bounds: _isFirstLoadComplete ? _mapData.bounds : null,
        onErrorDismiss: _dismissError,
      ),
    );
  }
}
