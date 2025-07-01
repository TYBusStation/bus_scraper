// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../pages/history_page.dart';
import '../utils/map_data_processor.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart'; // 引入 PointMarker

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

    _allPointsForBounds = [
      ...widget.segments.expand((s) => s.points),
      ...(widget.backgroundSegments?.expand((s) => s.points) ?? []),
    ];

    if (_allPointsForBounds.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // --- 1. 處理背景軌跡段 ---
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

    // --- 2. 根據是否篩選，選擇不同的繪圖策略 ---
    if (!widget.isFiltered) {
      // 情況 A: 未篩選
      final allMainPoints = widget.segments.expand((s) => s.points).toList();
      if (allMainPoints.isNotEmpty) {
        final processedData = processBusPoints(allMainPoints);
        allPolylines.addAll(processedData.polylines);
        allMarkers.addAll(processedData.markers);

        if (allMainPoints.length > 1) {
          allMarkers
              .add(_createStartEndMarker(allMainPoints.first, isStart: true));
          allMarkers
              .add(_createStartEndMarker(allMainPoints.last, isStart: false));
        } else {
          allMarkers.add(_createSinglePointMarker(allMainPoints.first));
        }
      }
    } else {
      // 情況 B: 已篩選
      for (final segment in widget.segments) {
        if (segment.points.isEmpty) continue;

        final processedData = processBusPoints(segment.points);
        allPolylines.addAll(processedData.polylines);
        allMarkers.addAll(processedData.markers);

        if (segment.points.length > 1) {
          allMarkers
              .add(_createStartEndMarker(segment.points.first, isStart: true));
          allMarkers
              .add(_createStartEndMarker(segment.points.last, isStart: false));
        } else {
          allMarkers.add(_createSinglePointMarker(segment.points.first));
        }
      }
    }

    // --- 3. 計算邊界 ---
    final LatLngBounds? calculatedBounds = LatLngBounds.fromPoints(
        _allPointsForBounds.map((p) => LatLng(p.lat, p.lon)).toList());

    setState(() {
      _polylines = allPolylines;
      _markers = allMarkers;
      _bounds = calculatedBounds;
    });
  }

  // [MODIFIED] 完全參照 live_osm_page.dart 的樣式，移除 Stack 和背景 Container
  PointMarker _createStartEndMarker(BusPoint point, {required bool isStart}) {
    return PointMarker(
      busPoint: point,
      width: 32, // 與 live_osm_page 一致
      height: 32, // 與 live_osm_page 一致
      child: Icon(
        isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded,
        color: isStart ? Colors.greenAccent : Colors.redAccent,
        // 顏色也與 live_osm_page 相似
        size: 32, // 與 live_osm_page 一致
        // 暈影已被移除，此處不再有 shadows 屬性
      ),
    );
  }

  // 單點軌跡段使用與一般軌跡段一樣的小圓點
  PointMarker _createSinglePointMarker(BusPoint point) {
    // 讓單點標記也使用與起點標記相同的樣式
    return _createStartEndMarker(point, isStart: true);
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
