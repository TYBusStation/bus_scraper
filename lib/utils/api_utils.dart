import 'dart:convert';

import 'package:bus_scraper/data/car.dart';
import 'package:bus_scraper/data/route_detail.dart';
import 'package:bus_scraper/data/vehicle_history.dart';
import 'package:bus_scraper/storage/city.dart';
import 'package:bus_scraper/utils/static.dart';

import '../data/bus_route.dart';
import 'formatter_utils.dart';

abstract class ApiUtils {
  static const String _graphqlQueryRoutes = """
  query QUERY_ROUTES(\$lang: String!) {
    routes(lang: \$lang) {
      edges {
        node {
          id
          name
          description
          departure
          destination
        }
      }
    }
  }
  """;

  static const String _graphqlQueryRouteDetail = """
  query QUERY_ROUTE_DETAIL(\$routeId: Int!, \$lang: String!) {
    route(xno: \$routeId, lang: \$lang) {
      id
      name
      departure
      destination
      description
    }
  }
  """;

  static const String _graphqlQueryRoutePathAndStops = """
  query QUERY_ROUTE_DETAIL(\$routeId: Int!, \$lang: String!) {
    route(xno: \$routeId, lang: \$lang) {
      routePoint {
        go
        back
      }
      stations {
        edges {
          goBack
          orderNo
          node {
            name
            lat
            lon
          }
        }
      }
    }
  }
  """;

  static const String _graphqlQueryDailyTimeTable = """
  query QUERY_DAILY_TIMETABLE(\$xno: Int!, \$date: String!) {
    dailyTimeTable(xno: \$xno, date: \$date) {
      edges {
        node {
          goBack
          carId
          scheduleTime
        }
      }
    }
  }
  """;

  static Future<String> fetchAnnouncement() async {
    final url = "${Static.apiBaseUrl}/announcement";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is String) {
        return response.data;
      }
      return '無法載入公告 (狀態碼: ${response.statusCode})';
    } catch (e) {
      Static.log("讀取公告時發生錯誤: $e");
      return '載入公告失敗，請檢查您的網路連線。';
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
      if (fetchedRoute.name != '未知') {
        return fetchedRoute;
      }
    }

    return route;
  }

  static Future<BusRoute> fetchGraphQLRouteDetailById(String routeId) async {
    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null || Static.city == City.taipei) {
      return BusRoute.unknownWithId(routeId);
    }
    try {
      final response = await Static.dio.get(
        Static.graphqlUrl,
        queryParameters: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": jsonEncode({"routeId": routeIdInt, "lang": "zh"}),
          "query": _graphqlQueryRouteDetail,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['route'] is Map) {
        final newRoute = BusRoute.fromJson(response.data['data']['route']);

        final index = Static.routeData.indexWhere((r) => r.id == newRoute.id);
        if (index != -1) {
          Static.routeData[index] = newRoute;
        } else {
          Static.routeData.add(newRoute);
        }

        return newRoute;
      }
    } catch (e) {
      Static.log("透過 GraphQL 讀取路線詳情 (ID: $routeId) 時發生錯誤: $e");
    }
    return BusRoute.unknownWithId(routeId);
  }

  static Future<RouteDetail> fetchRoutePathAndStops(String routeId) async {
    if (Static.routeDetailCache.containsKey(routeId)) {
      return Static.routeDetailCache[routeId]!;
    }
    RouteDetail routeDetail;
    if (Static.city == City.taipei) {
      final route = getRouteByIdSync(routeId);
      if (route.name == '未知路線' || route.nid == null || route.nid!.isEmpty) {
        return RouteDetail.unknown;
      }
      routeDetail = await _fetchTaipeiRoutePathAndStops(nid: route.nid!);
    } else {
      routeDetail = await _fetchGraphQLRoutePathAndStops(routeId: routeId);
    }
    if (routeDetail != RouteDetail.unknown) {
      Static.routeDetailCache[routeId] = routeDetail;
    }
    return routeDetail;
  }

  static Future<RouteDetail> _fetchTaipeiRoutePathAndStops(
      {required String nid}) async {
    final url = "${Static.apiBaseUrl}/${Static.city.code}/route_info/$nid";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return RouteDetail.fromJson(response.data);
      }
    } catch (e) {
      Static.log("透過 API 讀取台北路線詳情 (NID: $nid) 時發生錯誤: $e");
    }
    return RouteDetail.unknown;
  }

  static Future<RouteDetail> _fetchGraphQLRoutePathAndStops(
      {required String routeId}) async {
    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) return RouteDetail.unknown;
    try {
      final response = await Static.dio.get(
        Static.graphqlUrl,
        queryParameters: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": jsonEncode({"routeId": routeIdInt, "lang": "zh"}),
          "query": _graphqlQueryRoutePathAndStops,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['route'] is Map) {
        return RouteDetail.fromJson(response.data['data']['route']);
      }
    } catch (e) {
      Static.log("透過 GraphQL 讀取路線站點 (ID: $routeId) 時發生錯誤: $e");
    }
    return RouteDetail.unknown;
  }

  static Future<List<Map<String, dynamic>>> fetchTaichungDailyTimeTable({
    required int routeId,
    required String date,
  }) async {
    try {
      final response = await Static.dio.get(
        Static.graphqlUrl,
        queryParameters: {
          "operationName": "QUERY_DAILY_TIMETABLE",
          "variables": jsonEncode({"xno": routeId, "date": date}),
          "query": _graphqlQueryDailyTimeTable,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['dailyTimeTable']?['edges'] is List) {
        return (response.data['data']['dailyTimeTable']['edges'] as List)
            .map((e) => e['node'] as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      Static.log("透過 GraphQL 讀取時刻表 (ID: $routeId, Date: $date) 時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchAllRoutes() async {
    if (Static.city == City.taipei) return [];
    if (Static.allRouteData != null) return Static.allRouteData!;

    final String url = "${Static.apiBaseUrl}/${Static.city.code}/all_routes";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        final routes =
            (response.data as List).map((r) => BusRoute.fromJson(r)).toList();
        Static.allRouteData = routes;
        return routes;
      }
    } catch (e) {
      Static.log("讀取所有路線時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchGraphQLOpRoutes() async {
    try {
      final response = await Static.dio.get(
        Static.graphqlUrl,
        queryParameters: {
          "operationName": "QUERY_ROUTES",
          "variables": jsonEncode({"lang": "zh"}),
          "query": _graphqlQueryRoutes,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['routes']?['edges'] is List) {
        return (response.data['data']['routes']['edges'] as List)
            .map((edge) => BusRoute.fromJson(edge['node']))
            .toList();
      }
    } catch (e) {
      Static.log("透過 GraphQL 讀取營運路線時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchTaipeiOpRoutes() async {
    final String url = "${Static.apiBaseUrl}/${Static.city.code}/op_routes";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } catch (e) {
      Static.log("讀取台北營運路線時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> fetchSpecialRoutes() async {
    final String url =
        "${Static.apiBaseUrl}/${Static.city.code}/special_routes";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } catch (e) {
      Static.log("讀取特殊路線時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<Car>> fetchCarData() async {
    final String url = "${Static.apiBaseUrl}/${Static.city.code}/all_car_types";
    try {
      final response = await Static.dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((c) => Car.fromJson(c)).toList();
      }
    } catch (e) {
      Static.log("讀取車輛資料時發生錯誤: $e");
    }
    return [];
  }

  static Future<List<Car>> fetchCarsByPlates(List<String> plates) async {
    final futures = plates.map((plate) async {
      final url = "${Static.apiBaseUrl}/${Static.city.code}/car/$plate";
      try {
        final response = await Static.dio.getUri(Uri.parse(url));
        if (response.statusCode == 200 && response.data != null) {
          return Car.fromJson(response.data);
        }
      } catch (e) {
        Static.log("讀取車輛資料 (車牌: $plate) 時發生錯誤: $e");
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
    final uri = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/tools/find_route_vehicles")
        .replace(
      queryParameters: {
        'route_id': routeId,
        if (startDate != null)
          'start_time': FormatterUtils.apiTimeFormat.format(startDate),
        if (endDate != null)
          'end_time': FormatterUtils.apiTimeFormat.format(endDate),
      },
    );
    try {
      final response = await Static.dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleDrivingDates.fromJson(json))
            .toList();
      }
    } catch (e) {
      Static.log("查詢路線車輛 (ID: $routeId) 時發生錯誤: $e");
    }
    return [];
  }
}
