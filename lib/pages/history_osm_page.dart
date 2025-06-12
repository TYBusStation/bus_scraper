// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../utils/map_data_processor.dart';
import '../widgets/base_map_view.dart';

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final List<BusPoint> points;

  // *** NEW ***: 新增可選的背景點位參數
  final List<BusPoint>? backgroundPoints;

  const HistoryOsmPage({
    super.key,
    required this.plate,
    required this.points,
    this.backgroundPoints, // *** NEW ***
  });

  @override
  State<HistoryOsmPage> createState() => _HistoryOsmPageState();
}

class _HistoryOsmPageState extends State<HistoryOsmPage> {
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    _prepareMapData();
  }

  /// *** MODIFIED ***: 準備 Polyline 和 Marker 數據的完整重構邏輯
  void _prepareMapData() {
    // 如果主要點位和背景點位都為空，則不執行任何操作
    if (widget.points.isEmpty && (widget.backgroundPoints?.isEmpty ?? true)) {
      return;
    }

    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];

    // --- 1. 處理背景軌跡 (如果存在) ---
    // 這些是被篩選掉的點位，將繪製成虛線且無標記
    if (widget.backgroundPoints != null &&
        widget.backgroundPoints!.isNotEmpty) {
      final backgroundLatLatLngs =
          widget.backgroundPoints!.map((p) => LatLng(p.lat, p.lon)).toList();

      allPolylines.add(
        Polyline(
          points: backgroundLatLatLngs,
          color: Colors.grey,
          strokeWidth: 3.0,
          pattern: const StrokePattern.dotted(),
        ),
      );
    }

    // --- 2. 處理主要軌跡 (篩選後的結果) ---
    if (widget.points.isNotEmpty) {
      // 調用共享處理器來生成主要軌跡線和通用標記 (如速度變化)
      final processedData = processBusPoints(widget.points);

      // 添加處理器生成的主要軌跡線和標記
      allPolylines.addAll(processedData.polylines);
      allMarkers.addAll(processedData.markers);

      // --- 為主要軌跡添加特有的起點和終點標記 ---
      if (widget.points.length == 1) {
        allMarkers.add(_createSinglePointMarker(widget.points.first));
      } else {
        allMarkers
            .add(_createStartEndMarker(widget.points.first, isStart: true));
        allMarkers
            .add(_createStartEndMarker(widget.points.last, isStart: false));
      }
    }

    // --- 3. 計算包含所有點位的邊界 ---
    final List<BusPoint> allPointsForBounds = [
      ...widget.points,
      ...(widget.backgroundPoints ?? [])
    ];
    final LatLngBounds? calculatedBounds = allPointsForBounds.isNotEmpty
        ? LatLngBounds.fromPoints(
            allPointsForBounds.map((p) => LatLng(p.lat, p.lon)).toList())
        : null;

    // 更新狀態以觸發 build
    setState(() {
      _polylines = allPolylines;
      _markers = allMarkers;
      _bounds = calculatedBounds;
    });
  }

  // --- Marker 創建方法 (無需修改) ---
  PointMarker _createSinglePointMarker(BusPoint point) {
    return PointMarker(
      busPoint: point,
      width: 40,
      height: 40,
      child: const Icon(Icons.directions_bus, color: Colors.pink, size: 40),
    );
  }

  PointMarker _createStartEndMarker(BusPoint point, {required bool isStart}) {
    return PointMarker(
      busPoint: point,
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isStart ? Colors.green : Colors.red).withAlpha(50),
            ),
          ),
          Icon(
            isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded,
            color: isStart
                ? Colors.greenAccent.shade700
                : Colors.redAccent.shade700,
            size: 32,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // *** MODIFIED ***: 檢查所有可能的點位
    final bool hasData = widget.points.isNotEmpty ||
        (widget.backgroundPoints?.isNotEmpty ?? false);

    if (!hasData) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.plate} 軌跡地圖')),
        body: const Center(child: Text('沒有可顯示的點位數據。')),
      );
    }

    // 將所有準備好的數據傳遞給 BaseMapView
    return BaseMapView(
      appBarTitle: '${widget.plate} 軌跡地圖',
      isLoading: false,
      error: null,
      // *** MODIFIED ***: 傳遞所有點位給 BaseMapView, 方便其內部可能的功能使用
      points: [...widget.points, ...(widget.backgroundPoints ?? [])],
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
    );
  }
}
