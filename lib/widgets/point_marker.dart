import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';

class PointMarker extends Marker {
  final BusPoint busPoint;

  PointMarker({
    required this.busPoint,
    required super.child,
    super.width = 30.0,
    super.height = 30.0,
    super.alignment,
  }) : super(point: LatLng(busPoint.lat, busPoint.lon));
}
