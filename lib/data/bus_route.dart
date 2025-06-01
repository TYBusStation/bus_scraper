import 'package:json_annotation/json_annotation.dart';

part 'bus_route.g.dart';

@JsonSerializable()
class BusRoute {
  @JsonKey(name: "id")
  final String id;
  @JsonKey(name: "name")
  final String name;
  @JsonKey(name: "description")
  final String description;
  @JsonKey(name: "opType")
  final int opType;
  @JsonKey(name: "routeGroup")
  final String routeGroup;
  @JsonKey(name: "providers")
  final List<String> providers;

  BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.opType,
    required this.routeGroup,
    required this.providers,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) =>
      _$BusRouteFromJson(json);

  Map<String, dynamic> toJson() => _$BusRouteToJson(this);
}
