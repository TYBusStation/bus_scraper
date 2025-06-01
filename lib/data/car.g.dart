// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Car _$CarFromJson(Map<String, dynamic> json) => Car(
      plate: json['plate'] as String,
      type: $enumDecode(_$TypeEnumMap, json['type']),
    );

Map<String, dynamic> _$CarToJson(Car instance) => <String, dynamic>{
      'plate': instance.plate,
      'type': _$TypeEnumMap[instance.type]!,
    };

const _$TypeEnumMap = {
  Type.CITY_S: 'city_s',
  Type.EV: 'ev',
  Type.LFV: 'lfv',
  Type.NO_S: 'no_s',
};
