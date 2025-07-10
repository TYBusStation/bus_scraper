// static.dart

import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'data/bus_route.dart';
import 'data/car.dart';
import 'data/route_detail.dart';

// 【新增】定義一個城市資料模型
class AppCity {
  final String code; // e.g., 'taoyuan'
  final String name; // e.g., '桃園市'

  const AppCity({required this.code, required this.name});
}

class Static {
  static Future<void>? _initFuture;

  // --- Constants ---
  static const String _primaryApiUrl = "https://myster.freeddns.org:25566";
  static const String _fallbackApiUrl =
      "http://192.168.1.159:25567"; // 使用 http 以便本地測試

  static final DateFormat apiDateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayDateFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  // 【修改】將 apiBaseUrl 變為內部變數，並提供一個公共的 getter
  static String _currentApiBaseUrl = _primaryApiUrl;

  static String get apiBaseUrl => _currentApiBaseUrl;

  // 【新增】定義可用的城市列表
  static const List<AppCity> availableCities = [
    AppCity(code: 'taoyuan', name: '桃園市'),
    AppCity(code: 'kaohsiung', name: '高雄市'),
  ];

  // 【修改】將 GraphQL API URL 改為動態 getter
  static String get govWebUrl {
    final city = localStorage.city;
    if (city == 'kaohsiung') {
      return "https://ibus.tbkc.gov.tw/ibus";
    }
    // 預設返回桃園的 URL
    return "https://ebus.tycg.gov.tw/ebus";
  }

  static String get _graphqlApiUrl {
    return "$govWebUrl/graphql";
  }

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

  static Future<void> forceSwitchApiAndReInit() {
    log("Force switching API triggered by user.");
    if (_currentApiBaseUrl == _primaryApiUrl) {
      _currentApiBaseUrl = _fallbackApiUrl;
      log("Switched to FALLBACK API: $_currentApiBaseUrl");
    } else {
      _currentApiBaseUrl = _primaryApiUrl;
      log("Switched to PRIMARY API: $_currentApiBaseUrl");
    }

    _routeDetailCache.clear(); // 清除快取，因為後端可能不同步
    allRouteData = null;
    _initFuture = null;
    return init();
  }

  static Future<void> _performInit() async {
    log("Static initialization started.");

    // 【關鍵修改】將 StorageHelper.init() 移到最前面
    await StorageHelper.init();

    log("Using API Base URL: $apiBaseUrl");
    log("Current city: ${localStorage.city}");

    try {
      // 測試 API 連線
      await dio.getUri(Uri.parse(apiBaseUrl));
      log("API server connection successful.");

      // 步驟 3: 平行獲取所有必要的啟動資料
      final results = await Future.wait([
        _fetchOpRoutesFromServer(),
        _fetchSpecialRoutesFromServer(),
        _fetchCarDataFromServer(),
      ], eagerError: true); // eagerError: true 可以在任何一個 future 失敗時立即失敗

      // 步驟 4: 安全地賦值
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
    } catch (e, stackTrace) {
      // 【關鍵】如果初始化過程中任何一步失敗，捕獲錯誤
      log("!!! CRITICAL: Static initialization failed !!!");
      log("Error: $e");
      log("StackTrace: $stackTrace");

      // 為所有 late final 變數提供一個安全的空列表作為預設值
      // 這樣 App 雖然沒有資料，但不會因為 LateInitializationError 而崩潰
      opRouteData = [];
      specialRouteData = [];
      routeData = [];
      carData = [];

      rethrow;
    }
  }

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  static BusRoute getRouteByIdSync(String routeId) {
    try {
      return routeData.firstWhere((r) => r.id == routeId);
    } catch (e) {
      /* Do nothing */
    }

    if (allRouteData != null) {
      try {
        return allRouteData!.firstWhere((r) => r.id == routeId);
      } catch (e) {
        /* Do nothing */
      }
    }

    return BusRoute.unknown;
  }

  static Future<BusRoute> getRouteById(String routeId) async {
    final route = getRouteByIdSync(routeId);
    if (route != BusRoute.unknown) return route;
    return await fetchRouteDetailById(routeId);
  }

  static Future<BusRoute> fetchRouteDetailById(String routeId) async {
    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) return BusRoute.unknown;

    log("Fetching unknown route detail from API for ID: $routeId");
    try {
      final response = await dio.post(
        _graphqlApiUrl, // 使用動態 getter
        data: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": {"routeId": routeIdInt, "lang": "zh"},
          "query": _graphqlQueryRouteDetail,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['route'] is Map) {
        final newRoute = BusRoute.fromJson(response.data['data']['route']);
        log("Successfully fetched detail for unknown route: ${newRoute.name} ($routeId)");
        if (!routeData.any((r) => r.id == newRoute.id)) {
          routeData.add(newRoute);
        }
        return newRoute;
      }
    } on DioException catch (e) {
      log("DioError fetching route detail for ID $routeId: ${e.message}");
    } catch (e, s) {
      log("Unexpected error fetching route detail for ID $routeId: $e");
    }
    return BusRoute.unknown;
  }

  static Future<RouteDetail> fetchRoutePathAndStops(String routeId) async {
    if (_routeDetailCache.containsKey(routeId)) {
      return _routeDetailCache[routeId]!;
    }

    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) return RouteDetail.unknown;

    log("Fetching route path and stops from API for ID: $routeId");
    try {
      final response = await dio.post(
        _graphqlApiUrl, // 使用動態 getter
        data: {
          "operationName": "QUERY_ROUTE_DETAIL",
          "variables": {"routeId": routeIdInt, "lang": "zh"},
          "query": _graphqlQueryRoutePathAndStops,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['route'] is Map) {
        final routeDetail =
            RouteDetail.fromJson(response.data['data']['route']);
        _routeDetailCache[routeId] = routeDetail;
        return routeDetail;
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
      return allRouteData!;
    }
    final List<BusRoute> routes = await _fetchAllRoutesFromServer();
    allRouteData = routes;
    return routes;
  }

  static Future<List<BusRoute>> _fetchAllRoutesFromServer() async {
    final String url = "$apiBaseUrl/${localStorage.city}/all_routes";
    log("Fetching all routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching all routes: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching all routes: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> _fetchOpRoutesFromServer() async {
    log("Fetching operational routes from API: $_graphqlApiUrl");
    try {
      final response = await dio.post(
        _graphqlApiUrl, // 使用動態 getter
        data: {
          "operationName": "QUERY_ROUTES",
          "variables": {"lang": "zh"},
          "query": _graphqlQueryRoutes,
        },
      );
      if (response.statusCode == 200 &&
          response.data?['data']?['routes']?['edges'] is List) {
        return (response.data['data']['routes']['edges'] as List)
            .map((edge) => BusRoute.fromJson(edge['node']))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching operational routes: ${e.message}");
    } catch (e, stackTrace) {
      log("Unexpected error fetching operational routes: $e\nStackTrace: $stackTrace");
    }
    return [];
  }

  static Future<List<BusRoute>> _fetchSpecialRoutesFromServer() async {
    final String url =
        "$apiBaseUrl/${Static.localStorage.city}/special_routes"; // 特殊路線是全域的，不分城市
    log("Fetching special routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching special routes: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching special routes: $e");
    }
    return [];
  }

  static Future<List<Car>> _fetchCarDataFromServer() async {
    final String url = "$apiBaseUrl/${localStorage.city}/all_car_types";
    log("Fetching car data from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((c) => Car.fromJson(c)).toList();
      }
    } on DioException catch (e) {
      log("DioError fetching car data: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching car data: $e");
    }
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
      String pbParen = pb['suffixParenthesis'] as String;
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
      String pbParen = pb['suffixParenthesis'] as String;
      if (paIsSpecial && pbIsSpecial) return 0;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    }
    return a.compareTo(b);
  }

  /// 檢查對於**當前城市**的特定駕駛員是否存在備註。
  static bool hasDriverRemark(String driverId) {
    // 1. 獲取當前選擇的城市
    final currentCity = localStorage.city;
    // 2. 呼叫 LocalStorage 中新的、正確的方法
    return localStorage.getRemarksForCity(currentCity).containsKey(driverId);
  }

  /// 獲取對於**當前城市**的特定駕駛員的備註。
  static String? getDriverRemark(String driverId) {
    // 1. 獲取當前選擇的城市
    final currentCity = localStorage.city;
    // 2. 呼叫 LocalStorage 中新的、正確的方法
    return localStorage.getRemarksForCity(currentCity)[driverId];
  }

  /// 獲取駕駛員的顯示文字（如果**當前城市**有備註，則包含備註）。
  static String getDriverText(String driverId) {
    if (driverId == "0") {
      return "未知駕駛";
    }
    // hasDriverRemark 和 getDriverRemark 現在已經是城市感知的了
    return hasDriverRemark(driverId)
        ? "$driverId(${getDriverRemark(driverId)})"
        : driverId;
  }
}
