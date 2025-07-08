import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'data/bus_route.dart';
import 'data/car.dart';
import 'data/route_detail.dart';

class Static {
  static Future<void>? _initFuture;

  // --- Constants ---
  // [MODIFIED] 將 API 網址定義為頂層常數，方便管理和切換
  static const String _primaryApiUrl = "https://myster.freeddns.org:25566";
  static const String _fallbackApiUrl = "http://192.168.1.159:25567";

  static final DateFormat apiDateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayDateFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  // [MODIFIED] 初始化時使用 _primaryApiUrl
  static String apiBaseUrl = _primaryApiUrl;

  static const String _graphqlApiUrl = "https://ebus.tycg.gov.tw/ebus/graphql";

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

  // --- Dio Instance ---
  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {"Content-Type": "application/json"},
  ));

  // --- Local Storage ---
  static final LocalStorage localStorage = LocalStorage();

  // --- Static Data (late final and nullable) ---
  static late final List<BusRoute> opRouteData;
  static late final List<BusRoute> specialRouteData;
  static late final List<BusRoute> routeData; // 營運中 + 特殊路線
  static late final List<Car> carData;

  static List<BusRoute>? allRouteData;

  // --- Route detail cache ---
  static final Map<String, RouteDetail> _routeDetailCache = {};

  static Future<void> init() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

  // [NEW] 新增一個強制切換 API 並重新初始化的方法
  static Future<void> forceSwitchApiAndReInit() {
    log("Force switching API triggered by user.");
    // 切換到另一個 API
    if (apiBaseUrl == _primaryApiUrl) {
      apiBaseUrl = _fallbackApiUrl;
      log("Switched to FALLBACK API: $apiBaseUrl");
    } else {
      apiBaseUrl = _primaryApiUrl;
      log("Switched to PRIMARY API: $apiBaseUrl");
    }

    // 重設 _initFuture，這樣下一次呼叫 init() 時會執行新的 _performInit()
    _initFuture = null;
    // 重新開始初始化過程並回傳新的 Future
    return init();
  }

  static Future<void> _performInit() async {
    log("Static initialization started. (This should only run once)");
    log("Using API Base URL: $apiBaseUrl");

    await StorageHelper.init();
    await dio.getUri(Uri.parse(apiBaseUrl));

    final results = await Future.wait([
      _fetchOpRoutesFromServer(),
      _fetchSpecialRoutesFromServer(),
      _fetchCarDataFromServer(),
    ], eagerError: false);

    opRouteData =
        (results[0] is List<BusRoute>) ? results[0] as List<BusRoute> : [];

    specialRouteData =
        (results[1] is List<BusRoute>) ? results[1] as List<BusRoute> : [];

    carData = (results[2] is List<Car>) ? results[2] as List<Car> : [];

    routeData = [...opRouteData, ...specialRouteData];
    final seen = <String>{};
    routeData.retainWhere((route) => seen.add(route.id));

    log("Static initialization complete.");
    log("Operational routes loaded: ${opRouteData.length}");
    log("Special routes loaded: ${specialRouteData.length}");
    log("Total combined routes: ${routeData.length}");
    log("Car data loaded: ${carData.length}");
  }

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  static BusRoute getRouteByIdSync(String routeId) {
    try {
      return routeData.firstWhere((r) => r.id == routeId);
    } catch (e) {
      // firstWhere 找不到會拋出 StateError，我們捕捉它並繼續。
    }

    if (allRouteData != null) {
      try {
        return allRouteData!.firstWhere((r) => r.id == routeId);
      } catch (e) {
        // 捕捉 StateError
      }
    }

    return BusRoute.unknown;
  }

  static Future<BusRoute> getRouteById(String routeId) async {
    try {
      final route = routeData.firstWhere((r) => r.id == routeId);
      return route;
    } catch (e) {
      // firstWhere 找不到會拋出 StateError，我們捕捉它並繼續。
    }

    if (allRouteData != null) {
      try {
        final route = allRouteData!.firstWhere((r) => r.id == routeId);
        return route;
      } catch (e) {
        // 捕捉 StateError
      }
    }

    return await fetchRouteDetailById(routeId) ?? BusRoute.unknown;
  }

  static Future<BusRoute?> fetchRouteDetailById(String routeId) async {
    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) {
      log("Error: Invalid routeId format for GraphQL query: $routeId");
      return null;
    }

    log("Fetching unknown route detail from API for ID: $routeId");
    try {
      final response = await dio.post(
        _graphqlApiUrl,
        data: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": {"routeId": routeIdInt, "lang": "zh"},
          "query": _graphqlQueryRouteDetail,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final routeNode = response.data['data']?['route'];
        if (routeNode is Map<String, dynamic>) {
          final newRoute = BusRoute.fromJson(routeNode);
          log("Successfully fetched detail for unknown route: ${newRoute.name} ($routeId)");
          if (!routeData.any((r) => r.id == newRoute.id)) {
            routeData.add(newRoute);
            log("Dynamically added route ${newRoute.name} to Static.routeData.");
          }
          return newRoute;
        }
      }
    } on DioException catch (e) {
      log("DioError fetching route detail for ID $routeId: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching route detail for ID $routeId: $e");
    }
    return null;
  }

  static Future<RouteDetail> fetchRoutePathAndStops(String routeId) async {
    if (_routeDetailCache.containsKey(routeId)) {
      log("Returning route detail for $routeId from cache.");
      return _routeDetailCache[routeId]!;
    }

    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) {
      log("Error: Invalid routeId format for path/stops query: $routeId");
      return RouteDetail.unknown;
    }

    log("Fetching route path and stops from API for ID: $routeId");
    try {
      final response = await dio.post(
        _graphqlApiUrl,
        data: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": {"routeId": routeIdInt, "lang": "zh"},
          "query": _graphqlQueryRoutePathAndStops,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final routeNode = response.data['data']?['route'];
        if (routeNode is Map<String, dynamic>) {
          final routeDetail = RouteDetail.fromJson(routeNode);
          _routeDetailCache[routeId] = routeDetail;
          log("Successfully fetched and cached path/stops for route $routeId.");
          return routeDetail;
        } else {
          log("Route node is null or not a map for ID $routeId. Response: ${response.data}");
        }
      } else {
        log("Failed to fetch path/stops for $routeId. Status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      log("DioError fetching path/stops for ID $routeId: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching path/stops for ID $routeId: $e");
    }
    return RouteDetail.unknown;
  }

  static Future<List<BusRoute>> fetchAllRoutes() async {
    if (allRouteData != null) {
      log("Returning all routes from cache.");
      return allRouteData!;
    }
    log("Cache empty. Fetching all routes from server...");
    final List<BusRoute> routes = await _fetchAllRoutesFromServer();
    allRouteData = routes;
    return routes;
  }

  static Future<List<BusRoute>> _fetchAllRoutesFromServer() async {
    final String url = "$apiBaseUrl/all_routes";
    log("Fetching all routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> routesJson = response.data;
        List<BusRoute> processedRoutes = routesJson
            .where((routeJson) => routeJson is Map<String, dynamic>)
            .map((routeJson) => BusRoute.fromJson(routeJson))
            .toList();
        log("Successfully fetched ${processedRoutes.length} routes from /all_routes.");
        return processedRoutes;
      } else {
        log("Failed to fetch all routes. Status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      log("DioError fetching all routes: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching all routes: $e");
    }
    log("Failed to fetch all routes. Returning empty list as a fallback.");
    return [];
  }

  static Future<List<BusRoute>> _fetchOpRoutesFromServer() async {
    log("Fetching operational routes from API: $_graphqlApiUrl");
    try {
      final response = await dio.post(
        _graphqlApiUrl,
        data: {
          "operationName": "QUERY_ROUTES",
          "variables": {"lang": "zh"},
          "query": _graphqlQueryRoutes,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final routesNode = response.data['data']?['routes'];
        if (routesNode != null && routesNode['edges'] is List) {
          final List<dynamic> routeEdges = routesNode['edges'];
          List<BusRoute> processedRoutes = routeEdges
              .where((edge) =>
                  edge is Map<String, dynamic> &&
                  edge['node'] is Map<String, dynamic>)
              .map((edge) =>
                  BusRoute.fromJson(Map<String, dynamic>.from(edge['node'])))
              .toList();
          log("Successfully fetched ${processedRoutes.length} operational routes from API.");
          return processedRoutes;
        }
      }
    } on DioException catch (e) {
      log("DioError fetching operational routes: ${e.message}");
    } catch (e, stackTrace) {
      log("Unexpected error fetching operational routes: $e\nStackTrace: $stackTrace");
    }
    log("Failed to fetch operational routes. Returning empty list.");
    return [];
  }

  static Future<List<BusRoute>> _fetchSpecialRoutesFromServer() async {
    final String url = "$apiBaseUrl/special_routes";
    log("Fetching special routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> routesJson = response.data;
        List<BusRoute> processedRoutes = routesJson
            .where((routeJson) => routeJson is Map<String, dynamic>)
            .map((routeJson) => BusRoute.fromJson(routeJson))
            .toList();
        log("Successfully fetched ${processedRoutes.length} special routes from API.");
        return processedRoutes;
      } else {
        log("Failed to fetch special routes. Status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      log("DioError fetching special routes: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching special routes: $e");
    }
    log("Failed to fetch special routes. Returning empty list as a fallback.");
    return [];
  }

  static Future<List<Car>> _fetchCarDataFromServer() async {
    final String url = "$apiBaseUrl/all_car_types";
    log("Fetching car data from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> carsJson = response.data;
        List<Car> processedCars = carsJson
            .where((carJson) => carJson is Map<String, dynamic>)
            .map((carJson) => Car.fromJson(carJson))
            .toList();
        log("Successfully fetched ${processedCars.length} cars from API.");
        return processedCars;
      }
    } on DioException catch (e) {
      log("DioError fetching car data: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching car data: $e");
    }
    log("Failed to fetch car data. Returning empty list.");
    return [];
  }

  static Map<String, dynamic> _parseRoute(String route) {
    String type = 'UNKNOWN';
    int? baseNum;
    String? baseStr;
    String suffixAlpha = '';
    String suffixNumeric = '';
    String suffixParenthesis = '';
    bool isSpecialTGood = false;
    RegExpMatch? match;
    if (route.startsWith('T')) {
      type = 'T';
      match = RegExp(r'^T(\d+)\(真好\)$').firstMatch(route);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        isSpecialTGood = true;
        suffixParenthesis = '(真好)';
      } else {
        match = RegExp(r'^T(\d+)([A-Z]*)(\(.*\))?$').firstMatch(route);
        if (match != null) {
          baseNum = int.tryParse(match.group(1)!);
          suffixAlpha = match.group(2) ?? '';
          suffixParenthesis = match.group(3) ?? '';
        } else {
          type = 'ALPHA';
          baseStr = route;
        }
      }
    } else if (RegExp(r'^\d').hasMatch(route)) {
      type = 'NUMERIC';
      match = RegExp(r'^(\d+)([A-ZN-S]*)(\(.*\))?$').firstMatch(route);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        suffixAlpha = match.group(2) ?? '';
        suffixParenthesis = match.group(3) ?? '';
      } else {
        baseNum = int.tryParse(route);
        if (baseNum == null) {
          type = 'ALPHA';
          baseStr = route;
        }
      }
    } else {
      type = 'ALPHA';
      match = RegExp(r'^([A-Z]+)(\d*)([A-Z]*)(\(.*\))?$').firstMatch(route);
      if (match != null) {
        baseStr = match.group(1)!;
        suffixNumeric = match.group(2) ?? '';
        suffixAlpha = match.group(3) ?? '';
        suffixParenthesis = match.group(4) ?? '';
      } else {
        baseStr = route;
      }
    }
    return {
      'original': route,
      'type': type,
      'baseNum': baseNum,
      'baseStr': baseStr,
      'suffixAlpha': suffixAlpha,
      'suffixNumeric': suffixNumeric,
      'suffixParenthesis': suffixParenthesis,
      'isSpecialTGood': isSpecialTGood,
    };
  }

  static int compareRoutes(String a, String b) {
    if (a == b) return 0;
    var pa = _parseRoute(a);
    var pb = _parseRoute(b);
    int typeOrder(String type) {
      if (type == 'NUMERIC') return 1;
      if (type == 'ALPHA') return 2;
      if (type == 'T') return 3;
      return 4;
    }

    int typeComparison = typeOrder(pa['type']).compareTo(typeOrder(pb['type']));
    if (typeComparison != 0) return typeComparison;
    if (pa['type'] == 'NUMERIC') {
      int baseNumComparison =
          (pa['baseNum'] ?? 0).compareTo(pb['baseNum'] ?? 0);
      if (baseNumComparison != 0) return baseNumComparison;
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pb['suffixParenthesis'] as String;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    } else if (pa['type'] == 'ALPHA') {
      int baseStrComparison =
          (pa['baseStr'] ?? '').compareTo(pb['baseStr'] ?? '');
      if (baseStrComparison != 0) return baseStrComparison;
      int paSuffixNumVal = (pa['suffixNumeric'] as String).isEmpty
          ? 0
          : int.parse(pa['suffixNumeric'] as String);
      int pbSuffixNumVal = (pb['suffixNumeric'] as String).isEmpty
          ? 0
          : int.parse(pb['suffixNumeric'] as String);
      int suffixNumComparison = paSuffixNumVal.compareTo(pbSuffixNumVal);
      if (suffixNumComparison != 0) return suffixNumComparison;
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pa['suffixParenthesis'] as String;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    } else if (pa['type'] == 'T') {
      int baseNumComparison =
          (pa['baseNum'] ?? 0).compareTo(pb['baseNum'] ?? 0);
      if (baseNumComparison != 0) return baseNumComparison;
      bool paIsSpecial = pa['isSpecialTGood'] as bool;
      bool pbIsSpecial = pb['isSpecialTGood'] as bool;
      if (paIsSpecial != pbIsSpecial) {
        return paIsSpecial ? -1 : 1;
      }
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pa['suffixParenthesis'] as String;
      if (paIsSpecial && pbIsSpecial) return 0;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    }
    return a.compareTo(b);
  }

  static bool hasDriverRemark(String driverId) {
    return localStorage.driverRemarks.containsKey(driverId);
  }

  static String? getDriverRemark(String driverId) {
    return localStorage.driverRemarks[driverId];
  }

  static String getDriverText(String driverId) {
    if (driverId == "0") {
      return "未知駕駛";
    }
    return hasDriverRemark(driverId)
        ? "$driverId(${getDriverRemark(driverId)})"
        : driverId;
  }
}
