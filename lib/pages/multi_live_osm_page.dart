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

  // 使用 Map 來儲存每輛車的數據和最後更新時間
  final Map<String, List<BusPoint>> _pointsByPlate = {};
  final Map<String, DateTime> _lastPointTimeByPlate = {};

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

      // 為每個車牌創建一個異步請求
      final futures = widget.plates.map((plate) async {
        final lastPointTime = _lastPointTimeByPlate[plate];
        // --- 變更 1: 查詢開始時間從 1 小時前改為 20 分鐘前 ---
        final startTime = isInitialLoad || lastPointTime == null
            ? endTime.subtract(const Duration(minutes: 20))
            : lastPointTime;

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
        return {'plate': plate, 'points': <BusPoint>[]}; // 失敗或404時返回空列表
      });

      // 使用 Future.wait 等待所有請求完成
      final results = await Future.wait(futures);
      if (!mounted) return;

      // 處理所有請求的結果
      for (var result in results) {
        final plate = result['plate'] as String;
        final newPoints = result['points'] as List<BusPoint>;

        if (isInitialLoad) {
          _pointsByPlate[plate] = newPoints;
        } else {
          _pointsByPlate.putIfAbsent(plate, () => []).addAll(newPoints);
          // --- 變更 2: 清除舊點位的基準從 1 小時前改為 20 分鐘前 ---
          final twentyMinutesAgo =
              DateTime.now().subtract(const Duration(minutes: 20));
          _pointsByPlate[plate]
              ?.removeWhere((p) => p.dataTime.isBefore(twentyMinutesAgo));
        }

        if (_pointsByPlate[plate]?.isNotEmpty ?? false) {
          _lastPointTimeByPlate[plate] = _pointsByPlate[plate]!.last.dataTime;
        }
      }

      _prepareMapData();

      // 檢查是否有任何車輛數據，並設定錯誤訊息
      final allPoints =
          _pointsByPlate.values.expand((points) => points).toList();
      String? newError;
      if (allPoints.isEmpty) {
        // --- 變更 3: 更新錯誤訊息 ---
        newError = "過去 20 分鐘内沒有找到任何收藏車輛的軌跡資料。";
      } else if (errorPlates.isNotEmpty) {
        newError = "部分車輛資料獲取失敗。"; // 訊息可以更精確一點
      }

      setState(() {
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

  // =========================================================================
  // ===                         核心修改在此方法                         ===
  // =========================================================================
  void _prepareMapData() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    final List<LatLng> allPointsForBounds = [];

    // **核心修改 1: 定義一個全域顏色索引**
    // 這個索引將在所有車輛的所有軌跡段之間共享和遞增。
    int globalColorIndex = 0;

    _pointsByPlate.forEach((plate, points) {
      if (points.isEmpty) return;

      // 1. 正常處理單一車輛的點位，獲取其軌跡段
      final processedData = processBusPoints(points);

      // **核心修改 2: 為當前車輛的軌跡段重新上色**
      // 我們不直接使用 processedData.polylines，而是創建一個新的列表。
      final List<Polyline> vehicleRecoloredPolylines = [];
      for (final originalPolyline in processedData.polylines) {
        // 使用全域索引來獲取顏色
        final newColor = BaseMapView
            .segmentColors[globalColorIndex % BaseMapView.segmentColors.length];

        // 創建一個帶有新顏色的 Polyline 物件
        vehicleRecoloredPolylines.add(
          Polyline(
            points: originalPolyline.points,
            color: newColor,
            strokeWidth: originalPolyline.strokeWidth,
          ),
        );
        // 每處理一個軌跡段，索引就加一
        globalColorIndex++;
      }

      // 將重新上色後的軌跡線加入到總列表中
      allPolylines.addAll(vehicleRecoloredPolylines);

      // **核心修改 3: 創建 Marker 時，從重新上色後的軌跡線獲取顏色**
      for (final point in points) {
        // 找到這個點對應的顏色，但這次是從我們自己創建的 `vehicleRecoloredPolylines` 列表中查找
        final segmentColor = vehicleRecoloredPolylines
            .lastWhere(
                (polyline) =>
                    polyline.points.contains(LatLng(point.lat, point.lon)),
                orElse: () => Polyline(
                    points: [], color: BaseMapView.segmentColors.first))
            .color;

        // 創建軌跡點 Marker，並添加 GestureDetector
        allMarkers.add(
          PointMarker(
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
                  color: segmentColor, // 使用正確的連續顏色
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // 添加當前位置的 Marker (這部分邏輯不變)
      final lastPoint = points.last;
      allMarkers.add(Marker(
          point: LatLng(lastPoint.lat, lastPoint.lon),
          width: 110,
          height: 110,
          alignment: const Alignment(0.0, 0.23),
          child: GestureDetector(
            onTap: () {
              _baseMapStateKey.currentState
                  ?.selectPoint(lastPoint, plate: plate);
            },
            child: _buildCurrentLocationMarkerContent(lastPoint, plate),
          )));

      allPointsForBounds.addAll(points.map((p) => LatLng(p.lat, p.lon)));
    });

    setState(() {
      _polylines = allPolylines;
      _markers = allMarkers;
      _bounds = allPointsForBounds.isNotEmpty
          ? LatLngBounds.fromPoints(allPointsForBounds)
          : null;
    });
  }

  // **新增: 將創建 Marker 內容的邏輯抽離出來**
  Widget _buildCurrentLocationMarkerContent(BusPoint point, String plate) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 車牌標籤
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
        // 動畫和巴士圖標
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 擴散動畫效果
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
              // 中間的藍色圓點
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
              // 巴士圖標
              const Icon(Icons.directions_bus, color: Colors.white, size: 24),
            ],
          ),
        ),
      ],
    );
  }

  // AppBar保持和 LiveOsmPage 類似，但標題不同
  AppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: const Text('收藏車輛即時位置'),
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
        polylines: _polylines,
        markers: _markers,
        bounds: _isFirstLoadComplete ? _bounds : null,
        onErrorDismiss: _dismissError,
      ),
    );
  }
}
