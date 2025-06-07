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
  static final DateFormat dateFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayDateFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  // TODO: Verify the purpose of this RegExp.
  // If it's to check if a string consists ONLY of alphanumeric characters:
  static RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  // If it's to check if a string CONTAINS an alphanumeric character:
  // static RegExp letterNumber = RegExp(r"[a-zA-Z0-9]");
  // The original RegExp(r"^a-zA-Z0-9") was incorrect as it matched a literal string.

  // API Endpoints - Consider moving to a config file or environment variables for flexibility
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
  // Initialize Dio with base options and headers
  static final Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5), // Increased timeout slightly
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
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
    log("Static initialization started.");

    // Initialize storage helper (if it has its own async setup)
    await StorageHelper.init();

    // Load special routes from local assets first, as it's reliable and fast.
    specialRouteData =
        await _loadRoutesFromJsonAsset("special_route_data.json");

    // Fetch operational routes and car data concurrently.

    await _testApi();

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
      log("Error during parallel data fetching: $e. Attempting individual fallbacks.");
      opRouteData = await _loadRoutesFromJsonAsset(
          "op_route_data.json"); // Fallback for opRouteData
      carData = []; // Fallback for carData
    }

    // Combine operational and special routes.
    // Using a spread operator for a new list to ensure immutability of originals if needed.
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

  // --- Private Helper Methods ---

  /// Logs a message with a timestamp and class context.
  static void log(String message) {
    print("[${DateTime.now().toIso8601String()}] [Static] $message");
  }

  /// Fetches operational bus routes from the GraphQL API.
  /// Falls back to a local asset if the API request fails.
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

                // // Standardize provider information to a list of names
                // List<String> providerNames = [];
                // final providersData = routeInfo['providers'];
                // if (providersData is Map<String, dynamic> &&
                //     providersData['edges'] is List) {
                //   for (var pEdge in providersData['edges']) {
                //     if (pEdge is Map<String, dynamic> &&
                //         pEdge['node'] is Map<String, dynamic> &&
                //         pEdge['node']['name'] is String) {
                //       providerNames.add(pEdge['node']['name']);
                //     }
                //   }
                // }
                // routeInfo['providers'] =
                //     providerNames; // Replace original providers structure

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

  /// Fetches car data from the API.
  /// Falls back to an empty list if the API request fails.
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
            return []; // Return empty list if API response is an empty list
          }
        } else {
          log("API returned success, but car data structure is unexpected (expected a List): ${response.data}");
        }
      } else {
        log("Failed to fetch car data. Status: ${response.statusCode}, Message: ${response.statusMessage}, Data: ${response.data}");
      }
    } on DioException catch (e) {
      log("DioError fetching car data: ${e.message}" +
          (e.response != null ? " - Response: ${e.response?.data}" : ""));
    } catch (e, stackTrace) {
      log("Unexpected error fetching or parsing car data: $e\nStackTrace: $stackTrace");
    }

    log("Failed to fetch car data from API. Returning empty list as fallback.");
    return []; // Fallback to an empty list
  }

  /// Loads and parses bus routes from a JSON file in the assets folder.
  /// Returns an empty list on error to ensure fallbacks are safe.
  static Future<List<BusRoute>> _loadRoutesFromJsonAsset(
      String fileName) async {
    log("Loading routes from asset: assets/$fileName");
    try {
      final String jsonString = await rootBundle.loadString("assets/$fileName");
      // Assuming the root of the JSON asset is a list of route objects
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
      return []; // Return empty list on error to make fallbacks safer
    }
  }

  // Helper function to parse route strings into structured data
  static Map<String, dynamic> _parseRoute(String route) {
    String type = 'UNKNOWN';
    int? baseNum;
    String? baseStr;
    String suffixAlpha = '';
    String suffixNumeric = ''; // For things like GR2
    String suffixParenthesis = '';
    bool isSpecialTGood = false;

    RegExpMatch? match;

    // 1. T routes (highest precedence for parsing specific T patterns)
    if (route.startsWith('T')) {
      type = 'T';
      // Special T...(真好) case
      match = RegExp(r'^T(\d+)\(真好\)$').firstMatch(route);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        isSpecialTGood = true;
        suffixParenthesis =
            '(真好)'; // Store for completeness, though bool is key
      } else {
        // General T routes: T<num>[letters][(text)]
        match = RegExp(r'^T(\d+)([A-Z]*)(\(.*\))?$').firstMatch(route);
        if (match != null) {
          baseNum = int.tryParse(match.group(1)!);
          suffixAlpha = match.group(2) ?? '';
          suffixParenthesis = match.group(3) ?? '';
        } else {
          // Fallback if T route doesn't match T<num> pattern (e.g. "T" or "TALPHA")
          // Treat as an ALPHA type for sorting purposes if it's not a standard T<num> format
          type = 'ALPHA'; // Reclassify
          baseStr = route; // The whole string is the base
        }
      }
    }
    // 2. Numeric-first routes: <num>[letters][(text)]
    else if (RegExp(r'^\d').hasMatch(route)) {
      type = 'NUMERIC';
      match = RegExp(r'^(\d+)([A-ZN-S]*)(\(.*\))?$')
          .firstMatch(route); // Allow N,S in suffixAlpha
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        suffixAlpha = match.group(2) ?? '';
        suffixParenthesis = match.group(3) ?? '';
      } else {
        // Fallback for pure numbers if regex fails (should ideally be caught by above)
        baseNum = int.tryParse(route);
        if (baseNum == null) {
          // If it starts with a digit but isn't parsable as typical route
          type = 'ALPHA'; // Reclassify as a generic string
          baseStr = route;
        }
      }
    }
    // 3. Alpha-first routes: <letters>[digits][letters][(text)] (e.g. BR, GR, GR2, GR2A)
    else {
      type = 'ALPHA';
      match = RegExp(r'^([A-Z]+)(\d*)([A-Z]*)(\(.*\))?$').firstMatch(route);
      if (match != null) {
        baseStr = match.group(1)!;
        suffixNumeric = match.group(2) ?? '';
        suffixAlpha = match.group(3) ?? '';
        suffixParenthesis = match.group(4) ?? '';
      } else {
        // Purely alphabetical or unrecognised pattern
        baseStr = route;
      }
    }

    return {
      'original': route,
      'type': type,
      'baseNum': baseNum, // Numeric part for NUMERIC and T types
      'baseStr': baseStr, // Alphabetic part for ALPHA type (BR, GR)
      'suffixAlpha': suffixAlpha, // A, B, N, S
      'suffixNumeric': suffixNumeric, // For GR2
      'suffixParenthesis': suffixParenthesis, // (大溪站發車), (真好)
      'isSpecialTGood': isSpecialTGood, // For T...(真好)
    };
  }

  static int compareRoutes(String a, String b) {
    if (a == b) return 0;

    var pa = _parseRoute(a);
    var pb = _parseRoute(b);

    // Order of types: NUMERIC < ALPHA < T
    int typeOrder(String type) {
      if (type == 'NUMERIC') return 1;
      if (type == 'ALPHA') return 2;
      if (type == 'T') return 3;
      return 4; // UNKNOWN or fallback
    }

    int typeComparison = typeOrder(pa['type']).compareTo(typeOrder(pb['type']));
    if (typeComparison != 0) return typeComparison;

    // --- Within the same type ---

    if (pa['type'] == 'NUMERIC') {
      int baseNumComparison =
          (pa['baseNum'] ?? 0).compareTo(pb['baseNum'] ?? 0);
      if (baseNumComparison != 0) return baseNumComparison;

      // Suffix Alpha: "" < "A" < "B" ... < "N" < "S"
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;

      // Suffix Parenthesis: "" (no paren) < "(...)" (paren)
      // Then lexicographical for parenthesized content if both have it.
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pb['suffixParenthesis'] as String;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen); // If both empty or both non-empty
    } else if (pa['type'] == 'ALPHA') {
      // BR, GR, etc.
      int baseStrComparison =
          (pa['baseStr'] ?? '').compareTo(pb['baseStr'] ?? '');
      if (baseStrComparison != 0) return baseStrComparison;

      // Suffix Numeric (for GR vs GR2)
      // Treat empty suffixNumeric as 0 for comparison if baseStr is same
      int paSuffixNumVal = (pa['suffixNumeric'] as String).isEmpty
          ? 0
          : int.parse(pa['suffixNumeric'] as String);
      int pbSuffixNumVal = (pb['suffixNumeric'] as String).isEmpty
          ? 0
          : int.parse(pb['suffixNumeric'] as String);
      int suffixNumComparison = paSuffixNumVal.compareTo(pbSuffixNumVal);
      if (suffixNumComparison != 0) return suffixNumComparison;

      // Suffix Alpha (e.g., for a hypothetical GR2A vs GR2B)
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;

      // Suffix Parenthesis
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pb['suffixParenthesis'] as String;
      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    } else if (pa['type'] == 'T') {
      int baseNumComparison =
          (pa['baseNum'] ?? 0).compareTo(pb['baseNum'] ?? 0);
      if (baseNumComparison != 0) return baseNumComparison;

      // Special T(真好) rule: (真好) comes before others for the same base number
      bool paIsSpecial = pa['isSpecialTGood'] as bool;
      bool pbIsSpecial = pb['isSpecialTGood'] as bool;
      if (paIsSpecial != pbIsSpecial) {
        return paIsSpecial ? -1 : 1; // Special comes first
      }

      // Suffix Alpha: "" < "A" < "B"
      int suffixAlphaComparison =
          (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
      if (suffixAlphaComparison != 0) return suffixAlphaComparison;

      // Suffix Parenthesis (for non-真好 cases, as 真好 already handled)
      // "" (no paren) < "(...)"
      String paParen = pa['suffixParenthesis'] as String;
      String pbParen = pb['suffixParenthesis'] as String;
      // If one of them was special good, it would have been handled above or they are both special good.
      // If both special good and same base number and same suffix alpha, they are effectively equivalent here.
      if (paIsSpecial && pbIsSpecial) return 0;

      if (paParen.isEmpty && pbParen.isNotEmpty) return -1;
      if (paParen.isNotEmpty && pbParen.isEmpty) return 1;
      return paParen.compareTo(pbParen);
    }

    // Fallback: should ideally be covered by original string comparison if all parsed parts are equal
    return a.compareTo(b);
  }
}
