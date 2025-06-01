// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_route.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) => BusRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      opType: (json['opType'] as num).toInt(),
      routeGroup: json['routeGroup'] as String,
      providers:
          (json['providers'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$BusRouteToJson(BusRoute instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'opType': instance.opType,
      'routeGroup': instance.routeGroup,
      'providers': instance.providers,
    };
