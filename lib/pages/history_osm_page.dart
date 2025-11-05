import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../data/trajectory_segment.dart';
import '../utils/map_utils.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

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
    final colorCycler = ColorCycler();

    _allPointsForBounds = [
      ...widget.segments.expand((s) => s.points),
      ...(widget.backgroundSegments?.expand((s) => s.points) ?? []),
    ];

    if (_allPointsForBounds.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

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

    if (widget.segments.isNotEmpty) {
      for (int i = 0; i < widget.segments.length; i++) {
        final segment = widget.segments[i];
        if (segment.points.isEmpty) continue;

        final segmentColor = colorCycler.nextColor;

        allPolylines.add(Polyline(
          points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
          color: segmentColor,
          strokeWidth: 4,
        ));

        for (final point in segment.points) {
          allMarkers.add(_createTrackPointMarker(point, segmentColor));
        }

        if (widget.isFiltered) {
          allMarkers
              .add(_createStartEndMarker(segment.points.first, isStart: true));
          allMarkers
              .add(_createStartEndMarker(segment.points.last, isStart: false));
        } else {
          if (i == 0) {
            allMarkers.add(
                _createStartEndMarker(segment.points.first, isStart: true));
          }
          if (i == widget.segments.length - 1) {
            allMarkers.add(
                _createStartEndMarker(segment.points.last, isStart: false));
          }

          if (i < widget.segments.length - 1) {
            final nextSegment = widget.segments[i + 1];
            if (nextSegment.points.isNotEmpty) {
              final lastPoint = segment.points.last;
              final nextPoint = nextSegment.points.first;
              allPolylines.add(
                Polyline(
                  points: [
                    LatLng(lastPoint.lat, lastPoint.lon),
                    LatLng(nextPoint.lat, nextPoint.lon),
                  ],
                  color: segmentColor,
                  strokeWidth: 4,
                ),
              );
            }
          }
        }
      }
    }
    if (_allPointsForBounds.isNotEmpty) {
      final LatLngBounds calculatedBounds = LatLngBounds.fromPoints(
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
