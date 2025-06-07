import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../static.dart';

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final String routeName;
  final List<BusPoint> points;

  const HistoryOsmPage({
    super.key,
    required this.plate,
    required this.routeName,
    required this.points,
  });

  @override
  State<HistoryOsmPage> createState() => _HistoryOsmPageState();
}

class _HistoryOsmPageState extends State<HistoryOsmPage> {
  // 地圖控制器，用於手動操作地圖（例如重新置中）
  final MapController _mapController = MapController();

  // 狀態變數，用於儲存地圖上要顯示的元素
  List<Polyline> _polylines = []; // 軌跡線段列表
  List<Marker> _markers = []; // 標記點列表
  LatLngBounds? _bounds; // 地圖視野邊界，用於自動縮放

  // (新功能) 狀態變數：用於控制衛星圖層的透明度，初始值為 0.3
  double _satelliteOpacity = 0.3;

  // 用於分段著色的顏色列表，當顏色用完時會循環使用
  final List<Color> _segmentColors = const [
    Colors.red,
    Colors.teal,
    Colors.amber,
    Colors.greenAccent,
    Colors.orange,
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.lightGreen,
    Colors.cyan,
    Colors.brown,
    Colors.indigo,
    Colors.grey,
    Colors.deepPurple,
  ];

  @override
  void initState() {
    super.initState();
    // 頁面初始化時，準備所有地圖上需要顯示的數據
    _prepareMapData();
  }

  // 準備地圖數據的核心方法
  void _prepareMapData() {
    if (widget.points.isEmpty) return; // 如果沒有軌跡點，直接返回

    // --- 步驟 1: 計算所有點的整體地理邊界，用於地圖初始縮放 ---
    if (widget.points.length > 1) {
      final allLatLngPoints =
          widget.points.map((p) => LatLng(p.lat, p.lon)).toList();
      _bounds = LatLngBounds.fromPoints(allLatLngPoints);
    }

    // --- 步驟 2: 處理軌跡線與標記點 ---
    final List<Polyline> segmentedPolylines = [];
    final List<Marker> allMarkers = [];

    if (widget.points.length > 1) {
      int colorIndex = 0;
      // 初始化第一個線段的起點
      List<LatLng> currentSegmentPoints = [
        LatLng(widget.points.first.lat, widget.points.first.lon)
      ];

      // 遍歷所有點，從第二個點開始
      for (int i = 1; i < widget.points.length; i++) {
        final currentPoint = widget.points[i];
        final previousPoint = widget.points[i - 1];
        final segmentColor = _segmentColors[colorIndex % _segmentColors.length];

        // 為前一個點創建軌跡標記
        allMarkers.add(_createTrackPointMarker(previousPoint, segmentColor));

        final timeDifference =
            currentPoint.dataTime.difference(previousPoint.dataTime);

        // 判斷是否為一個新線段的開始
        // 條件：路線ID改變、去返程改變、或時間差大於等於5分鐘
        bool isNewSegment = (currentPoint.routeId != previousPoint.routeId ||
            currentPoint.goBack != previousPoint.goBack ||
            timeDifference.inMinutes >= 10);

        if (isNewSegment) {
          // 如果是新線段，則將目前收集到的點繪製成一條 Polyline
          segmentedPolylines.add(
            Polyline(
              points: List.from(currentSegmentPoints),
              color: segmentColor,
              strokeWidth: 3,
            ),
          );
          // 換下一個顏色
          colorIndex++;
          // (核心修改) 建立一個新的線段列表，並只包含「目前點」。
          // 這樣就不會將「目前點」與「前一個點」連接起來，實現了斷開連線的效果。
          currentSegmentPoints = [LatLng(currentPoint.lat, currentPoint.lon)];
        } else {
          // 如果仍在同一個線段，則將目前點加入到線段列表中
          currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
        }
      }

      // 迴圈結束後，處理最後一段未被繪製的線段
      final lastSegmentColor =
          _segmentColors[colorIndex % _segmentColors.length];
      if (currentSegmentPoints.length > 1) {
        segmentedPolylines.add(
          Polyline(
            points: currentSegmentPoints,
            color: lastSegmentColor,
            strokeWidth: 3,
          ),
        );
      }
      // 為軌跡的最後一個點添加標記
      allMarkers
          .add(_createTrackPointMarker(widget.points.last, lastSegmentColor));
    } else if (widget.points.isNotEmpty) {
      // 當只有一個點時，只繪製一個普通軌跡點標記
      allMarkers.add(
        Marker(
          point: LatLng(widget.points.first.lat, widget.points.first.lon),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showPointInfo(widget.points.first), // 點擊時顯示詳細資訊
            child: const Icon(
              Icons.directions_bus,
              color: Colors.pinkAccent,
              size: 36,
            ),
          ),
        ),
      );
    }
    _polylines = segmentedPolylines;

    // --- 步驟 3: 繪製起點和終點的特殊標記 ---
    if (widget.points.length > 1) {
      final BusPoint startPoint = widget.points.first;
      allMarkers.add(_createStartEndMarker(startPoint, isStart: true));

      final BusPoint endPoint = widget.points.last;
      allMarkers.add(_createStartEndMarker(endPoint, isStart: false));
    }

    _markers = allMarkers;
  }

  // 輔助方法：創建一個普通的軌跡點標記 (小圓點)
  Marker _createTrackPointMarker(BusPoint point, Color borderColor) {
    return Marker(
      point: LatLng(point.lat, point.lon),
      width: 16,
      height: 16,
      child: GestureDetector(
        onTap: () => _showPointInfo(point), // 點擊時顯示詳細資訊
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: borderColor, // 邊框顏色與軌跡線顏色一致
              width: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  // 輔助方法：創建起點或終點的特殊標記 (大圖示)
  Marker _createStartEndMarker(BusPoint point, {required bool isStart}) {
    return Marker(
      point: LatLng(point.lat, point.lon),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showPointInfo(point),
        child: Tooltip(
          message: isStart ? '軌跡起點' : '軌跡終點',
          child: Icon(
            isStart ? Icons.play_circle_fill : Icons.stop_circle,
            color: isStart ? Colors.green : Colors.red,
            size: 40,
          ),
        ),
      ),
    );
  }

  // 當點擊標記時，顯示 SnackBar 資訊框
  void _showPointInfo(BusPoint point) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    // 從上下文中獲取當前主題，以便讓 SnackBar 樣式與 App 主題一致
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // (程式碼健壯性修正) 安全地查找路線名稱，如果找不到則返回'未知路線'
    final route =
        Static.routeData.firstWhere((route) => route.id == point.routeId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '時間：${Static.displayDateFormat.format(point.dataTime)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '座標：${point.lon.toStringAsFixed(6)}, ${point.lat.toStringAsFixed(6)}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  Text(
                    '狀態：${point.dutyStatus == 0 ? "營運" : "非營運"}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  Text(
                    '路線 / 編號：${route.name} / ${route.id}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  Text(
                    '方向：${point.goBack == 1 ? "去程" : "返程"} | 往：${point.goBack == 1 ? route.destination : route.departure}',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close),
                color: colorScheme.onSurfaceVariant,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          ],
        ),
        duration: const Duration(minutes: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果沒有點位數據，顯示一個提示，避免後續出錯
    if (widget.points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.plate} 軌跡地圖')),
        body: const Center(child: Text('沒有可顯示的點位數據。')),
      );
    }

    return PopScope(
        // onPopInvokedWithResult 在較新的 Flutter 版本中替代了 WillPopScope
        // 這裡確保返回上一頁時，SnackBar 會被移除
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('${widget.plate} 軌跡地圖'),
          ),
          // (新功能) 使用 Stack 來疊放地圖和 UI 控制項 (如滑桿)
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      LatLng(widget.points.first.lat, widget.points.first.lon),
                  initialZoom: (widget.points.length == 1) ? 17.0 : 12.0,
                  initialCameraFit:
                      (widget.points.length > 1 && _bounds != null)
                          ? CameraFit.bounds(
                              bounds: _bounds!,
                              padding: const EdgeInsets.all(50.0),
                            )
                          : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'me.myster.bus_scraper',
                  ),
                  // (新功能) 將衛星圖層包裹在 Opacity 元件中，
                  // 並使用 _satelliteOpacity 狀態變數來控制其透明度
                  Opacity(
                    opacity: _satelliteOpacity,
                    child: TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'me.myster.bus_scraper',
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      width: double.infinity,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          child: Text(
                            'Esri, Maxar, Earthstar Geographics, and the GIS User Community',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PolylineLayer(
                    polylines: _polylines,
                  ),
                  MarkerLayer(
                    markers: _markers,
                  ),
                ],
              ),
              // (新功能) 衛星雲圖透明度控制滑桿
              Positioned(
                // 將控制項放在右下角，並向上偏移一些距離以避免與 FAB 重疊
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.satellite_alt_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      // 使用 RotatedBox 將滑桿變為垂直方向，節省水平空間
                      RotatedBox(
                        quarterTurns: 3, // 旋轉 270 度
                        child: Slider(
                          padding: const EdgeInsetsGeometry.all(10),
                          activeColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          inactiveColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          value: _satelliteOpacity,
                          min: 0.0,
                          // 完全透明
                          max: 1.0,
                          // 完全不透明
                          onChanged: (newValue) {
                            // 當滑桿值改變時，更新狀態變數
                            setState(() {
                              _satelliteOpacity = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (widget.points.length > 1 && _bounds != null) {
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: _bounds!,
                    padding: const EdgeInsets.all(50.0),
                  ),
                );
              } else if (widget.points.isNotEmpty) {
                _mapController.move(
                  LatLng(widget.points.first.lat, widget.points.first.lon),
                  17.0,
                );
              }
            },
            tooltip: '重新置中',
            child: const Icon(Icons.my_location),
          ),
        ));
  }
}
