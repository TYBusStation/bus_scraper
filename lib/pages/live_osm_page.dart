// lib/pages/live_osm_page.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../static.dart';
import '../widgets/base_map_view.dart';

class LiveOsmPage extends StatefulWidget {
  final String plate;

  const LiveOsmPage({super.key, required this.plate});

  @override
  State<LiveOsmPage> createState() => _LiveOsmPageState();
}

class _LiveOsmPageState extends State<LiveOsmPage>
    with SingleTickerProviderStateMixin {
  // ... (其他狀態變數保持不變)
  Timer? _refreshTimer;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchTime;
  DateTime? _lastPointTime;

  List<BusPoint> _points = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetchAndDrawMap(isInitialLoad: true);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _fetchAndDrawMap();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 從 API 獲取數據並更新地圖 (數據邏輯)
  Future<void> _fetchAndDrawMap({bool isInitialLoad = false}) async {
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final endTime = DateTime.now();
      final startTime = isInitialLoad || _lastPointTime == null
          ? endTime.subtract(const Duration(hours: 1))
          : _lastPointTime!;

      final formattedStartTime = Static.dateFormat.format(startTime);
      final formattedEndTime = Static.dateFormat.format(endTime);

      final url = Uri.parse(
          "${Static.apiBaseUrl}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      final response = await Static.dio.getUri(url);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;
        final newPoints = decodedData
            .map((item) => BusPoint.fromJson(item))
            .toList()
            .reversed
            .toList();

        if (isInitialLoad) {
          _points = newPoints;
        } else {
          _points.addAll(newPoints);
          final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
          _points.removeWhere((point) => point.dataTime.isBefore(oneHourAgo));
        }

        if (_points.isNotEmpty) {
          _lastPointTime = _points.last.dataTime;
        }

        _prepareMapData();

        String? newError;
        if (_points.isEmpty) {
          newError = "過去一小時内沒有找到軌跡資料。";
        } else {
          final lastPointTime = _points.last.dataTime;
          final timeDifference = DateTime.now().difference(lastPointTime);

          if (timeDifference.inMinutes >= 10) {
            final minutesAgo = timeDifference.inMinutes;
            newError = "車輛可能已離線 (最後訊號於 $minutesAgo 分鐘前)";
          }
        }

        setState(() {
          _isLoading = false;
          _lastFetchTime = DateTime.now();
          _error = newError;
        });
      } else {
        // 處理其他非 200 的成功狀態碼，視為錯誤
        throw DioException(
            requestOptions: response.requestOptions, response: response);
      }
    } on DioException catch (e) {
      if (!mounted) return;

      // --- 核心修改邏輯開始 ---
      // 檢查 DioException 的類型，並且其 response 不為 null
      if (e.response != null) {
        // 如果狀態碼是 404 (Not Found)
        if (e.response!.statusCode == 404) {
          // 將其視為「空資料」的正常情況
          // 清空點位數據，並準備一個空的地圖
          _points.clear();
          _prepareMapData();

          setState(() {
            _error = "過去一小時内沒有找到軌跡資料。";
            _isLoading = false;
            _lastFetchTime = DateTime.now(); // 仍然記錄更新時間
          });
        } else {
          // 對於其他 HTTP 錯誤 (如 500, 403 等)，顯示通用錯誤訊息
          setState(() {
            _error = "數據獲取失敗: ${e.response!.statusCode}";
            _isLoading = false;
          });
        }
      } else {
        // 對於沒有 response 的錯誤 (如網絡中斷、超時)，顯示另一種錯誤訊息
        setState(() {
          _error = "網絡連線失敗，請檢查您的網絡設定。";
          _isLoading = false;
        });
      }
      // --- 核心修改邏輯結束 ---
    } catch (e) {
      if (!mounted) return;
      // 處理非 DioException 的其他未知錯誤
      setState(() {
        _error = "發生未知錯誤: $e";
        _isLoading = false;
      });
    }
  }

  // _prepareMapData, _create...Marker, 和 build 方法保持不變
  // ... (省略未變動的程式碼)
  void _prepareMapData() {
    if (_points.isEmpty) {
      setState(() {
        _polylines = [];
        _markers = [];
        _bounds = null;
      });
      return;
    }
    if (_points.length > 1) {
      _bounds = LatLngBounds.fromPoints(
          _points.map((p) => LatLng(p.lat, p.lon)).toList());
    }
    final List<Polyline> segmentedPolylines = [];
    final List<Marker> allMarkers = [];
    if (_points.length > 1) {
      int colorIndex = 0;
      List<LatLng> currentSegmentPoints = [
        LatLng(_points.first.lat, _points.first.lon)
      ];
      for (int i = 1; i < _points.length; i++) {
        final currentPoint = _points[i];
        final previousPoint = _points[i - 1];
        final segmentColor = BaseMapView
            .segmentColors[colorIndex % BaseMapView.segmentColors.length];
        allMarkers.add(_createTrackPointMarker(previousPoint, segmentColor));
        final timeDifference =
            currentPoint.dataTime.difference(previousPoint.dataTime);
        bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
            currentPoint.goBack != previousPoint.goBack ||
            timeDifference.inMinutes >= 10);
        if (isSegmentEnd) {
          segmentedPolylines.add(Polyline(
              points: List.from(currentSegmentPoints),
              color: segmentColor,
              strokeWidth: 4));
          colorIndex++;
          currentSegmentPoints = [
            LatLng(previousPoint.lat, previousPoint.lon),
            LatLng(currentPoint.lat, currentPoint.lon)
          ];
        } else {
          currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
        }
      }
      final lastSegmentColor = BaseMapView
          .segmentColors[colorIndex % BaseMapView.segmentColors.length];
      if (currentSegmentPoints.length > 1) {
        segmentedPolylines.add(Polyline(
            points: currentSegmentPoints,
            color: lastSegmentColor,
            strokeWidth: 4));
      }
    }
    if (_points.isNotEmpty) {
      allMarkers.add(_createStartMarker(_points.first));
      allMarkers.add(_createCurrentLocationMarker(_points.last));
    }
    setState(() {
      _polylines = segmentedPolylines;
      _markers = allMarkers;
    });
  }

  PointMarker _createTrackPointMarker(BusPoint point, Color color) {
    return PointMarker(
      busPoint: point,
      width: 14,
      height: 14,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }

  PointMarker _createStartMarker(BusPoint point) {
    return PointMarker(
      busPoint: point,
      width: 32,
      height: 32,
      child: const Icon(
        Icons.flag_circle_rounded,
        color: Colors.greenAccent,
        size: 32,
        shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
      ),
    );
  }

  Marker _createCurrentLocationMarker(BusPoint point) {
    return PointMarker(
      busPoint: point,
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.7, end: 0.0)
                .animate(_animationController),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.3, end: 1.0)
                  .animate(_animationController),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BaseMapView(
      appBarTitle: '${widget.plate} 即時位置',
      appBarActions: [
        if (_lastFetchTime != null)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '更新於：${TimeOfDay.fromDateTime(_lastFetchTime!).format(context)}\n（每分鐘更新）',
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
      isLoading: _isLoading,
      error: _error,
      points: _points,
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
    );
  }
}
