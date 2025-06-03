import 'package:json_annotation/json_annotation.dart';

part 'bus_point.g.dart';

@JsonSerializable()
class BusPoint {
  @JsonKey(name: "route_id")
  final String routeId;
  @JsonKey(name: "go_back")
  final int goBack;
  @JsonKey(name: "lat")
  final double lat;
  @JsonKey(name: "lon")
  final double lon;
  @JsonKey(name: "duty_status")
  final int dutyStatus;
  @JsonKey(name: "data_time")
  final DateTime dataTime;

  BusPoint(
      {required this.routeId,
      required this.goBack,
      required this.lat,
      required this.lon,
      required this.dutyStatus,
      required this.dataTime});

  factory BusPoint.fromJson(Map<String, dynamic> json) =>
      _$BusPointFromJson(json);

  Map<String, dynamic> toJson() => _$BusPointToJson(this);
}
