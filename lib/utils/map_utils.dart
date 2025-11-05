import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../data/processed_map_data.dart';
import '../data/trajectory_segment.dart';
import '../widgets/point_marker.dart';

abstract class MapUtils {
  static const List<Color> segmentColors = [
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
  static List<Color> segmentColorsReverse = segmentColors.reversed.toList();
  static const double defaultZoom = 17;

  static ProcessedMapData processBusPoints(List<BusPoint> points) {
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
      final colorCycler = ColorCycler();
      Color color = colorCycler.nextColor;
      List<LatLng> currentSegmentPoints = [
        LatLng(points.first.lat, points.first.lon)
      ];

      trackPointMarkers.add(_createTrackPointMarker(points.first, color));

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
            segmentedPolylines.add(Polyline(
              points: List.from(currentSegmentPoints),
              color: color,
              strokeWidth: 4,
            ));
          }

          color = colorCycler.nextColor;

          currentSegmentPoints = [
            LatLng(previousPoint.lat, previousPoint.lon),
            LatLng(currentPoint.lat, currentPoint.lon),
          ];
        } else {
          currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
        }

        trackPointMarkers.add(_createTrackPointMarker(currentPoint, color));
      }

      if (currentSegmentPoints.length > 1) {
        segmentedPolylines.add(Polyline(
          points: currentSegmentPoints,
          color: color,
          strokeWidth: 4,
        ));
      }
    } else {
      final color = segmentColors[0];
      trackPointMarkers.add(_createTrackPointMarker(points.first, color));
    }

    return ProcessedMapData(
      polylines: segmentedPolylines,
      markers: trackPointMarkers,
      bounds: bounds,
    );
  }

  static PointMarker _createTrackPointMarker(BusPoint point, Color color) {
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

  static double getPanelHeight(bool isLandscape) {
    return isLandscape ? 100.0 : 160.0;
  }

  static Widget buildInfoChip(
      {required BuildContext context,
      required IconData icon,
      required String label,
      Color? color}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Chip(
        avatar: Icon(icon,
            size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
        label: Text(label, style: theme.textTheme.labelMedium),
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  static List<TrajectorySegment> processPointsIntoSegments(
      List<BusPoint> points) {
    if (points.isEmpty) return [];
    final List<TrajectorySegment> segments = [];
    List<BusPoint> currentSegmentPoints = [points.first];

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final previousPoint = points[i - 1];
      final timeDifference =
          currentPoint.dataTime.difference(previousPoint.dataTime);

      bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
          currentPoint.goBack != previousPoint.goBack ||
          currentPoint.dutyStatus != previousPoint.dutyStatus ||
          currentPoint.driverId != previousPoint.driverId ||
          timeDifference.inMinutes >= 10);

      if (isSegmentEnd) {
        if (currentSegmentPoints.isNotEmpty) {
          segments
              .add(TrajectorySegment(points: List.from(currentSegmentPoints)));
        }
        currentSegmentPoints = [currentPoint];
      } else {
        currentSegmentPoints.add(currentPoint);
      }
    }

    if (currentSegmentPoints.isNotEmpty) {
      segments.add(TrajectorySegment(points: List.from(currentSegmentPoints)));
    }
    return segments;
  }
}

class ColorCycler {
  int index = 0;

  Color get nextColor {
    final color = MapUtils.segmentColors[index % MapUtils.segmentColors.length];
    index++;
    return color;
  }
}
