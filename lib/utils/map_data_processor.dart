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

  // --- 軌跡線和軌跡點 ---
  if (points.length > 1) {
    int colorIndex = 0;
    List<LatLng> currentSegmentPoints = [
      LatLng(points.first.lat, points.first.lon)
    ];

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final previousPoint = points[i - 1];
      final segmentColor = BaseMapView
          .segmentColors[colorIndex % BaseMapView.segmentColors.length];

      // 為前一個點創建軌跡點標記
      trackPointMarkers
          .add(_createTrackPointMarker(previousPoint, segmentColor));

      final timeDifference =
          currentPoint.dataTime.difference(previousPoint.dataTime);

      // 當路線ID、方向、營運狀態、駕駛員ID改變，或時間間隔過長時，切分新段
      bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
          currentPoint.goBack != previousPoint.goBack ||
          currentPoint.dutyStatus != previousPoint.dutyStatus ||
          currentPoint.driverId != previousPoint.driverId ||
          timeDifference.inMinutes >= 10);

      if (isSegmentEnd) {
        // 結束當前段
        if (currentSegmentPoints.length > 1) {
          segmentedPolylines.add(Polyline(
            points: List.from(currentSegmentPoints),
            color: segmentColor,
            strokeWidth: 4,
          ));
        }
        // 開始新段
        colorIndex++;
        currentSegmentPoints = [
          LatLng(previousPoint.lat, previousPoint.lon), // 連接斷點
          LatLng(currentPoint.lat, currentPoint.lon),
        ];
      } else {
        // 繼續當前段
        currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
      }
    }

    // 添加最後一段軌跡線
    final lastSegmentColor = BaseMapView
        .segmentColors[colorIndex % BaseMapView.segmentColors.length];
    if (currentSegmentPoints.length > 1) {
      segmentedPolylines.add(Polyline(
        points: currentSegmentPoints,
        color: lastSegmentColor,
        strokeWidth: 4,
      ));
    }

    // 為最後一個點創建軌跡點標記
    trackPointMarkers
        .add(_createTrackPointMarker(points.last, lastSegmentColor));
  }

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
