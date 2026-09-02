import 'dart:convert';

import 'package:bus_scraper/data/car.dart';
import 'package:bus_scraper/data/route_detail.dart';
import 'package:bus_scraper/data/vehicle_history.dart';
import 'package:bus_scraper/storage/city.dart';
import 'package:bus_scraper/utils/static.dart';
import 'package:dio/dio.dart';

import '../data/bus_route.dart';
import 'formatter_utils.dart';

abstract class ApiUtils {
  static const String _queryRouteDetail = """
  query QUERY_ROUTE_DETAIL(\$routeId: Int!, \$lang: String!) {
    route(xno: \$routeId, lang: \$lang) {
      id, name, departure, destination, description
    }
  }
  """;

  static const String _queryDailyTimeTable = """
  query QUERY_DAILY_TIMETABLE(\$xno: Int!, \$date: String!) {
    dailyTimeTable(xno: \$xno, date: \$date) {
      edges { node { goBack, carId, scheduleTime } }
    }
  }
  """;

  static Map<String, String> _getHeaders(String cityCode, {String? routeId}) {
    final String domain = Static.city.url.replaceAll(RegExp(r'/$'), '');

    final String referer =
        routeId != null ? "$domain/ebus/driving-map/$routeId" : "$domain/ebus/";

    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      'Origin': domain,
      'Referer': referer,
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
  }

  static Future<Response?> _postGraphQL(String operationName,
      Map<String, dynamic> variables, String query) async {
    try {
      final payload = {
        "operationName": operationName,
        "variables": variables,
        "query": query,
      };

      return await Static.dio.post(
        Static.graphqlUrl,
        data: jsonEncode(payload),
        options: Options(
            headers: _getHeaders(Static.city.code,
                routeId: variables['routeId']?.toString())),
      );
    } catch (e) {
      Static.log("GraphQL $operationName 請求錯誤: $e");
      return null;
    }
  }

  static Future<RouteDetail> _fetchGraphQLRoutePathAndStops(
      {required String routeId}) async {
    final String apiBase = Static.city.url.replaceAll(RegExp(r'/$'), '');

    try {
      final headers = _getHeaders(Static.city.code, routeId: routeId);

      // 同時發送 /stop (站點) 與 /points (軌跡) 請求
      final results = await Future.wait([
        Static.dio.get("$apiBase/cms/api/route/$routeId/stop",
            options: Options(headers: headers)),
        Static.dio.get("$apiBase/cms/api/route/$routeId/points",
            options: Options(headers: headers)),
      ]);

      final stopResp = results[0];
      final pointResp = results[1];

      Map<String, dynamic> combinedData = {
        "stations": {"edges": []},
        "routePoint": {"go": "", "back": ""}
      };

      if (stopResp.statusCode == 200 && stopResp.data is List) {
        combinedData["stations"]["edges"] = (stopResp.data as List).map((s) {
          return {
            "goBack": s["GoBack"],
            "orderNo": s["SeqNo"],
            "node": {
              "name": s["NameZh"],
              "lat": s["Latitude"],
              "lon": s["Longitude"],
            }
          };
        }).toList();
      }

      if (pointResp.statusCode == 200 && pointResp.data is List) {
        for (var p in pointResp.data) {
          if (p["GoBack"] == 1)
            combinedData["routePoint"]["go"] = p["Polyline"] ?? "";
          if (p["GoBack"] == 2)
            combinedData["routePoint"]["back"] = p["Polyline"] ?? "";
        }
      }

      return RouteDetail.fromJson(combinedData);
    } catch (e) {
      Static.log("REST 讀取路線細節 (ID: $routeId) 失敗: $e");
    }
    return RouteDetail.unknown;
  }

  static Future<BusRoute> fetchGraphQLRouteDetailById(String routeId) async {
    return BusRoute.unknownWithId(routeId);
  }

  static Future<List<Map<String, dynamic>>> fetchTaichungDailyTimeTable({
    required int routeId,
    required String date,
  }) async {
    final response = await _postGraphQL(
      "QUERY_DAILY_TIMETABLE",
      {"xno": routeId, "date": date},
      _queryDailyTimeTable,
    );

    if (response?.statusCode == 200 &&
        response?.data?['data']?['dailyTimeTable']?['edges'] is List) {
      return (response!.data['data']['dailyTimeTable']['edges'] as List)
          .map((e) => e['node'] as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  static Future<String> fetchAnnouncement() async {
    final url = "${Static.apiBaseUrl}/announcement";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is String)
        return response.data;
      return '無法載入公告';
    } catch (e) {
      return '載入公告失敗';
    }
  }

  static BusRoute getRouteByIdSync(String routeId) {
    try {
      return Static.routeData.firstWhere((r) => r.id == routeId);
    } catch (_) {}
    if (Static.allRouteData != null) {
      try {
        return Static.allRouteData!.firstWhere((r) => r.id == routeId);
      } catch (_) {}
    }
    return BusRoute.unknownWithId(routeId);
  }

  static Future<BusRoute> getRouteById(String routeId) async {
    final route = getRouteByIdSync(routeId);
    if (route.name == '未知' || route == BusRoute.unknown) {
      final fetchedRoute = await fetchGraphQLRouteDetailById(routeId);
      if (fetchedRoute.name != '未知') return fetchedRoute;
    }
    return route;
  }

  static Future<RouteDetail> fetchRoutePathAndStops(String routeId) async {
    if (Static.routeDetailCache.containsKey(routeId)) {
      return Static.routeDetailCache[routeId]!;
    }

    RouteDetail routeDetail;
    final route = getRouteByIdSync(routeId);
    if (route.name == '未知路線' ||
        (Static.city == City.taipei &&
            (route.nid == null || route.nid!.isEmpty))) {
      return RouteDetail.unknown;
    }
    routeDetail = await _fetchRoutePathAndStops(
        nid: Static.city == City.taipei ? route.nid! : routeId);

    if (routeDetail != RouteDetail.unknown) {
      Static.routeDetailCache[routeId] = routeDetail;
    }
    return routeDetail;
  }

  static Future<RouteDetail> _fetchRoutePathAndStops(
      {required String nid}) async {
    final url = "${Static.apiBaseUrl}/${Static.city.code}/route_info/$nid";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return RouteDetail.fromJson(response.data);
      }
    } catch (e) {
      Static.log("台北站點讀取錯誤: $e");
    }
    return RouteDetail.unknown;
  }

  static Future<List<BusRoute>> fetchAllRoutes() async {
    if (Static.city == City.taipei) return [];
    if (Static.allRouteData != null) return Static.allRouteData!;

    final String url = "${Static.apiBaseUrl}/${Static.city.code}/all_routes";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        final routes =
            (response.data as List).map((r) => BusRoute.fromJson(r)).toList();
        Static.allRouteData = routes;
        return routes;
      }
    } catch (e) {
      Static.log("讀取所有路線失敗: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchOpRoutes() async {
    final String url = "${Static.apiBaseUrl}/${Static.city.code}/op_routes";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } catch (e) {
      Static.log("讀取台北營運路線失敗: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchSpecialRoutes() async {
    final String url =
        "${Static.apiBaseUrl}/${Static.city.code}/special_routes";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } catch (e) {
      Static.log("讀取特殊路線失敗: $e");
    }
    return [];
  }

  static Future<List<Car>> fetchCarData() async {
    final String url = "${Static.apiBaseUrl}/${Static.city.code}/all_car_types";
    try {
      final response = await Static.dio
          .get(url, options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((c) => Car.fromJson(c)).toList();
      }
    } catch (e) {
      Static.log("讀取車輛資料失敗: $e");
    }
    return [];
  }

  static Future<List<Car>> fetchCarsByPlates(List<String> plates) async {
    final futures = plates.map((plate) async {
      final url = "${Static.apiBaseUrl}/${Static.city.code}/car/$plate";
      try {
        final response = await Static.dio
            .get(url, options: Options(headers: _getHeaders(Static.city.code)));
        if (response.statusCode == 200 && response.data != null) {
          Car car = Car.fromJson(response.data);
          Static.carData.removeWhere((c) => c.plate == plate);
          Static.carData.add(car);
          return car;
        }
      } catch (e) {
        Static.log("讀取車輛 ($plate) 失敗: $e");
      }
      return null;
    }).toList();
    final results = await Future.wait(futures);
    return results.where((car) => car != null).cast<Car>().toList();
  }

  static Future<List<VehicleDrivingDates>> findVehiclesOnRoute({
    required String routeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = {
      'route_id': routeId,
      if (startDate != null)
        'start_time': FormatterUtils.apiTimeFormat.format(startDate),
      if (endDate != null)
        'end_time': FormatterUtils.apiTimeFormat.format(endDate),
    };
    final String url =
        "${Static.apiBaseUrl}/${Static.city.code}/tools/find_route_vehicles";

    try {
      final response = await Static.dio.get(url,
          queryParameters: queryParams,
          options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleDrivingDates.fromJson(json))
            .toList();
      }
    } catch (e) {
      Static.log("查詢歷史路線車輛失敗: $e");
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchCarTimetable({
    required String plate,
    required String date,
  }) async {
    final url = "${Static.apiBaseUrl}/${Static.city.code}/timetable";
    try {
      final response = await Static.dio.get(url,
          queryParameters: {"date": date, "plate": plate},
          options: Options(headers: _getHeaders(Static.city.code)));
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      Static.log("讀取車輛時刻表失敗: $e");
    }
    return [];
  }
}
