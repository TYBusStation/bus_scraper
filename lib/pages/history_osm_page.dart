// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 僅 Marker 需要
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../widgets/base_map_view.dart'; // 引入新的共享 Widget

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final List<BusPoint> points;

  const HistoryOsmPage({super.key, required this.plate, required this.points});

  @override
  State<HistoryOsmPage> createState() => _HistoryOsmPageState();
}

class _HistoryOsmPageState extends State<HistoryOsmPage> {
  // --- 地圖數據 ---
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

  @override
  void initState() {
    super.initState();
    // 在初始化時一次性準備好所有地圖數據
    _prepareMapData();
  }

  /// 準備 Polyline 和 Marker 數據
  void _prepareMapData() {
    if (widget.points.isEmpty) return;

    if (widget.points.length > 1) {
      _bounds = LatLngBounds.fromPoints(
          widget.points.map((p) => LatLng(p.lat, p.lon)).toList());
    }

    final List<Polyline> segmentedPolylines = [];
    final List<Marker> allMarkers = [];

    // --- 軌跡線和軌跡點 ---
    if (widget.points.length > 1) {
      int colorIndex = 0;
      List<LatLng> currentSegmentPoints = [
        LatLng(widget.points.first.lat, widget.points.first.lon)
      ];
      for (int i = 1; i < widget.points.length; i++) {
        final currentPoint = widget.points[i];
        final previousPoint = widget.points[i - 1];
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
      allMarkers
          .add(_createTrackPointMarker(widget.points.last, lastSegmentColor));
    } else if (widget.points.isNotEmpty) {
      allMarkers.add(_createSinglePointMarker(widget.points.first));
    }

    // --- 起點和終點的特殊標記 ---
    if (widget.points.length > 1) {
      allMarkers.add(_createStartEndMarker(widget.points.first, isStart: true));
      allMarkers.add(_createStartEndMarker(widget.points.last, isStart: false));
    }

    // 更新狀態以觸發 build
    setState(() {
      _polylines = segmentedPolylines;
      _markers = allMarkers;
    });
  }

  // --- Marker 創建方法 (特定於 History 頁面) ---
  // 同樣，這些方法是此頁面的特殊實現，所以保留下來。
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
      // 歷史頁面沒有加載狀態
      error: null,
      points: widget.points,
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
    );
  }
}
