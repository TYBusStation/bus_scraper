import 'package:json_annotation/json_annotation.dart';

part 'car.g.dart';

@JsonSerializable()
class Car {
  @JsonKey(name: "plate")
  final String plate;
  @JsonKey(name: "type")
  final Type type;

  Car({
    required this.plate,
    required this.type,
  });

  factory Car.fromJson(Map<String, dynamic> json) => _$CarFromJson(json);

  Map<String, dynamic> toJson() => _$CarToJson(this);
}

enum Type {
  @JsonValue("city_s")
  CITY_S("直樑"),
  @JsonValue("ev")
  EV("電動"),
  @JsonValue("lfv")
  LFV("低地板"),
  @JsonValue("no_s")
  NO_S("直樑");

  final String chinese;

  const Type(this.chinese);
}

final typeValues = EnumValues(
    {"city_s": Type.CITY_S, "ev": Type.EV, "lfv": Type.LFV, "no_s": Type.NO_S});

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
