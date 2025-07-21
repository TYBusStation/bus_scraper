// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Car _$CarFromJson(Map<String, dynamic> json) => Car(
      plate: json['plate'] as String,
      type:
          $enumDecode(_$TypeEnumMap, json['type'], unknownValue: Type.unknown),
      lastSeen: DateTime.parse(json['last_seen'] as String),
    );

Map<String, dynamic> _$CarToJson(Car instance) => <String, dynamic>{
      'plate': instance.plate,
      'type': _$TypeEnumMap[instance.type]!,
      'last_seen': instance.lastSeen.toIso8601String(),
    };

const _$TypeEnumMap = {
  Type.NO_S: 'no_s',
  Type.CITY_S: 'city_s',
  Type.EV: 'ev',
  Type.LFV: 'lfv',
  Type.WIFI_LFV: 'wifilfv',
  Type.LFV_M_L_BUS: 'lfvmlbus',
  Type.LFV_EV_BUS: 'lfvevbus',
  Type.GEN_M_BUS: 'genmbus',
  Type.GEN_L_BUS: 'genlbus',
  Type.GEN_M_L_BUS: 'genmlbus',
  Type.DRTS: 'DRTS',
  Type.KLRT: 'KLRT',
  Type.unknown: 'unknown',
};
