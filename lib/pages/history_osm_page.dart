// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../pages/history_page.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

/// 一個簡單的顏色循環器，以確保所有線條顏色連續且獨立。
class _ColorCycler {
  int _index = 0;

  Color get nextColor {
    final color =
        BaseMapView.segmentColors[_index % BaseMapView.segmentColors.length];
    _index++;
    return color;
  }
}

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final List<TrajectorySegment> segments;
  final List<TrajectorySegment>? backgroundSegments;
  final bool isFiltered;

  const HistoryOsmPage({
    super.key,
    required this.plate,
    required this.segments,
    this.backgroundSegments,
    required this.isFiltered,
  });

  @override
  State<HistoryOsmPage> createState() => _HistoryOsmPageState();
}

class _HistoryOsmPageState extends State<HistoryOsmPage> {
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;
  List<BusPoint> _allPointsForBounds = [];

  @override
  void initState() {
    super.initState();
    _prepareMapData();
  }

  void _prepareMapData() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    final _colorCycler = _ColorCycler();

    _allPointsForBounds = [
      ...widget.segments.expand((s) => s.points),
      ...(widget.backgroundSegments?.expand((s) => s.points) ?? []),
    ];

    if (_allPointsForBounds.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // --- 1. 處理背景軌跡段 (不變) ---
    if (widget.backgroundSegments != null) {
      for (final segment in widget.backgroundSegments!) {
        if (segment.points.isEmpty) continue;
        allPolylines.add(
          Polyline(
            points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
            color: Colors.black.withOpacity(0.5),
            strokeWidth: 3.0,
            pattern: const StrokePattern.dotted(),
          ),
        );
      }
    }

    // --- [MODIFICATION START] ---
    // 邏輯調整：
    // - 遍歷所有 segment，為每個 segment 生成彩色線條和軌跡點。
    // - 根據 isFiltered 狀態，決定如何添加起/終點旗幟。
    // - 如果未篩選，則在 segment 之間添加實線連接，形成連續軌跡。
    if (widget.segments.isNotEmpty) {
      for (int i = 0; i < widget.segments.length; i++) {
        final segment = widget.segments[i];
        if (segment.points.isEmpty) continue;

        final segmentColor = _colorCycler.nextColor;

        // 1. 為當前軌跡段創建彩色的 Polyline
        allPolylines.add(Polyline(
          points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
          color: segmentColor,
          strokeWidth: 4,
        ));

        // 2. 為當前軌跡段的所有點創建彩色的軌跡點標記 (小圓點)
        for (final point in segment.points) {
          allMarkers.add(_createTrackPointMarker(point, segmentColor));
        }

        // 3. 根據篩選狀態添加起/終點旗幟標記
        if (widget.isFiltered) {
          // A. 已篩選：每個軌跡段都有自己的起點和終點旗幟
          allMarkers
              .add(_createStartEndMarker(segment.points.first, isStart: true));
          allMarkers
              .add(_createStartEndMarker(segment.points.last, isStart: false));
        } else {
          // B. 未篩選：只為整個行程的絕對起點和終點添加旗幟
          if (i == 0) {
            // 這是第一個軌跡段，添加總起點旗幟
            allMarkers.add(
                _createStartEndMarker(segment.points.first, isStart: true));
          }
          if (i == widget.segments.length - 1) {
            // 這是最後一個軌跡段，添加總終點旗幟
            allMarkers.add(
                _createStartEndMarker(segment.points.last, isStart: false));
          }

          // C. 未篩選：在當前軌跡段和下一個軌跡段之間畫一條同色的實線，以形成連續視覺效果
          if (i < widget.segments.length - 1) {
            final nextSegment = widget.segments[i + 1];
            if (nextSegment.points.isNotEmpty) {
              final lastPoint = segment.points.last;
              final nextPoint = nextSegment.points.first;
              allPolylines.add(Polyline(
                points: [
                  LatLng(lastPoint.lat, lastPoint.lon),
                  LatLng(nextPoint.lat, nextPoint.lon),
                ],
                color: segmentColor, // 使用當前軌跡段的顏色進行連接
                strokeWidth: 4, // 保持與主軌跡線相同的寬度
              ));
            }
          }
        }
      }
    }
    // --- [MODIFICATION END] ---

    // --- 4. 計算邊界 (不變) ---
    if (_allPointsForBounds.isNotEmpty) {
      final LatLngBounds? calculatedBounds = LatLngBounds.fromPoints(
          _allPointsForBounds.map((p) => LatLng(p.lat, p.lon)).toList());
      setState(() {
        _polylines = allPolylines;
        _markers = allMarkers;
        _bounds = calculatedBounds;
      });
    } else {
      setState(() {
        _polylines = [];
        _markers = [];
        _bounds = null;
      });
    }
  }

  // --- 輔助方法 (不變) ---
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

  PointMarker _createStartEndMarker(BusPoint point, {required bool isStart}) {
    return PointMarker(
      busPoint: point,
      width: 32,
      height: 32,
      child: Icon(
        isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded,
        color: isStart ? Colors.greenAccent : Colors.redAccent,
        size: 32,
        shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _allPointsForBounds.isNotEmpty;
    if (!hasData) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.plate} 軌跡')),
        body: const Center(child: Text('沒有可顯示的軌跡數據。')),
      );
    }
    return BaseMapView(
      appBarTitle: '${widget.plate} 軌跡地圖',
      isLoading: false,
      error: null,
      points: _allPointsForBounds,
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
    );
  }
}
