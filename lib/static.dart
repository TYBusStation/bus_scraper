import 'dart:convert';

import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data/bus_route.dart';
import 'data/car.dart';

class Static {
  // --- *** 核心修改：新增一個靜態 Future 變數來緩存初始化結果 *** ---
  /// 這個變數會保存 `_performInit()` 返回的 Future。
  /// 它是可為空的（nullable），初始值為 null。
  static Future<void>? _initFuture;

  // --- Constants ---
  static final DateFormat dateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayDateFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  static String apiBaseUrl = "https://myster.freeddns.org:25566";
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

  // --- Dio Instance ---
  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {
      "Content-Type": "application/json",
    },
  ));

  // --- Local Storage ---
  static final LocalStorage localStorage = LocalStorage();

  // --- Static Data (late final) ---
  static late final List<BusRoute> opRouteData;
  static late final List<BusRoute> specialRouteData;
  static late final List<BusRoute> routeData;
  static late final List<Car> carData;

  // --- *** 核心修改：公開的 init 方法 *** ---
  /// 這個方法是給外部（如 FutureBuilder）調用的。
  /// 它確保底層的初始化邏輯 `_performInit` 只會被執行一次。
  static Future<void> init() {
    // 使用 '??=' (null-aware assignment) 運算子。
    // 如果 _initFuture 是 null，就執行 _performInit() 並將其返回的 Future 賦值給 _initFuture。
    // 如果 _initFuture 不是 null（表示已經開始或已完成初始化），則不執行右邊的表達式。
    _initFuture ??= _performInit();

    // 無論是第一次調用還是後續調用，都返回同一個 Future 實例。
    // FutureBuilder 會正確地等待這個唯一的 Future 完成。
    return _initFuture!;
  }

  // --- *** 核心修改：將原始的 init 邏輯移到一個私有方法中 *** ---
  /// 這個私有方法包含了所有實際的數據加載和初始化工作。
  /// 它只應該被上面的 `init()` 方法調用一次。
  static Future<void> _performInit() async {
    log("Static initialization started. (This should only run once)");

    await StorageHelper.init();
    specialRouteData =
        await _loadRoutesFromJsonAsset("special_route_data.json");

    await _testApi();

    try {
      final results = await Future.wait([
        _fetchOpRoutesFromServer(),
        _fetchCarDataFromServer(),
      ]);

      opRouteData = results[0] as List<BusRoute>;
      carData = results[1] as List<Car>;
    } catch (e) {
      log("Error during parallel data fetching: $e. Attempting individual fallbacks.");
      opRouteData = await _loadRoutesFromJsonAsset("op_route_data.json");
      carData = [];
    }

    routeData = [...opRouteData, ...specialRouteData];

    log("Static initialization complete.");
    log("Operational routes loaded: ${opRouteData.length}");
    log("Special routes loaded: ${specialRouteData.length}");
    log("Total combined routes: ${routeData.length}");
    log("Car data loaded: ${carData.length}");
  }

  static Future<void> _testApi() async {
    try {
      await dio.getUri(Uri.parse(apiBaseUrl));
    } on DioException catch (e) {
      log("DioError: $e.Changing apiBaseUrl.");
      apiBaseUrl = "http://192.168.1.159:25567";
    }
  }

  // --- Private Helper Methods (以下所有方法保持不變) ---

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
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
        final responseData = response.data;
        final routesNode = responseData['data']?['routes'];
        if (routesNode != null && routesNode['edges'] is List) {
          final List<dynamic> routeEdges = routesNode['edges'];
          if (routeEdges.isNotEmpty) {
            List<BusRoute> processedRoutes = [];
            for (var edge in routeEdges) {
              if (edge is Map<String, dynamic> &&
                  edge['node'] is Map<String, dynamic>) {
                Map<String, dynamic> routeInfo =
                    Map<String, dynamic>.from(edge['node']);
                processedRoutes.add(BusRoute.fromJson(routeInfo));
              } else {
                log("Warning: Skipping malformed operational route edge: $edge");
              }
            }
            log("Successfully fetched and processed ${processedRoutes.length} operational routes from API.");
            return processedRoutes;
          } else {
            log("API returned success, but operational route list is empty.");
          }
        } else {
          log("API returned success, but data structure for routes is unexpected: $responseData");
        }
      } else {
        log("Failed to fetch operational routes. Status: ${response.statusCode}, Message: ${response.statusMessage}, Data: ${response.data}");
      }
    } on DioException catch (e) {
      log("DioError fetching operational routes: ${e.message}${e.response != null ? " - Response: ${e.response?.data}" : ""}");
    } catch (e, stackTrace) {
      log("Unexpected error fetching or parsing operational routes: $e\nStackTrace: $stackTrace");
    }

    log("Falling back to local asset for operational routes (op_route_data.json).");
    return _loadRoutesFromJsonAsset("op_route_data.json");
  }

  static Future<List<Car>> _fetchCarDataFromServer() async {
    final String url = "$apiBaseUrl/all_car_types";
    log("Fetching car data from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          final List<dynamic> carsJson = response.data;
          if (carsJson.isNotEmpty) {
            List<Car> processedCars = [];
            for (var carJson in carsJson) {
              if (carJson is Map<String, dynamic>) {
                processedCars.add(Car.fromJson(carJson));
              } else {
                log("Warning: Skipping malformed car data item: $carJson");
              }
            }
            log("Successfully fetched and processed ${processedCars.length} cars from API.");
            return processedCars;
          } else {
            log("API returned success, but car list is empty.");
            return [];
          }
        } else {
          log("API returned success, but car data structure is unexpected (expected a List): ${response.data}");
        }
      } else {
        log("Failed to fetch car data. Status: ${response.statusCode}, Message: ${response.statusMessage}, Data: ${response.data}");
      }
    } on DioException catch (e) {
      log("DioError fetching car data: ${e.message}${e.response != null ? " - Response: ${e.response?.data}" : ""}");
    } catch (e, stackTrace) {
      log("Unexpected error fetching or parsing car data: $e\nStackTrace: $stackTrace");
    }

    log("Failed to fetch car data from API. Returning empty list as fallback.");
    return [];
  }

  static Future<List<BusRoute>> _loadRoutesFromJsonAsset(
      String fileName) async {
    log("Loading routes from asset: assets/$fileName");
    try {
      final String jsonString = await rootBundle.loadString("assets/$fileName");
      final List<dynamic> jsonData = jsonDecode(jsonString);

      List<BusRoute> assetRoutes = [];
      for (var routeJson in jsonData) {
        if (routeJson is Map<String, dynamic>) {
          assetRoutes.add(BusRoute.fromJson(routeJson));
        } else {
          log("Warning: Skipping malformed route data item in asset $fileName: $routeJson");
        }
      }
      log("Successfully loaded ${assetRoutes.length} routes from asset: $fileName");
      return assetRoutes;
    } catch (e, stackTrace) {
      log("Error loading or parsing routes from asset $fileName: $e\nStackTrace: $stackTrace");
      return [];
    }
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
}
