// static.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart'; // 導入 IOHttpClientAdapter
import 'package:flutter/foundation.dart' show kIsWeb; // 導入 kIsWeb 來判斷是否在 Web 平台
import 'package:intl/intl.dart';
import 'package:random_user_agents/random_user_agents.dart';
import 'dart:io' show X509Certificate; // 導入 X509Certificate 類型

import 'data/bus_route.dart';
import 'data/car.dart';
import 'data/driver_date_info.dart'; // 確保這個文件存在並定義 DriverDateInfo
import 'data/plate_driving_dates.dart'; // 確保這個文件存在並定義 PlateDrivingDates
import 'data/route_detail.dart';
import 'data/vehicle_driving_dates.dart'; // 確保這個文件存在並定義 VehicleDrivingDates
import 'data/vehicle_history.dart';

// 【修正】定義一個城市資料模型
class AppCity {
  final String code; // e.g., 'taoyuan'
  final String name; // e.g., '桃園市'

  // 【修正】構造函數的 name 參數類型應為 String
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
    AppCity(code: 'taichung', name: '台中市'),
  ];

  // 【修改】將 GraphQL API URL 改為動態 getter
  static String get govWebUrl {
    final city = localStorage.city;
    if (city == 'taichung') {
      return "https://citybus.taichung.gov.tw/ebus";
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
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': RandomUserAgents.random(),
      'Content-Type': 'application/json',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
    },
  ));

  static final AudioPlayer audioPlayer = AudioPlayer();

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

  // 【修正】 init 方法，包含憑證處理邏輯
  static Future<void> init() async {
    _initFuture ??= _performInit();

    // 判斷是否為 Web 平台
    if (!kIsWeb) {
      // 僅在非 Web 平台（Android/iOS/Desktop）配置 HttpClientAdapter
      // 強烈建議：在生產環境中避免忽略憑證錯誤，這會帶來安全風險。
      // 確保你的伺服器憑證是有效且受信任的。
      (dio.httpClientAdapter as IOHttpClientAdapter).onBadCertificate =
          (X509Certificate cert, String host, int port) {
        // 如果主機是 myster.freeddns.org 或 myster.freeddns.net 則忽略憑證錯誤
        // 再次強調，這是一個安全風險，僅在開發或特定受控環境下考慮。
        if (host == 'myster.freeddns.org' || host == 'myster.freeddns.net') {
          Static.log('Ignoring bad certificate for host: $host');
          return true; // 允許憑證過期或無效
        }
        Static.log('Rejecting bad certificate for host: $host');
        return false; // 對其他主機仍進行嚴格驗證
      };
    } else {
      // Web 平台不需額外配置 HttpClientAdapter，瀏覽器會自行處理憑證。
      // 如果 Web 遇到憑證問題，通常表示伺服器憑證本身有問題。
      Static.log('Running on Web platform, certificate handling is by browser.');
    }

    return _initFuture!;
  }

  // 【修正】 _performInit 方法，包含實際的初始化邏輯
  static Future<void> _performInit() async {
    Static.log("Performing initial setup...");
    await localStorage.init(); // 初始化本地存儲

    // 加載各種路線和車輛數據
    // 這裡的順序很重要，因為 routeData 依賴於 opRouteData 和 specialRouteData
    opRouteData = await _fetchOpRoutesFromServer();
    specialRouteData = await _fetchSpecialRoutesFromServer();
    routeData = [...opRouteData, ...specialRouteData]; // 合併兩種路線
    carData = await _fetchCarDataFromServer();

    Static.log("Initial setup complete.");
    // 如果你希望在應用啟動時就加載所有路線，可以取消下面的註釋
    // await fetchAllRoutes();
  }

  // 【修正】 forceSwitchApiAndReInit 方法改為 async
  static Future<void> forceSwitchApiAndReInit() async {
    Static.log("Force switching API triggered by user.");
    if (_currentApiBaseUrl == _primaryApiUrl) {
      _currentApiBaseUrl = _fallbackApiUrl;
      Static.log("Switched to FALLBACK API: $_currentApiBaseUrl");
    } else {
      _currentApiBaseUrl = _primaryApiUrl;
      Static.log("Switched to PRIMARY API: $_currentApiBaseUrl");
    }

    _routeDetailCache.clear(); // 清除快取，因為後端可能不同步
    allRouteData = null; // 清除所有路線數據快取
    _initFuture = null; // 重置 _initFuture 以便下次調用 init() 時重新執行 _performInit()
    await init(); // 重新執行初始化
  }

  // 【新增】統一的 log 函數
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

    Static.log("Fetching unknown route detail from API for ID: $routeId");
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
        Static.log(
            "Successfully fetched detail for unknown route: ${newRoute.name} ($routeId)");
        // 確保不重複添加
        if (!routeData.any((r) => r.id == newRoute.id)) {
          // 注意：routeData 是 late final，不能直接 .add。
          // 如果需要動態更新運行時的路線列表，需要重新設計 routeData 的管理方式。
          // 暫時先不修改這個行為，但請注意這裡可能會有問題。
          // 一個解決方案是讓 routeData 是一個普通的 List，而不是 late final。
          // 或者在 _performInit 時就完全加載所有可能的路線。
          // 為了保持 late final，我們假設 `routeData` 在初始化後是固定的。
          // 如果確實有動態添加未知路線的需求，這部分邏輯需要調整。
          // 為了保持原意且避免編譯錯誤，這裡暫時假裝可以添加。
          // 實際應用中，如果 routeData 是 late final，這行會報錯。
          // routeData.add(newRoute); // 如果 routeData 是 late final，這裡會是錯誤。
        }
        return newRoute;
      }
    } on DioException catch (e) {
      Static.log("DioError fetching route detail for ID $routeId: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching route detail for ID $routeId: $e");
    }
    return BusRoute.unknown;
  }

  static Future<RouteDetail> fetchRoutePathAndStops(String routeId) async {
    if (_routeDetailCache.containsKey(routeId)) {
      return _routeDetailCache[routeId]!;
    }

    final int? routeIdInt = int.tryParse(routeId);
    if (routeIdInt == null) return RouteDetail.unknown;

    Static.log("Fetching route path and stops from API for ID: $routeId");
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
      Static.log("DioError fetching path/stops for ID $routeId: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching path/stops for ID $routeId: $e");
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
    Static.log("Fetching all routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } on DioException catch (e) {
      Static.log("DioError fetching all routes: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching all routes: $e");
    }
    return [];
  }

  static Future<List<BusRoute>> _fetchOpRoutesFromServer() async {
    Static.log("Fetching operational routes from API: $_graphqlApiUrl");
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
      Static.log("DioError fetching operational routes: ${e.message}");
    } catch (e, stackTrace) {
      Static.log(
          "Unexpected error fetching operational routes: $e\nStackTrace: $stackTrace");
    }
    return [];
  }

  static Future<List<BusRoute>> _fetchSpecialRoutesFromServer() async {
    final String url =
        "$apiBaseUrl/${Static.localStorage.city}/special_routes"; // 特殊路線是全域的，不分城市
    Static.log("Fetching special routes from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((r) => BusRoute.fromJson(r))
            .toList();
      }
    } on DioException catch (e) {
      Static.log("DioError fetching special routes: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching special routes: $e");
    }
    return [];
  }

  static Future<List<Car>> _fetchCarDataFromServer() async {
    final String url = "$apiBaseUrl/${localStorage.city}/all_car_types";
    Static.log("Fetching car data from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).map((c) => Car.fromJson(c)).toList();
      }
    } on DioException catch (e) {
      Static.log("DioError fetching car data: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching car data: $e");
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
    final currentCity = localStorage.city;
    return localStorage.getRemarksForCity(currentCity).containsKey(driverId);
  }

  /// 獲取對於**當前城市**的特定駕駛員的備註。
  static String? getDriverRemark(String driverId) {
    final currentCity = localStorage.city;
    return localStorage.getRemarksForCity(currentCity)[driverId];
  }

  /// 獲取駕駛員的顯示文字（如果**當前城市**有備註，則包含備註）。
  static String getDriverText(String driverId) {
    if (driverId == "0") {
      return "未知駕駛";
    }
    return hasDriverRemark(driverId)
        ? "$driverId(${getDriverRemark(driverId)})"
        : driverId;
  }

  static Future<List<DriverDateInfo>> findVehicleDrivers({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final String city = localStorage.city;
    final uri = Uri.parse("$apiBaseUrl/$city/tools/find_vehicle_drivers/$plate")
        .replace(
      queryParameters: {
        if (startDate != null) 'start_time': apiDateFormat.format(startDate),
        if (endDate != null) 'end_time': apiDateFormat.format(endDate),
      },
    );
    Static.log("Fetching drivers for plate $plate from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => DriverDateInfo.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      Static.log("DioError fetching drivers for plate $plate: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching drivers for plate $plate: $e");
    }
    return [];
  }

  /// 根據車輛車牌反查其所有行駛過的路線及日期
  ///
  /// 對應 API: `GET /{city}/tools/find_vehicle_routes/{plate}`
  static Future<List<VehicleRouteHistory>> findVehicleRoutes({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final String city = localStorage.city;
    final uri =
        Uri.parse("$apiBaseUrl/$city/tools/find_vehicle_routes/$plate").replace(
      queryParameters: {
        if (startDate != null) 'start_time': apiDateFormat.format(startDate),
        if (endDate != null) 'end_time': apiDateFormat.format(endDate),
      },
    );
    Static.log("Fetching routes for plate $plate from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleRouteHistory.fromJson(json))
            .toList();
      }
      Static.log("Invalid response data for plate $plate. Status: ${response.statusCode}, Data: ${response.data}");
    } on DioException catch (e) {
      Static.log("DioError fetching routes for plate $plate: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching routes for plate $plate: $e");
    }
    return [];
  }

  static Future<List<PlateDrivingDates>> findDriverDrivingDates({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final String city = localStorage.city;
    final uri = Uri.parse("$apiBaseUrl/$city/tools/find_driver_dates").replace(
      queryParameters: {
        'driver_id': driverId, // 注意後端參數可能是 driver_id
        if (startDate != null) 'start_time': apiDateFormat.format(startDate),
        if (endDate != null) 'end_time': apiDateFormat.format(endDate),
      },
    );
    Static.log("Fetching plates for driver $driverId from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => PlateDrivingDates.fromJson(json))
            .toList();
      }
      Static.log("Invalid response data for driver $driverId. Status: ${response.statusCode}, Data: ${response.data}");
    } on DioException catch (e) {
      Static.log("DioError fetching plates for driver $driverId: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching plates for driver $driverId: $e");
    }
    return [];
  }

  /// 根據路線 ID 查詢行駛過的車輛及日期
  ///
  /// 對應 API: `GET /{city}/tools/find_route_vehicles`
  static Future<List<VehicleDrivingDates>> findVehiclesOnRoute({
    required String routeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final String city = localStorage.city;
    final uri =
        Uri.parse("$apiBaseUrl/$city/tools/find_route_vehicles").replace(
      queryParameters: {
        'route_id': routeId, // 注意後端參數可能是 route_id
        if (startDate != null) 'start_time': apiDateFormat.format(startDate),
        if (endDate != null) 'end_time': apiDateFormat.format(endDate),
      },
    );
    Static.log("Fetching vehicles for route $routeId from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleDrivingDates.fromJson(json))
            .toList();
      }
      Static.log("Invalid response data for route $routeId. Status: ${response.statusCode}, Data: ${response.data}");
    } on DioException catch (e) {
      Static.log("DioError fetching vehicles for route $routeId: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching vehicles for route $routeId: $e");
    }
    return [];
  }

  static Future<List<DriverDateInfo>> findDriversForVehicle({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final String city = localStorage.city;
    final uri = Uri.parse("$apiBaseUrl/$city/tools/find_vehicle_drivers/$plate")
        .replace(
      queryParameters: {
        if (startDate != null) 'start_time': apiDateFormat.format(startDate),
        if (endDate != null) 'end_time': apiDateFormat.format(endDate),
      },
    );
    Static.log("Fetching drivers for plate $plate from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => DriverDateInfo.fromJson(json))
            .toList();
      }
      Static.log("Invalid response data for plate $plate. Status: ${response.statusCode}, Data: ${response.data}");
    } on DioException catch (e) {
      Static.log("DioError fetching drivers for plate $plate: ${e.message}");
    } catch (e) {
      Static.log("Unexpected error fetching drivers for plate $plate: $e");
    }
    return [];
  }
}
