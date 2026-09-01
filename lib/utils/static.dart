import 'dart:convert';

import 'package:bus_scraper/storage/city.dart';
import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:random_user_agents/random_user_agents.dart';

import '../../data/bus_route.dart';
import '../../data/car.dart';
import '../../data/route_detail.dart';
import 'api_utils.dart';

abstract class Static {
  static Future<void>? _initFuture;
  static int _currentInitId = 0;

  static late final String announcementMarkdown;
  static late final String? currentVersion;
  static late final String? versionNotes;

  static const String _primaryApiUrl = "https://myster.freeddns.org:25566";
  static const String _fallbackApiUrl = "http://192.168.1.249:25567";
  static String _currentApiBaseUrl = _primaryApiUrl;

  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': RandomUserAgents.random(),
      'Content-Type': 'application/json',
    },
  ));

  static final LocalStorage localStorage = LocalStorage();

  static late List<BusRoute> opRouteData;
  static late List<BusRoute> specialRouteData;
  static late List<BusRoute> routeData;
  static late List<Car> carData;
  static List<BusRoute>? allRouteData;
  static final Map<String, RouteDetail> routeDetailCache = {};

  static String get apiBaseUrl => _currentApiBaseUrl;

  static City get city => localStorage.city;

  static String get graphqlUrl =>
      "${city.url.replaceAll(RegExp(r'/$'), '')}/ebus/graphql";

  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  static Future<void> init() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

  static Future<void> forceSwitchApiAndReInit() {
    if (_currentApiBaseUrl == _primaryApiUrl) {
      _currentApiBaseUrl = _fallbackApiUrl;
      log("已切換至備用 API: $_currentApiBaseUrl");
    } else {
      _currentApiBaseUrl = _primaryApiUrl;
      log("已切換至主要 API: $_currentApiBaseUrl");
    }

    routeDetailCache.clear();
    allRouteData = null;
    _initFuture = null;
    _currentInitId++;
    return init();
  }

  static Future<void> _performInit() async {
    final int initId = _currentInitId;
    log("靜態資源初始化開始 (ID: $initId)...");

    await StorageHelper.init();
    log("目前城市: ${city.name} (${city.code}), API: $apiBaseUrl");

    try {
      await dio.getUri(Uri.parse(apiBaseUrl));
      log("後端 API 伺服器連線成功。");

      final opRoutesFuture = (city == City.taipei)
          ? ApiUtils.fetchTaipeiOpRoutes()
          : ApiUtils.fetchGraphQLOpRoutes();

      final results = await Future.wait([
        opRoutesFuture,
        ApiUtils.fetchSpecialRoutes(),
        ApiUtils.fetchCarData(),
        ApiUtils.fetchAnnouncement(),
        _fetchVersionInfoFromServer(),
      ], eagerError: true);

      if (initId != _currentInitId) {
        log("初始化 (ID: $initId) 已過期，中止程序。");
        return;
      }

      opRouteData = (results[0] as List<BusRoute>?) ?? [];
      specialRouteData = (results[1] as List<BusRoute>?) ?? [];
      carData = (results[2] as List<Car>?) ?? [];
      announcementMarkdown = results[3] as String? ?? '公告載入失敗';

      final versionInfo = results[4] as Map<String, String?>;
      currentVersion = versionInfo['version'];
      versionNotes = versionInfo['notes'];

      routeData = [...opRouteData, ...specialRouteData];
      final seen = <String>{};
      routeData.retainWhere((route) => seen.add(route.id));

      log("靜態資源初始化完成 (共 ${routeData.length} 條路線, ${carData.length} 台車輛)。");
    } catch (e, stackTrace) {
      if (initId != _currentInitId) {
        log("忽略來自過期初始化 (ID: $initId) 的錯誤: $e");
        return;
      }
      log("!!! 靜態資源初始化失敗 (ID: $initId) !!!");
      log("錯誤詳情: $e");

      opRouteData = [];
      specialRouteData = [];
      routeData = [];
      carData = [];
      announcementMarkdown = '載入失敗，請檢查網路連線後重新啟動應用程式。\n錯誤碼: $e';
      currentVersion = '未知';
      versionNotes = '無法從伺服器獲取更新日誌。';

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
      log("讀取版本資訊失敗: $e");
      return {'version': '版本讀取失敗', 'notes': '無法讀取 versions.json'};
    }
  }
}
