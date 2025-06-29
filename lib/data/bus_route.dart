import 'package:json_annotation/json_annotation.dart';

part 'bus_route.g.dart';

@JsonSerializable()
class BusRoute {
  static final unknown = BusRoute(
    id: "未知",
    name: '未知',
    departure: "未知",
    destination: "未知",
    description: "未知",
  );

  @JsonKey(name: "id")
  final String id;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "description")
  final String description;
  @JsonKey(name: "departure")
  final String departure;
  @JsonKey(name: "destination")
  final String destination;

  BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.departure,
    required this.destination,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$BusRouteToJson(this);
}
