import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

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

ProcessedMapData processBusPoints(List<BusPoint> points) {
  if (points.isEmpty) {
    return ProcessedMapData(polylines: [], markers: [], bounds: null);
  }

  final bounds = points.length > 1
      ? LatLngBounds.fromPoints(
          points.map((p) => LatLng(p.lat, p.lon)).toList())
      : null;

  final List<Polyline> segmentedPolylines = [];
  final List<Marker> trackPointMarkers = [];

  if (points.length > 1) {
    int colorIndex = 0;
    List<LatLng> currentSegmentPoints = [
      LatLng(points.first.lat, points.first.lon)
    ];

    trackPointMarkers.add(_createTrackPointMarker(
        points.first,
        BaseMapView
            .segmentColors[colorIndex % BaseMapView.segmentColors.length]));

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final previousPoint = points[i - 1];

      final timeDifference =
          currentPoint.dataTime.difference(previousPoint.dataTime);

      final bool isNewSegment =
          (currentPoint.routeId != previousPoint.routeId ||
              currentPoint.goBack != previousPoint.goBack ||
              currentPoint.dutyStatus != previousPoint.dutyStatus ||
              currentPoint.driverId != previousPoint.driverId ||
              timeDifference.inMinutes >= 10);

      if (isNewSegment) {
        if (currentSegmentPoints.length > 1) {
          final color = BaseMapView
              .segmentColors[colorIndex % BaseMapView.segmentColors.length];
          segmentedPolylines.add(Polyline(
            points: List.from(currentSegmentPoints),
            color: color,
            strokeWidth: 4,
          ));
        }

        colorIndex++;

        currentSegmentPoints = [
          LatLng(previousPoint.lat, previousPoint.lon),
          LatLng(currentPoint.lat, currentPoint.lon),
        ];
      } else {
        currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
      }

      final markerColor = BaseMapView
          .segmentColors[colorIndex % BaseMapView.segmentColors.length];
      trackPointMarkers.add(_createTrackPointMarker(currentPoint, markerColor));
    }

    if (currentSegmentPoints.length > 1) {
      final lastSegmentColor = BaseMapView
          .segmentColors[colorIndex % BaseMapView.segmentColors.length];
      segmentedPolylines.add(Polyline(
        points: currentSegmentPoints,
        color: lastSegmentColor,
        strokeWidth: 4,
      ));
    }
  } else {
    final color = BaseMapView.segmentColors[0];
    trackPointMarkers.add(_createTrackPointMarker(points.first, color));
  }

  return ProcessedMapData(
    polylines: segmentedPolylines,
    markers: trackPointMarkers,
    bounds: bounds,
  );
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
