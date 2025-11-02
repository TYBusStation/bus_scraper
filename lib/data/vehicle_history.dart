import 'dart:convert';

class PlateDrivingDates {
  final String plate;
  final List<String> dates;

  PlateDrivingDates({
    required this.plate,
    required this.dates,
  });

  factory PlateDrivingDates.fromJson(Map<String, dynamic> json) {
    return PlateDrivingDates(
      plate: json['plate'] as String,
      dates: List<String>.from(json['dates']),
    );
  }
}

class VehicleDrivingDates {
  final String plate;
  final List<String> dates;

  VehicleDrivingDates({
    required this.plate,
    required this.dates,
  });

  factory VehicleDrivingDates.fromJson(Map<String, dynamic> json) {
    return VehicleDrivingDates(
      plate: json['plate'] as String,
      dates: List<String>.from(json['dates']),
    );
  }
}

class DriverDateInfo {
  final String driverId;
  final List<String> dates;

  DriverDateInfo({
    required this.driverId,
    required this.dates,
  });

  factory DriverDateInfo.fromJson(Map<String, dynamic> json) {
    return DriverDateInfo(
      driverId: json['driver_id'],
      dates: List<String>.from(json['dates']),
    );
  }
}

class VehicleRouteHistory {
  final String routeId;
  final List<String> dates;

  VehicleRouteHistory({
    required this.routeId,
    required this.dates,
  });

  factory VehicleRouteHistory.fromJson(Map<String, dynamic> json) {
    return VehicleRouteHistory(
      routeId: json['route_id'],
      dates: List<String>.from(json['dates']),
    );
  }
}

List<PlateDrivingDates> parsePlateDrivingDates(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed
      .map<PlateDrivingDates>((json) => PlateDrivingDates.fromJson(json))
      .toList();
}

List<VehicleDrivingDates> parseVehicleDrivingDates(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed
      .map<VehicleDrivingDates>((json) => VehicleDrivingDates.fromJson(json))
      .toList();
}

List<DriverDateInfo> parseDriverDateInfo(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed
      .map<DriverDateInfo>((json) => DriverDateInfo.fromJson(json))
      .toList();
}

List<VehicleRouteHistory> parseVehicleRouteHistory(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed
      .map<VehicleRouteHistory>((json) => VehicleRouteHistory.fromJson(json))
      .toList();
}
