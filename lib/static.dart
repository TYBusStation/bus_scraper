import 'dart:convert';

import 'package:bus_scraper/storage/local_storage.dart'; // Assuming LocalStorage is used by StorageHelper or elsewhere
import 'package:bus_scraper/storage/storage.dart'; // For StorageHelper
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data/bus_route.dart'; // Your BusRoute model
import 'data/car.dart'; // Your Car model

class Static {
  // --- Constants ---
  static DateFormat dateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");

  // TODO: Verify the purpose of this RegExp.
  // If it's to check if a string consists ONLY of alphanumeric characters:
  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  // If it's to check if a string CONTAINS an alphanumeric character:
  // static RegExp letterNumber = RegExp(r"[a-zA-Z0-9]");
  // The original RegExp(r"^a-zA-Z0-9") was incorrect as it matched a literal string.

  // API Endpoints - Consider moving to a config file or environment variables for flexibility
  static const String apiBaseUrl = "https://myster.freeddns.org:25566";

  // static const String apiBaseUrl =
  //     "http://192.168.1.159:25567"; // Active API base URL
  // static const String apiBaseUrl = "http://localhost:8000";
  // static const String apiBaseUrl = "http://192.168.1.207:8000";

  static const String _allCarTypesEndpoint = "/all_car_types";
  static const String _graphqlApiUrl = "https://ebus.tycg.gov.tw/ebus/graphql";

  static const String _graphqlQueryRoutes = """
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

  // --- Dio Instance ---
  // Initialize Dio with base options and headers
  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10), // Increased timeout slightly
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      "Content-Type": "application/json",
      // Add other common headers if needed, e.g., "Accept": "application/json"
    },
  ));

  // --- Local Storage ---
  // Assuming LocalStorage is used somewhere, keeping it if necessary.
  // If not used directly in Static, it might belong elsewhere or only be used by StorageHelper.
  static final LocalStorage localStorage = LocalStorage();

  // --- Static Data (late final) ---
  // These will be initialized by the init() method.
  static late final List<BusRoute> opRouteData;
  static late final List<BusRoute> specialRouteData;
  static late final List<BusRoute>
      routeData; // Combined opRouteData and specialRouteData
  static late final List<Car> carData;

  // --- Initialization ---
  /// Initializes static data by fetching from APIs and local assets.
  /// This method should be called once at app startup.
  static Future<void> init() async {
    _log("Static initialization started.");

    // Initialize storage helper (if it has its own async setup)
    await StorageHelper.init();

    // Load special routes from local assets first, as it's reliable and fast.
    specialRouteData =
        await _loadRoutesFromJsonAsset("special_route_data.json");

    // Fetch operational routes and car data concurrently.
    try {
      final results = await Future.wait([
        _fetchOpRoutesFromServer(),
        _fetchCarDataFromServer(),
      ]);

      opRouteData = results[0] as List<BusRoute>;
      carData = results[1] as List<Car>;
    } catch (e) {
      // If Future.wait throws (e.g., one of the futures rejects and it's not caught inside them),
      // we ensure a graceful fallback.
      _log(
          "Error during parallel data fetching: $e. Attempting individual fallbacks.");
      opRouteData = await _loadRoutesFromJsonAsset(
          "op_route_data.json"); // Fallback for opRouteData
      carData = []; // Fallback for carData
    }

    // Combine operational and special routes.
    // Using a spread operator for a new list to ensure immutability of originals if needed.
    routeData = [...opRouteData, ...specialRouteData];

    _log("Static initialization complete.");
    _log("Operational routes loaded: ${opRouteData.length}");
    _log("Special routes loaded: ${specialRouteData.length}");
    _log("Total combined routes: ${routeData.length}");
    _log("Car data loaded: ${carData.length}");
  }

  // --- Private Helper Methods ---

  /// Logs a message with a timestamp and class context.
  static void _log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  /// Fetches operational bus routes from the GraphQL API.
  /// Falls back to a local asset if the API request fails.
  static Future<List<BusRoute>> _fetchOpRoutesFromServer() async {
    _log("Fetching operational routes from API: $_graphqlApiUrl");
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
        // Defensive parsing of GraphQL structure
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

                // Standardize provider information to a list of names
                List<String> providerNames = [];
                final providersData = routeInfo['providers'];
                if (providersData is Map<String, dynamic> &&
                    providersData['edges'] is List) {
                  for (var pEdge in providersData['edges']) {
                    if (pEdge is Map<String, dynamic> &&
                        pEdge['node'] is Map<String, dynamic> &&
                        pEdge['node']['name'] is String) {
                      providerNames.add(pEdge['node']['name']);
                    }
                  }
                }
                routeInfo['providers'] =
                    providerNames; // Replace original providers structure

                processedRoutes.add(BusRoute.fromJson(routeInfo));
              } else {
                _log(
                    "Warning: Skipping malformed operational route edge: $edge");
              }
            }
            _log(
                "Successfully fetched and processed ${processedRoutes.length} operational routes from API.");
            return processedRoutes;
          } else {
            _log("API returned success, but operational route list is empty.");
          }
        } else {
          _log(
              "API returned success, but data structure for routes is unexpected: $responseData");
        }
      } else {
        _log(
            "Failed to fetch operational routes. Status: ${response.statusCode}, Message: ${response.statusMessage}, Data: ${response.data}");
      }
    } on DioException catch (e) {
      _log(
          "DioError fetching operational routes: ${e.message}${e.response != null ? " - Response: ${e.response?.data}" : ""}");
    } catch (e, stackTrace) {
      _log(
          "Unexpected error fetching or parsing operational routes: $e\nStackTrace: $stackTrace");
    }

    _log(
        "Falling back to local asset for operational routes (op_route_data.json).");
    return _loadRoutesFromJsonAsset("op_route_data.json");
  }

  /// Fetches car data from the API.
  /// Falls back to an empty list if the API request fails.
  static Future<List<Car>> _fetchCarDataFromServer() async {
    const String url = "$apiBaseUrl$_allCarTypesEndpoint";
    _log("Fetching car data from API: $url");
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
                _log("Warning: Skipping malformed car data item: $carJson");
              }
            }
            _log(
                "Successfully fetched and processed ${processedCars.length} cars from API.");
            return processedCars;
          } else {
            _log("API returned success, but car list is empty.");
            return []; // Return empty list if API response is an empty list
          }
        } else {
          _log(
              "API returned success, but car data structure is unexpected (expected a List): ${response.data}");
        }
      } else {
        _log(
            "Failed to fetch car data. Status: ${response.statusCode}, Message: ${response.statusMessage}, Data: ${response.data}");
      }
    } on DioException catch (e) {
      _log("DioError fetching car data: ${e.message}" +
          (e.response != null ? " - Response: ${e.response?.data}" : ""));
    } catch (e, stackTrace) {
      _log(
          "Unexpected error fetching or parsing car data: $e\nStackTrace: $stackTrace");
    }

    _log(
        "Failed to fetch car data from API. Returning empty list as fallback.");
    return []; // Fallback to an empty list
  }

  /// Loads and parses bus routes from a JSON file in the assets folder.
  /// Returns an empty list on error to ensure fallbacks are safe.
  static Future<List<BusRoute>> _loadRoutesFromJsonAsset(
      String fileName) async {
    _log("Loading routes from asset: assets/$fileName");
    try {
      final String jsonString = await rootBundle.loadString("assets/$fileName");
      // Assuming the root of the JSON asset is a list of route objects
      final List<dynamic> jsonData = jsonDecode(jsonString);

      List<BusRoute> assetRoutes = [];
      for (var routeJson in jsonData) {
        if (routeJson is Map<String, dynamic>) {
          assetRoutes.add(BusRoute.fromJson(routeJson));
        } else {
          _log(
              "Warning: Skipping malformed route data item in asset $fileName: $routeJson");
        }
      }
      _log(
          "Successfully loaded ${assetRoutes.length} routes from asset: $fileName");
      return assetRoutes;
    } catch (e, stackTrace) {
      _log(
          "Error loading or parsing routes from asset $fileName: $e\nStackTrace: $stackTrace");
      return []; // Return empty list on error to make fallbacks safer
    }
  }
}
