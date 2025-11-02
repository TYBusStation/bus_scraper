import 'package:json_annotation/json_annotation.dart';

part 'car.g.dart';

Object? _readRawType(Map json, String key) => json['type'];

@JsonSerializable()
class Car {
  @JsonKey(name: "plate")
  final String plate;

  @JsonKey(name: "type", unknownEnumValue: Type.unknown)
  final Type type;

  @JsonKey(readValue: _readRawType, includeToJson: false)
  final String rawType;

  @JsonKey(name: "last_seen")
  final DateTime lastSeen;

  Car({
    required this.plate,
    required this.type,
    required this.lastSeen,
    required this.rawType,
  });

  String get typeDisplayName {
    return '${type.chinese} ($rawType)';
  }

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);

  Map<String, dynamic> toJson() => _$CarToJson(this);
}

enum Type {
  @JsonValue("no_s")
  NO_S("直樑"),
  @JsonValue("city_s")
  CITY_S("直樑"),
  @JsonValue("ev")
  EV("電動"),
  @JsonValue("lfv")
  LFV("低地板"),
  @JsonValue("wifilfv")
  WIFI_LFV("Wi-Fi 低地板"),
  @JsonValue("lfvmlbus")
  LFV_M_L_BUS("低地板手排大巴"),
  @JsonValue("lfvevbus")
  LFV_EV_BUS("低地板電動巴士"),
  @JsonValue("genmbus")
  GEN_M_BUS("普通中巴"),
  @JsonValue("genlbus")
  GEN_L_BUS("普通大巴"),
  @JsonValue("genmlbus")
  GEN_M_L_BUS("普通手排大巴"),
  @JsonValue("DRTS")
  DRTS("計程車"),
  @JsonValue("KLRT")
  KLRT("輕軌列車"),
  unknown("未知類型");

  final String chinese;

  const Type(this.chinese);
}
