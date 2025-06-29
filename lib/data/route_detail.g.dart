// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StationNode _$StationNodeFromJson(Map<String, dynamic> json) => StationNode(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );

StationEdge _$StationEdgeFromJson(Map<String, dynamic> json) => StationEdge(
      node: StationNode.fromJson(json['node'] as Map<String, dynamic>),
      orderNo: (json['orderNo'] as num).toInt(),
      goBack: (json['goBack'] as num).toInt(),
    );

StationsConnection _$StationsConnectionFromJson(Map<String, dynamic> json) =>
    StationsConnection(
      edges: (json['edges'] as List<dynamic>?)
              ?.map((e) => StationEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

RoutePoint _$RoutePointFromJson(Map<String, dynamic> json) => RoutePoint(
      go: json['go'] as String? ?? '',
      back: json['back'] as String? ?? '',
    );

RouteDetail _$RouteDetailFromJson(Map<String, dynamic> json) => RouteDetail(
      routePoint:
          RoutePoint.fromJson(json['routePoint'] as Map<String, dynamic>),
      stationsConnection:
          StationsConnection.fromJson(json['stations'] as Map<String, dynamic>),
    );
