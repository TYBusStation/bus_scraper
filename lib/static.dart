import 'dart:convert';

import 'package:bus_scraper/storage/city.dart';
import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:random_user_agents/random_user_agents.dart';

import 'data/bus_route.dart';
import 'data/car.dart';
import 'data/route_detail.dart';
import 'data/vehicle_history.dart';

class Static {
  static Future<void>? _initFuture;
  static int _currentInitId = 0;

  static late final String announcementMarkdown;
  static late final String? currentVersion;
  static late final String? versionNotes;

  static const String _primaryApiUrl = "https://myster.freeddns.org:25566";
  static const String _fallbackApiUrl = "http://192.168.1.159:25567";

  static final DateFormat apiTimeFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayTimeFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat displayDateFormat = DateFormat('yyyy/MM/dd');

  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");
  static String _currentApiBaseUrl = _primaryApiUrl;

  static String get apiBaseUrl => _currentApiBaseUrl;

  static City get city => localStorage.city;

  static String get _graphqlUrl => "${city.url}/graphql";

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

  static final LocalStorage localStorage = LocalStorage();

  static late final List<BusRoute> opRouteData;
  static late final List<BusRoute> specialRouteData;
  static late final List<BusRoute> routeData;
  static late List<Car> carData;
  static List<BusRoute>? allRouteData;
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
    _routeDetailCache.clear();
    allRouteData = null;
    _initFuture = null;
    _currentInitId++;
    log("Initialization ID incremented to: $_currentInitId");
    return init();
  }

  static Future<void> _performInit() async {
    final int initId = _currentInitId;
    log("Static initialization started with ID: $initId.");
    await StorageHelper.init();
    log("Using API Base URL: $apiBaseUrl");
    log("Current city: $city");
    try {
      await dio.getUri(Uri.parse(apiBaseUrl));
      log("API server connection successful for ID: $initId.");
      final results = await Future.wait([
        _fetchOpRoutesFromServer(),
        _fetchSpecialRoutesFromServer(),
        _fetchCarDataFromServer(),
        _fetchAnnouncementFromServer(),
        _fetchVersionInfoFromServer(),
      ], eagerError: true);
      if (initId != _currentInitId) {
        log("Initialization with ID: $initId is outdated. Aborting assignment.");
        return;
      }
      log("Initialization with ID: $initId is current. Proceeding with assignment.");
      opRouteData =
          (results[0] is List<BusRoute>) ? results[0] as List<BusRoute> : [];
      specialRouteData =
          (results[1] is List<BusRoute>) ? results[1] as List<BusRoute> : [];
      carData = (results[2] is List<Car>) ? results[2] as List<Car> : [];
      announcementMarkdown = results[3] as String;
      final versionInfo = results[4] as Map<String, String?>;
      currentVersion = versionInfo['version'];
      versionNotes = versionInfo['notes'];
      routeData = [...opRouteData, ...specialRouteData];
      final seen = <String>{};
      routeData.retainWhere((route) => seen.add(route.id));
      log("Static initialization complete for ID: $initId.");
      log("Operational routes loaded: ${opRouteData.length}");
      log("Special routes loaded: ${specialRouteData.length}");
      log("Total combined routes: ${routeData.length}");
      log("Car data loaded: ${carData.length}");
    } catch (e, stackTrace) {
      if (initId != _currentInitId) {
        log("Ignoring error from outdated initialization with ID: $initId. Error: $e");
        return;
      }
      log("!!! CRITICAL: Static initialization failed for ID: $initId !!!");
      log("Error: $e");
      log("StackTrace: $stackTrace");
      opRouteData = [];
      specialRouteData = [];
      routeData = [];
      carData = [];
      announcementMarkdown = '公告載入失敗：\n$e';
      currentVersion = '未知版本';
      versionNotes = '更新日誌載入失敗。';
      rethrow;
    }
  }

  static Future<void> updateCarData() async {
    log("Attempting to update carData from server...");
    try {
      final List<Car> updatedCarData = await _fetchCarDataFromServer();
      carData = updatedCarData;
      log("Successfully updated carData. Total cars: ${carData.length}");
    } catch (e) {
      log("!!! FAILED to update carData: $e !!!");
      rethrow;
    }
  }

  static Future<Map<String, String?>> _fetchVersionInfoFromServer() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr =
          '${packageInfo.version}+${packageInfo.buildNumber}';
      final jsonString = await rootBundle.loadString('assets/versions.json');
      final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'version': currentVersionStr,
        'notes': decodedJson[currentVersionStr]?.toString(),
      };
    } catch (e) {
      log("Error fetching version info: $e");
      return {
        'version': '未知版本',
        'notes': '更新日誌載入失敗: $e',
      };
    }
  }

  static Future<String> _fetchAnnouncementFromServer() async {
    String url = "$apiBaseUrl/announcement";
    log("Fetching announcement from API: $url");
    try {
      final response = await dio.getUri(Uri.parse(url));
      if (response.statusCode == 200 && response.data is String) {
        return response.data;
      }
      return '無法載入公告 (狀態碼: ${response.statusCode})';
    } catch (e) {
      log("Error fetching announcement: $e");
      return '載入公告失敗，請檢查您的網路連線。';
    }
  }

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  static BusRoute getRouteByIdSync(String routeId) {
    try {
      return routeData.firstWhere((r) => r.id == routeId);
    } catch (e) {
      // Do nothing
    }
    if (allRouteData != null) {
      try {
        return allRouteData!.firstWhere((r) => r.id == routeId);
      } catch (e) {
        // Do nothing
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
        _graphqlUrl,
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
    } catch (e) {
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
        _graphqlUrl,
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
    final String url = "$apiBaseUrl/${city.code}/all_routes";
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
    log("Fetching operational routes from API: $_graphqlUrl");
    try {
      final response = await dio.post(
        _graphqlUrl,
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
    final String url = "$apiBaseUrl/${city.code}/special_routes";
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
    final String url = "$apiBaseUrl/${city.code}/all_car_types";
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

  static bool hasDriverRemark(String driverId) {
    return localStorage.getRemarksForCity(city).containsKey(driverId);
  }

  static String? getDriverRemark(String driverId) {
    return localStorage.getRemarksForCity(city)[driverId];
  }

  static String getDriverText(String driverId) {
    if (driverId == "0") {
      return "未知駕駛長";
    }
    return hasDriverRemark(driverId)
        ? "$driverId(${getDriverRemark(driverId)})"
        : driverId;
  }

  static Future<List<VehicleRouteHistory>> findVehicleRoutes({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri =
        Uri.parse("$apiBaseUrl/${city.code}/tools/find_vehicle_routes/$plate")
            .replace(
      queryParameters: {
        if (startDate != null) 'start_time': apiTimeFormat.format(startDate),
        if (endDate != null) 'end_time': apiTimeFormat.format(endDate),
      },
    );
    log("Fetching routes for plate $plate from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleRouteHistory.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching routes for plate $plate: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching routes for plate $plate: $e");
    }
    return [];
  }

  static Future<List<PlateDrivingDates>> findDriverDrivingDates({
    required String driverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri =
        Uri.parse("$apiBaseUrl/${city.code}/tools/find_driver_dates").replace(
      queryParameters: {
        'driver_id': driverId,
        if (startDate != null) 'start_time': apiTimeFormat.format(startDate),
        if (endDate != null) 'end_time': apiTimeFormat.format(endDate),
      },
    );
    log("Fetching plates for driver $driverId from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => PlateDrivingDates.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching plates for driver $driverId: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching plates for driver $driverId: $e");
    }
    return [];
  }

  static Future<List<VehicleDrivingDates>> findVehiclesOnRoute({
    required String routeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri =
        Uri.parse("$apiBaseUrl/${city.code}/tools/find_route_vehicles").replace(
      queryParameters: {
        'route_id': routeId,
        if (startDate != null) 'start_time': apiTimeFormat.format(startDate),
        if (endDate != null) 'end_time': apiTimeFormat.format(endDate),
      },
    );
    log("Fetching vehicles for route $routeId from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => VehicleDrivingDates.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching vehicles for route $routeId: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching vehicles for route $routeId: $e");
    }
    return [];
  }

  static Future<List<DriverDateInfo>> findDriversForVehicle({
    required String plate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri =
        Uri.parse("$apiBaseUrl/${city.code}/tools/find_vehicle_drivers/$plate")
            .replace(
      queryParameters: {
        if (startDate != null) 'start_time': apiTimeFormat.format(startDate),
        if (endDate != null) 'end_time': apiTimeFormat.format(endDate),
      },
    );
    log("Fetching drivers for plate $plate from API: $uri");
    try {
      final response = await dio.getUri(uri);
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => DriverDateInfo.fromJson(json))
            .toList();
      }
    } on DioException catch (e) {
      log("DioError fetching drivers for plate $plate: ${e.message}");
    } catch (e) {
      log("Unexpected error fetching drivers for plate $plate: $e");
    }
    return [];
  }

  static final DateTime _firstSelectableDate = DateTime(2025, 6, 8);

  static Future<void> selectDateTime({
    required BuildContext context,
    required bool isStart,
    required DateTimeRange currentRange,
    required DateTime lastSelectableDate,
    required bool pickTime,
    required Duration maxDuration,
    required void Function(DateTimeRange newRange) onDateTimeChanged,
  }) async {
    final DateTime initialPickerDate =
        isStart ? currentRange.start : currentRange.end;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialPickerDate.isAfter(lastSelectableDate)
          ? lastSelectableDate
          : (initialPickerDate.isBefore(_firstSelectableDate)
              ? _firstSelectableDate
              : initialPickerDate),
      firstDate: _firstSelectableDate,
      lastDate: lastSelectableDate,
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate == null || !context.mounted) return;

    final DateTime newDateTime;

    if (pickTime) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialPickerDate),
        helpText: isStart ? '選擇開始時間' : '選擇結束時間',
      );

      if (pickedTime == null) return;

      newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    } else {
      newDateTime = isStart
          ? DateTime(pickedDate.year, pickedDate.month, pickedDate.day)
          : DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59,
              59, 999);
    }

    var newStart = currentRange.start;
    var newEnd = currentRange.end;

    if (isStart) {
      newStart = newDateTime;
      if (newStart.isAfter(newEnd)) {
        newEnd = newStart.add(const Duration(minutes: 1)); // 保持一個微小的有效範圍
      }
      if (newEnd.difference(newStart) > maxDuration) {
        newEnd = newStart.add(maxDuration);
      }
      if (newEnd.isAfter(lastSelectableDate)) {
        newEnd = lastSelectableDate;
        if (newStart.isAfter(newEnd)) {
          newStart = newEnd.subtract(const Duration(minutes: 1));
        }
      }
    } else {
      newEnd = newDateTime;
      if (newEnd.isBefore(newStart)) {
        newStart = newEnd.subtract(const Duration(minutes: 1));
      }
      if (newEnd.difference(newStart) > maxDuration) {
        newStart = newEnd.subtract(maxDuration);
      }
      if (newStart.isBefore(_firstSelectableDate)) {
        newStart = _firstSelectableDate;
        if (newEnd.isBefore(newStart)) {
          newEnd = newStart.add(const Duration(minutes: 1));
        }
      }
    }

    onDateTimeChanged(DateTimeRange(start: newStart, end: newEnd));
  }
}
