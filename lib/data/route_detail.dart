// lib/data/route_detail.dart

import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // <--- 【新增】導入
import 'package:json_annotation/json_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'route_detail.g.dart';

class LatLngListConverter
    implements JsonConverter<List<LatLng>, List<dynamic>> {
  const LatLngListConverter();

  @override
  List<LatLng> fromJson(List<dynamic> json) {
    return json
        .whereType<String>()
        .map((p) {
          final parts = p.split(',');
          if (parts.length == 2) {
            return LatLng(double.tryParse(parts[1]) ?? 0.0,
                double.tryParse(parts[0]) ?? 0.0);
          }
          return const LatLng(0, 0);
        })
        .where((p) => p.latitude != 0.0 || p.longitude != 0.0)
        .toList();
  }

  @override
  List<dynamic> toJson(List<LatLng> object) {
    return object.map((p) => '${p.longitude},${p.latitude}').toList();
  }
}

@JsonSerializable(createToJson: false)
class StationNode {
  final String name;
  final double lat;
  final double lon;

  StationNode({required this.name, required this.lat, required this.lon});

  factory StationNode.fromJson(Map<String, dynamic> json) =>
      _$StationNodeFromJson(json);
}

@JsonSerializable(createToJson: false)
class StationEdge {
  @JsonKey(name: 'node')
  final StationNode node;

  @JsonKey(name: 'orderNo')
  final int orderNo;

  @JsonKey(name: 'goBack')
  final int goBack;

  StationEdge({
    required this.node,
    required this.orderNo,
    required this.goBack,
  });

  String get name => node.name;

  LatLng get position => LatLng(node.lat, node.lon);

  factory StationEdge.fromJson(Map<String, dynamic> json) =>
      _$StationEdgeFromJson(json);
}

@JsonSerializable(createToJson: false)
class StationsConnection {
  @JsonKey(name: 'edges', defaultValue: [])
  final List<StationEdge> edges;

  StationsConnection({required this.edges});

  factory StationsConnection.fromJson(Map<String, dynamic> json) =>
      _$StationsConnectionFromJson(json);
}

@JsonSerializable(createToJson: false)
class RoutePoint {
  @JsonKey(defaultValue: "")
  final String go;

  @JsonKey(defaultValue: "")
  final String back;

  RoutePoint({required this.go, required this.back});

  factory RoutePoint.fromJson(Map<String, dynamic> json) =>
      _$RoutePointFromJson(json);
}

@JsonSerializable(createToJson: false)
class RouteDetail {
  static final unknown = RouteDetail(
    routePoint: RoutePoint(go: "", back: ""),
    stationsConnection: StationsConnection(edges: []),
  );

  @JsonKey(name: 'routePoint')
  final RoutePoint routePoint;

  @JsonKey(name: 'stations')
  final StationsConnection stationsConnection;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<LatLng> goPath;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<LatLng> backPath;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<StationEdge> goStations;

  @JsonKey(includeFromJson: false, includeToJson: false)
  late final List<StationEdge> backStations;

  RouteDetail({
    required this.routePoint,
    required this.stationsConnection,
  }) {
    final polylinePoints = PolylinePoints();

    final List<PointLatLng> goResult =
        polylinePoints.decodePolyline(routePoint.go);
    goPath = goResult.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final List<PointLatLng> backResult =
        polylinePoints.decodePolyline(routePoint.back);
    backPath = backResult.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final allStations = stationsConnection.edges;

    goStations = allStations.where((s) => s.goBack == 1).toList()
      ..sort((a, b) => a.orderNo.compareTo(b.orderNo));

    backStations = allStations.where((s) => s.goBack == 2).toList()
      ..sort((a, b) => a.orderNo.compareTo(b.orderNo));
  }

  factory RouteDetail.fromJson(Map<String, dynamic> json) =>
      _$RouteDetailFromJson(json);
}
