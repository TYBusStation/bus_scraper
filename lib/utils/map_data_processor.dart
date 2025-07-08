// lib/utils/map_data_processor.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

/// 一個用於存儲處理後的地圖數據的容器類。
class ProcessedMapData {
  final List<Polyline> polylines;
  final List<Marker> markers;
  final LatLngBounds? bounds;

  ProcessedMapData({
    required this.polylines,
    required this.markers,
    this.bounds,
  });
}

/// 核心地圖數據處理器。
/// 接收一個 BusPoint 列表，並返回繪製地圖所需的 Polylines, Markers 和 Bounds。
ProcessedMapData processBusPoints(List<BusPoint> points) {
  if (points.isEmpty) {
    return ProcessedMapData(polylines: [], markers: [], bounds: null);
  }

  // 計算邊界
  final bounds = points.length > 1
      ? LatLngBounds.fromPoints(
      points.map((p) => LatLng(p.lat, p.lon)).toList())
      : null;

  final List<Polyline> segmentedPolylines = [];
  final List<Marker> trackPointMarkers = [];

  // --- [MODIFICATION START] ---
  // 重構軌跡線和軌跡點的處理邏輯，以確保每個斷開的段都有獨立的顏色。
  if (points.length > 1) {
    int colorIndex = 0;
    List<LatLng> currentSegmentPoints = [
      LatLng(points.first.lat, points.first.lon)
    ];

    // 為第一個點創建標記，使用初始顏色
    trackPointMarkers.add(_createTrackPointMarker(points.first,
        BaseMapView.segmentColors[colorIndex % BaseMapView.segmentColors.length]));

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final previousPoint = points[i - 1];

      final timeDifference =
      currentPoint.dataTime.difference(previousPoint.dataTime);

      // 當路線ID、方向、營運狀態、駕駛員ID改變，或時間間隔過長時，切分新段
      final bool isNewSegment = (currentPoint.routeId != previousPoint.routeId ||
          currentPoint.goBack != previousPoint.goBack ||
          currentPoint.dutyStatus != previousPoint.dutyStatus ||
          currentPoint.driverId != previousPoint.driverId ||
          timeDifference.inMinutes >= 10);

      if (isNewSegment) {
        // 1. 結束並繪製上一個軌跡段
        if (currentSegmentPoints.length > 1) {
          final color = BaseMapView.segmentColors[colorIndex % BaseMapView.segmentColors.length];
          segmentedPolylines.add(Polyline(
            points: List.from(currentSegmentPoints),
            color: color,
            strokeWidth: 4,
          ));
        }

        // 2. 為新軌跡段更新顏色索引
        colorIndex++;

        // 3. 開始一個新的軌跡段，從上一個點連接到當前點
        currentSegmentPoints = [
          LatLng(previousPoint.lat, previousPoint.lon),
          LatLng(currentPoint.lat, currentPoint.lon),
        ];
      } else {
        // 繼續當前的軌跡段
        currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
      }

      // 為每個點創建標記，使用其所屬軌跡段的顏色
      final markerColor = BaseMapView.segmentColors[colorIndex % BaseMapView.segmentColors.length];
      trackPointMarkers.add(_createTrackPointMarker(currentPoint, markerColor));
    }

    // 添加最後一段正在累積的軌跡線
    if (currentSegmentPoints.length > 1) {
      final lastSegmentColor = BaseMapView.segmentColors[colorIndex % BaseMapView.segmentColors.length];
      segmentedPolylines.add(Polyline(
        points: currentSegmentPoints,
        color: lastSegmentColor,
        strokeWidth: 4,
      ));
    }
  } else {
    // 只有一個點的情況
    final color = BaseMapView.segmentColors[0];
    trackPointMarkers.add(_createTrackPointMarker(points.first, color));
  }
  // --- [MODIFICATION END] ---

  return ProcessedMapData(
    polylines: segmentedPolylines,
    markers: trackPointMarkers,
    bounds: bounds,
  );
}

/// 創建通用的軌跡點標記 (小圓點)
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