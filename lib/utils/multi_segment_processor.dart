// lib/utils/multi_segment_processor.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../pages/history_page.dart';
import '../widgets/point_marker.dart'; // 為了 TrajectorySegment

/// 一個帶有狀態的處理器，用於為多個獨立的軌跡段生成帶有不同顏色的地圖元素。
class MultiSegmentProcessor {
  // 複製 BaseMapView 中的顏色列表，使其自成一體
  static const List<Color> _segmentColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF00897B),
    Color(0xFF5E35B1),
    Color(0xFFFFB300),
    Color(0xFF039BE5),
    Color(0xFF6D4C41),
    Color(0xFFF4511E),
    Color(0xFFC0CA33),
    Color(0xFF00ACC1),
    Color(0xFF7CB342),
    Color(0xFF673AB7),
    Color(0xFF455A64),
  ];

  int _colorIndex = 0;

  /// 處理單個軌跡段，並將生成的 Polyline 和 Marker 添加到傳入的列表中。
  void processAndAdd(
    TrajectorySegment segment, {
    required List<Polyline> polylines,
    required List<Marker> markers,
  }) {
    if (segment.points.isEmpty) {
      return;
    }

    // 1. 為整個軌跡段創建一條單色的 Polyline
    final color = _segmentColors[_colorIndex % _segmentColors.length];
    polylines.add(
      Polyline(
        points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
        color: color.withOpacity(0.8), // 使用指定的顏色
        strokeWidth: 5.0,
      ),
    );

    // 2. 為這個軌跡段添加起點和終點標記
    if (segment.points.length == 1) {
      markers.add(_createSinglePointMarker(segment.points.first, color));
    } else {
      markers.add(_createStartEndMarker(segment.points.first,
          isStart: true, color: color));
      markers.add(_createStartEndMarker(segment.points.last,
          isStart: false, color: color));
    }

    // 3. 更新顏色索引，為下一個軌跡段做準備
    _colorIndex++;
  }

  // --- Marker 創建輔助方法 ---

  PointMarker _createSinglePointMarker(BusPoint point, Color color) {
    return PointMarker(
      busPoint: point,
      width: 40,
      height: 40,
      child: Icon(Icons.directions_bus, color: color, size: 40),
    );
  }

  PointMarker _createStartEndMarker(BusPoint point,
      {required bool isStart, required Color color}) {
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
              color: color.withAlpha(50),
            ),
          ),
          Icon(
            isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded,
            color: color,
            size: 32,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
          ),
        ],
      ),
    );
  }
}
