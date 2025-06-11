// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/bus_point.dart';
import '../utils/map_data_processor.dart';
import '../widgets/base_map_view.dart';

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final List<BusPoint> points;

  const HistoryOsmPage({super.key, required this.plate, required this.points});

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

  /// 準備 Polyline 和 Marker 數據
  void _prepareMapData() {
    if (widget.points.isEmpty) return;

    // 調用共享處理器
    final processedData = processBusPoints(widget.points);
    final List<Marker> allMarkers = processedData.markers; // 從通用軌跡點開始

    // --- 添加此頁面特有的標記 ---
    if (widget.points.length == 1) {
      // 只有一個點的特殊情況
      allMarkers.add(_createSinglePointMarker(widget.points.first));
    } else {
      // 多個點，添加起點和終點標記
      allMarkers.add(_createStartEndMarker(widget.points.first, isStart: true));
      allMarkers.add(_createStartEndMarker(widget.points.last, isStart: false));
    }

    // 更新狀態以觸發 build
    setState(() {
      _polylines = processedData.polylines;
      _markers = allMarkers;
      _bounds = processedData.bounds;
    });
  }

  // --- Marker 創建方法 (特定於 History 頁面) ---
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
    if (widget.points.isEmpty) {
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
      points: widget.points,
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
    );
  }
}
