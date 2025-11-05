import 'package:flutter_map/flutter_map.dart';

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
