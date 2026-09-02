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
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
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

  static String get graphqlUrl => "${city.url}/ebus/graphql";

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
    log("使用 API: $apiBaseUrl, 城市: ${city.name}");

    try {
      await dio.getUri(Uri.parse(apiBaseUrl));
      log("API 伺服器連線成功。");

      final opRoutesFuture = ApiUtils.fetchOpRoutes();

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

      log("靜態資源初始化完成。");
    } catch (e, stackTrace) {
      if (initId != _currentInitId) {
        log("忽略來自過期初始化 (ID: $initId) 的錯誤: $e");
        return;
      }
      log("!!! 嚴重：靜態資源初始化失敗 (ID: $initId) !!!");
      log("錯誤: $e");
      log("堆疊追蹤: $stackTrace");
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
      log("讀取版本資訊時發生錯誤: $e");
      return {'version': '未知版本', 'notes': '更新日誌載入失敗: $e'};
    }
  }
}
