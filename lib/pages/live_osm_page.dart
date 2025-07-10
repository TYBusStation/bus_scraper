// lib/pages/live_osm_page.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

import '../data/bus_point.dart';
import '../static.dart';
import '../utils/map_data_processor.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

const Duration _kRefreshInterval = Duration(seconds: 30);

class LiveOsmPage extends StatefulWidget {
  final String plate;

  const LiveOsmPage({super.key, required this.plate});

  @override
  State<LiveOsmPage> createState() => _LiveOsmPageState();
}

class _LiveOsmPageState extends State<LiveOsmPage>
    with TickerProviderStateMixin {
  Timer? _refreshTimer;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchTime;
  DateTime? _lastPointTime;

  List<BusPoint> _points = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

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

    restartTimer();
  }

  void restartTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
        _kRefreshInterval, (_) async => await _fetchAndDrawMap());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationAnimationController.dispose();
    _timerAnimationController.dispose();
    super.dispose();
  }

  // *** 新增：用於關閉錯誤提示框的方法 ***
  void _dismissError() {
    setState(() {
      _error = null;
    });
  }

  Future<void> _fetchAndDrawMap({bool isInitialLoad = false}) async {
    // 如果是自動刷新，先清除舊錯誤
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
      // --- 變更 1: 查詢開始時間從 1 小時前改為 20 分鐘前 ---
      final startTime = isInitialLoad || _lastPointTime == null
          ? endTime.subtract(const Duration(minutes: 20))
          : _lastPointTime!;

      final formattedStartTime = Static.apiDateFormat.format(startTime);
      final formattedEndTime = Static.apiDateFormat.format(endTime);

      final url = Uri.parse(
          "${Static.apiBaseUrl}/${Static.localStorage.city}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      final response = await Static.dio.getUri(url);

      if (!mounted) return;

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;
        final newPoints = decodedData
            .map((item) => BusPoint.fromJson(item))
            .toList()
            .toList();

        if (isInitialLoad) {
          _points = newPoints;
        } else {
          _points.addAll(newPoints);
          // --- 變更 2: 清除舊點位的基準從 1 小時前改為 20 分鐘前 ---
          final twentyMinutesAgo =
              DateTime.now().subtract(const Duration(minutes: 20));
          _points.removeWhere(
              (point) => point.dataTime.isBefore(twentyMinutesAgo));
        }

        if (_points.isNotEmpty) {
          _lastPointTime = _points.last.dataTime;
        }

        _prepareMapData();

        String? newError;
        if (_points.isEmpty) {
          // --- 變更 3: 更新錯誤訊息 ---
          newError = "過去 20 分鐘内沒有找到軌跡資料。";
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
        throw DioException(
            requestOptions: response.requestOptions, response: response);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response != null) {
        if (e.response!.statusCode == 404) {
          _points.clear();
          _prepareMapData();
          setState(() {
            // --- 變更 4: 更新 404 錯誤訊息 ---
            _error = "過去 20 分鐘内沒有找到軌跡資料。";
            _isLoading = false;
            _lastFetchTime = DateTime.now();
          });
        } else {
          setState(() {
            _error = "數據獲取失敗: ${e.response!.statusCode}";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = "網絡連線失敗，請檢查您的網絡設定。";
          _isLoading = false;
        });
      }
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

  void _prepareMapData() {
    final processedData = processBusPoints(_points);
    final List<Marker> allMarkers = processedData.markers;

    if (_points.isNotEmpty) {
      if (allMarkers.isNotEmpty) allMarkers.removeAt(0);
      allMarkers.insert(0, _createStartMarker(_points.first));

      if (allMarkers.length > 1) allMarkers.removeLast();
      allMarkers.add(_createCurrentLocationMarker(_points.last));
    }

    setState(() {
      _polylines = processedData.polylines;
      _markers = allMarkers;
      _bounds = processedData.bounds;
    });
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
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: Text('${widget.plate} 動態'),
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
                            InkWell(
                              onTap: () async {
                                await _fetchAndDrawMap();
                                restartTimer();
                              },
                              child: const Icon(Icons.refresh),
                            ),
                            const SizedBox(width: 4),
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
    return Scaffold(
      appBar: _buildAppBar(context),
      body: BaseMapView(
        appBarTitle: '',
        hideAppBar: true,
        isLoading: _isLoading,
        error: _error,
        points: _points,
        polylines: _polylines,
        markers: _markers,
        bounds: _isFirstLoadComplete ? _bounds : null,
        // *** 核心修改：將關閉錯誤的方法傳遞給 BaseMapView ***
        onErrorDismiss: _dismissError,
      ),
    );
  }
}
