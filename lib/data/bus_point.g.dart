// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bus_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusPoint _$BusPointFromJson(Map<String, dynamic> json) => BusPoint(
      plate: json['plate'] as String,
      driverId: json['driver_id'] as String,
      routeId: json['route_id'] as String,
      goBack: (json['go_back'] as num).toInt(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      dutyStatus: (json['duty_status'] as num).toInt(),
      dataTime: DateTime.parse(json['data_time'] as String),
    );

Map<String, dynamic> _$BusPointToJson(BusPoint instance) => <String, dynamic>{
      'plate': instance.plate,
      'driver_id': instance.driverId,
      'route_id': instance.routeId,
      'go_back': instance.goBack,
      'lat': instance.lat,
      'lon': instance.lon,
      'duty_status': instance.dutyStatus,
      'data_time': instance.dataTime.toIso8601String(),
    };
