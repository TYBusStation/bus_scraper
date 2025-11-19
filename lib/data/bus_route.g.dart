// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_route.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusRoute _$BusRouteFromJson(Map<String, dynamic> json) => BusRoute(
      id: json['id'] as String,
      nid: json['nid'] as String?,
      pnid: json['pnid'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      departure: json['departure'] as String,
      destination: json['destination'] as String,
    );

Map<String, dynamic> _$BusRouteToJson(BusRoute instance) => <String, dynamic>{
      'id': instance.id,
      'nid': instance.nid,
      'pnid': instance.pnid,
      'name': instance.name,
      'description': instance.description,
      'departure': instance.departure,
      'destination': instance.destination,
    };
