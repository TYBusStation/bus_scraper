// lib/data/vehicle_history.dart

import 'dart:convert';

/// 代表單一車輛及其被特定駕駛員駕駛的日期
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

/// 代表單一車輛及其行駛特定路線的日期
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

/// 代表單一駕駛員及其駕駛日期的資料模型
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

/// 代表單一車輛行駛路線及其日期的資料模型
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

// --- JSON 解析輔助函式 ---

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
