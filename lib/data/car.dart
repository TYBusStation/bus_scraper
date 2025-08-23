// car.dart

import 'package:json_annotation/json_annotation.dart';

part 'car.g.dart';

/// 這是一個頂層函式 (top-level function)，`json_serializable` 會使用它
/// 來讀取 `rawType` 欄位的值。
///
/// 我們直接從傳入的 JSON map 中讀取 'type' 鍵的值。
Object? _readRawType(Map json, String key) => json['type'];

@JsonSerializable()
class Car {
  @JsonKey(name: "plate")
  final String plate;

  @JsonKey(name: "type", unknownEnumValue: Type.unknown)
  final Type type;

  /// 使用 `readValue` 來從原始 JSON 的 'type' 鍵讀取字串值。
  /// 這樣就不會與上面的 `type` 欄位產生 key 衝突。
  /// `includeToJson: false` 確保在序列化回 JSON 時，不會額外產生 "rawType" 欄位。
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

  /// 方便的 getter，如果類型未知，則結合中文名稱與原始資料。
  String get typeDisplayName {
    return '${type.chinese} ($rawType)';
  }

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);

  Map<String, dynamic> toJson() => _$CarToJson(this);
}

// Enum 本身保持不變
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
