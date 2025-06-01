import 'dart:convert';

import 'package:bus_scraper/storage/local_storage.dart';
import 'package:bus_scraper/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data/bus_route.dart';
import 'data/car.dart';

class Static {
  static DateFormat dateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");

  static final LocalStorage localStorage = LocalStorage();
  static final Dio dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5)));

  static const String api = "http://myster.ddns.net:25566";

  // static const String api = "http://192.168.1.159:25566";

//   static const String api = "http://localhost:8000";
//  static const String api = "http://192.168.1.207:8000";

  static const String GRAPHQL_QUERY = """
query QUERY_ROUTES(\$lang: String!) {
  routes(lang: \$lang) {
    edges {
      node {
        id
        name
        opType
        routeGroup
        description
        providers {
          edges {
            node {
              name
            }
          }
        }
      }
    }
  }
}
""";

  static late final List<BusRoute> opRouteData;
  static late final List<BusRoute> specialRouteData;
  static late final List<BusRoute> routeData;
  static late final List<Car> carData;

  static Future<void> staticInit() async {
    await StorageHelper.init();
    dio.options.headers = {
      "Content-Type": "application/json",
    };
    specialRouteData = await loadRoutesFromJsonAsset("special_route_data.json");
    try {
      final response =
          await dio.post("https://ebus.tycg.gov.tw/ebus/graphql", data: {
        "operationName": "QUERY_ROUTES",
        "variables": {
          "lang": "zh",
        },
        "query": GRAPHQL_QUERY,
      });
      if (response.statusCode == 200) {
        final responseData = response.data;
        // 根據 GraphQL 的回傳結構，我們需要深入到 'data' -> 'routes' -> 'edges'
        if (responseData != null &&
            responseData['data'] != null &&
            responseData['data']['routes'] != null) {
          final List<dynamic> routeEdges =
              responseData['data']['routes']['edges'] as List<dynamic>? ?? [];
          // 解析 routes 並賦值給 late final 變數
          // 確保 routes 只被賦值一次
          if (routeEdges.isNotEmpty) {
            List<BusRoute> processedRoutes = [];
            for (var edge in routeEdges) {
              if (edge is! Map<String, dynamic> ||
                  !edge.containsKey('node') ||
                  edge['node'] is! Map<String, dynamic>) {
                print("[${DateTime.now()}] 警告: 跳過格式錯誤的邊緣: $edge");
                continue;
              }

              Map<String, dynamic> routeInfo =
                  Map<String, dynamic>.from(edge['node']); // 創建可修改的副本

              // 處理提供者資訊：提取 name，確保它始終是一個列表
              List<String> providerNames = [];
              if (routeInfo.containsKey('providers') &&
                  routeInfo['providers'] is Map<String, dynamic> &&
                  routeInfo['providers'].containsKey('edges') &&
                  routeInfo['providers']['edges'] is List) {
                final List<dynamic> providerEdges =
                    routeInfo['providers']['edges'];
                for (var pEdge in providerEdges) {
                  if (pEdge is Map<String, dynamic> &&
                      pEdge.containsKey('node') &&
                      pEdge['node'] is Map<String, dynamic> &&
                      pEdge['node'].containsKey('name') &&
                      pEdge['node']['name'] is String) {
                    providerNames.add(pEdge['node']['name']);
                  }
                }
              }
              // Python 腳本將處理後的 providers 列表直接賦值回 routeInfo['providers']
              // Dart 中，我們直接將這個名稱列表用於創建 Route 物件
              routeInfo['providers'] =
                  providerNames; // 更新 routeInfo 中的 providers 欄位 (雖然 Route.fromProcessedNode 會直接用)

              processedRoutes.add(BusRoute.fromJson(routeInfo));
            }

            print("[${DateTime.now()}] 成功獲取並處理了 ${processedRoutes.length} 條路線");
            opRouteData = processedRoutes;
          } else {
            print('API 回傳成功，但路線列表為空');
            opRouteData = await loadRoutesFromJsonAsset("op_route_data.json");
          }
        } else {
          print('API 回傳成功，但資料結構不符合預期: $responseData');
          opRouteData = await loadRoutesFromJsonAsset("op_route_data.json");
        }
      } else {
        print('請求失敗，狀態碼: ${response.statusCode}');
        print('錯誤訊息: ${response.statusMessage}');
        print('回應內容: ${response.data}');
        opRouteData = await loadRoutesFromJsonAsset("op_route_data.json");
      }
    } catch (e) {
      print('解析資料或發生其他未預期錯誤: $e');
      opRouteData = await loadRoutesFromJsonAsset("op_route_data.json");
    }

    routeData = opRouteData + specialRouteData;
    await staticInit2();
  }

  static Future<void> staticInit2() async {
    try {
      final response = await dio.getUri(
        Uri.parse("$api/all_car_types"),
      );
      if (response.statusCode == 200) {
        final responseData = response.data;
        // 根據 GraphQL 的回傳結構，我們需要深入到 'data' -> 'routes' -> 'edges'
        if (responseData != null) {
          final List<dynamic> cars = responseData as List<dynamic>? ?? [];
          // 解析 routes 並賦值給 late final 變數
          // 確保 routes 只被賦值一次
          if (cars.isNotEmpty) {
            List<Car> processedCars = [];
            for (var carJson in cars) {
              if (carJson is Map<String, dynamic>) {
                processedCars.add(Car.fromJson(carJson));
              }
            }
            carData = processedCars;
          } else {
            print('API 回傳成功，但路線列表為空');
            carData = [];
          }
        } else {
          print('API 回傳成功，但資料結構不符合預期: $responseData');
          carData = [];
        }
      } else {
        print('請求失敗，狀態碼: ${response.statusCode}');
        print('錯誤訊息: ${response.statusMessage}');
        print('回應內容: ${response.data}');
        carData = [];
      }
    } catch (e) {
      print('解析資料或發生其他未預期錯誤: $e');
      carData = [];
    }
  }

  static Future<List<BusRoute>> loadRoutesFromJsonAsset(String fileName) async {
    final List<BusRoute> routeData = [];
    try {
      // 1. 從 assets 載入 JSON 字串
      final String jsonString = await rootBundle.loadString("assets/$fileName");

      // 2. 解析 JSON 字串為 Map<String, dynamic>
      // 假設你的 JSON 根結構直接就是 GraphQL 回應的樣子，
      final List<dynamic> jsonData = jsonDecode(jsonString);

      for (Map<String, dynamic> route in jsonData) {
        routeData.add(BusRoute.fromJson(route));
      }
    } catch (e) {
      print('從 assets 載入或解析 JSON 時發生錯誤: $e');
      rethrow; // 重新拋出錯誤，讓調用者處理
    }
    return routeData;
  }
}
