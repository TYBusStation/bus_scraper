import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../data/trajectory_segment.dart';
import '../widgets/point_marker.dart';
import 'map_utils.dart';

class MultiSegmentProcessor {
  final colorCycler = ColorCycler();

  void processAndAdd(
    TrajectorySegment segment, {
    required List<Polyline> polylines,
    required List<Marker> markers,
  }) {
    if (segment.points.isEmpty) {
      return;
    }

    final color = colorCycler.nextColor;
    polylines.add(
      Polyline(
        points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
        color: color.withOpacity(0.8),
        strokeWidth: 5.0,
      ),
    );

    if (segment.points.length == 1) {
      markers.add(_createSinglePointMarker(segment.points.first, color));
    } else {
      markers.add(_createStartEndMarker(segment.points.first,
          isStart: true, color: color));
      markers.add(_createStartEndMarker(segment.points.last,
          isStart: false, color: color));
    }
  }

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
