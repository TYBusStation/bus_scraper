// lib/pages/nearby_vehicles_page.dart

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../data/bus_route.dart';
import '../static.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';
import 'history_page.dart';

class NearbyVehiclesPage extends StatefulWidget {
  const NearbyVehiclesPage({super.key});

  @override
  State<NearbyVehiclesPage> createState() => _NearbyVehiclesPageState();
}

class _NearbyVehiclesPageState extends State<NearbyVehiclesPage> {
  final MapController _mapController = MapController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  LatLng _currentMapCenter = BaseMapView.getDefaultCenter();
  StreamSubscription<MapEvent>? _mapEventSubscription;
  bool _isProgrammaticMove = false;

  double _searchRadiusKm = 0.1;
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 1));
  DateTime _endTime = DateTime.now();

  bool _isLoading = false;
  List<BusPoint> _foundPoints = [];
  List<Marker> _resultMarkers = [];
  List<Polyline> _resultPolylines = [];
  bool _isSearched = false;
  late LatLng _searchCenterWhenSearched;

  List<String> _availablePlates = [];
  List<String> _selectedPlates = [];

  double _satelliteOpacity = 0.25;
  LatLng? _myLocation;
  bool _isLocating = false;

  BusPoint? _selectedPoint;
  BusRoute? _selectedRoute;
  bool _isFetchingRouteDetail = false;
  Marker? _highlightMarker;

  @override
  void initState() {
    super.initState();
    _updateCenterText();
    _mapEventSubscription = _mapController.mapEventStream.listen((mapEvent) {
      if (_isProgrammaticMove) return;
      if (mapEvent is MapEventMove && mounted && !_isSearched) {
        if (_currentMapCenter != mapEvent.camera.center) {
          setState(() {
            _currentMapCenter = mapEvent.camera.center;
            _updateCenterText();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    _mapController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _updateCenterText() {
    if (!mounted) return;
    _latController.text = _currentMapCenter.latitude.toString();
    _lonController.text = _currentMapCenter.longitude.toString();
  }

  void _parseAndSetCenter() {
    if (_isSearched) return;

    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);

    if (lat != null && lon != null && (lat.abs() <= 90) && (lon.abs() <= 180)) {
      final newCenter = LatLng(lat, lon);
      if (newCenter == _currentMapCenter) return;

      setState(() {
        _currentMapCenter = newCenter;
      });

      _isProgrammaticMove = true;
      _mapController.move(newCenter, _mapController.camera.zoom);
      Future.delayed(const Duration(milliseconds: 500))
          .whenComplete(() => _isProgrammaticMove = false);
    }
  }

  Future<void> _pasteLatLng() async {
    if (_isSearched) return;
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text != null && text.isNotEmpty) {
      final parts =
          text.split(RegExp(r'[,;\s]+')).map((e) => e.trim()).toList();
      if (parts.length == 2) {
        _latController.text = parts[0];
        _lonController.text = parts[1];
        _parseAndSetCenter();
      } else {
        _latController.text = text;
        _lonController.text = '';
      }
    }
  }

  Future<void> _performSearch() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus(); // 收起鍵盤
    setState(() {
      _isLoading = true;
      _searchCenterWhenSearched = _currentMapCenter;
    });

    try {
      final double effectiveRadius =
          _searchRadiusKm > 0 ? _searchRadiusKm : 0.01;
      final dio = Static.dio;
      final url =
          "${Static.apiBaseUrl}/${Static.localStorage.city}/tools/find_nearby_vehicles";
      final queryParameters = {
        'lat': _searchCenterWhenSearched.latitude.toString(),
        'lon': _searchCenterWhenSearched.longitude.toString(),
        'radius': effectiveRadius.toString(),
        'start_time': Static.apiDateFormat.format(_startTime),
        'end_time': Static.apiDateFormat.format(_endTime),
      };

      final response = await dio.get(url, queryParameters: queryParameters);
      List<BusPoint> results = [];
      if (response.statusCode == 200 && response.data is List) {
        results = (response.data as List)
            .map((item) => BusPoint.fromJson(item))
            .toList();
      } else {
        throw Exception('API 回傳格式錯誤');
      }

      if (mounted) {
        setState(() {
          _clearLayers(keepFilters: true);
          _foundPoints = results;
          _isSearched = true;

          final uniquePlates = results.map((p) => p.plate).toSet().toList();
          uniquePlates.sort();
          _availablePlates = uniquePlates;
          _selectedPlates.removeWhere((p) => !_availablePlates.contains(p));

          _applyFiltersAndUpdateLayers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('搜尋失敗: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndUpdateLayers() {
    final List<BusPoint> pointsToDisplay = _selectedPlates.isEmpty
        ? _foundPoints
        : _foundPoints.where((p) => _selectedPlates.contains(p.plate)).toList();
    final pointsByPlate =
        groupBy<BusPoint, String>(pointsToDisplay, (p) => p.plate);
    final newPolylines = <Polyline>[];
    final newMarkers = <Marker>[];
    int colorIndex = 0;
    pointsByPlate.forEach((plate, points) {
      if (points.isEmpty) return;
      final color = BaseMapView
          .segmentColors[colorIndex % BaseMapView.segmentColors.length];
      points.sort((a, b) => a.dataTime.compareTo(b.dataTime));
      final latlngs = points.map((p) => LatLng(p.lat, p.lon)).toList();
      if (latlngs.length > 1) {
        newPolylines
            .add(Polyline(points: latlngs, color: color, strokeWidth: 4.0));
      }
      for (final point in points) {
        newMarkers.add(_buildPointMarker(point, color));
      }
      colorIndex++;
    });
    setState(() {
      _resultPolylines = newPolylines;
      _resultMarkers = newMarkers;
    });
  }

  PointMarker _buildPointMarker(BusPoint point, Color color) {
    return PointMarker(
      busPoint: point,
      width: 14,
      height: 14,
      child: GestureDetector(
        onTap: () => _selectPoint(point),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }

  void _selectPoint(BusPoint point) {
    setState(() {
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
        _selectedRoute = null;
        _isFetchingRouteDetail = false;
      } else {
        _selectedPoint = point;
        _highlightMarker = Marker(
          point: LatLng(point.lat, point.lon),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const IgnorePointer(
            child: Icon(Icons.location_on,
                color: Colors.blue,
                size: 40,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
          ),
        );
        _selectedRoute = null;
        _isFetchingRouteDetail = false;
        final routeIndex =
            Static.routeData.indexWhere((r) => r.id == point.routeId);
        if (routeIndex != -1) {
          _selectedRoute = Static.routeData[routeIndex];
        } else {
          _isFetchingRouteDetail = true;
          _fetchAndSetRouteDetail(point.routeId);
        }
      }
    });
  }

  void _clearLayers({bool keepFilters = false}) {
    setState(() {
      _foundPoints.clear();
      _resultMarkers.clear();
      _resultPolylines.clear();
      _selectedPoint = null;
      _highlightMarker = null;
      _isSearched = false;
      if (!keepFilters) {
        _availablePlates.clear();
        _selectedPlates.clear();
      }
    });
  }

  Future<void> _fetchAndSetRouteDetail(String routeId) async {
    final route = await Static.fetchRouteDetailById(routeId);
    if (mounted &&
        _selectedPoint != null &&
        _selectedPoint!.routeId == routeId) {
      setState(() {
        _selectedRoute = route;
        _isFetchingRouteDetail = false;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initialDate = isStart ? _startTime : _endTime;
    final now = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 6, 8),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
    );
    if (newDate == null || !mounted) return;
    final newTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
    if (newTime == null) return;
    setState(() {
      final finalDateTime = DateTime(newDate.year, newDate.month, newDate.day,
          newTime.hour, newTime.minute);
      if (isStart) {
        _startTime = finalDateTime;
        if (_startTime.isAfter(_endTime)) {
          _endTime = _startTime.add(const Duration(minutes: 30));
        }
      } else {
        _endTime = finalDateTime;
        if (_endTime.isBefore(_startTime)) {
          _startTime = _endTime.subtract(const Duration(minutes: 30));
        }
      }
    });
  }

  Future<void> _recenterMap() async {
    LatLngBounds bounds;
    final center = _isSearched ? _searchCenterWhenSearched : _currentMapCenter;
    final radius = _searchRadiusKm;
    const earthRadiusKm = 6371;
    final latRad = center.latitudeInRad;
    final angularDistance = radius / earthRadiusKm;
    final latDelta = angularDistance * (180 / pi);
    final lonDelta = angularDistance * (180 / pi) / cos(latRad);
    final southWest =
        LatLng(center.latitude - latDelta, center.longitude - lonDelta);
    final northEast =
        LatLng(center.latitude + latDelta, center.longitude + lonDelta);
    final circleBoundaryPoints = [southWest, northEast];

    if (_foundPoints.isEmpty) {
      bounds = LatLngBounds.fromPoints(circleBoundaryPoints);
    } else {
      final allPointsForBounds = [
        ..._foundPoints.map((p) => LatLng(p.lat, p.lon)),
        ...circleBoundaryPoints,
      ];
      bounds = LatLngBounds.fromPoints(allPointsForBounds);
    }

    _isProgrammaticMove = true;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    _isProgrammaticMove = false;
  }

  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('請開啟裝置的定位服務');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('您已拒絕位置權限');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('位置權限已被永久拒絕，請至應用程式設定中開啟');
      }

      final position = await Geolocator.getCurrentPosition();
      final newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _myLocation = newLocation;
          _currentMapCenter = newLocation;
          _updateCenterText();
        });
        _isProgrammaticMove = true;
        _mapController.move(newLocation, 17.0);
        await Future.delayed(const Duration(milliseconds: 500));
        _isProgrammaticMove = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth > 800;

        // 【修改】將共用的 MapView 抽離出來
        final mapView = _buildMapView(isLandscape);

        if (isLandscape) {
          return Row(
            children: [
              Expanded(child: mapView), // 左側是地圖
              SizedBox(
                width: 220, // 右側控制面板的寬度
                child: _buildControlPanel(isLandscape), // 右側是控制面板
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildControlPanel(isLandscape), // 頂部是控制面板
              Expanded(child: mapView), // 下方是地圖
            ],
          );
        }
      },
    );
  }

  Widget _buildMapView(bool isLandscape) {
    final theme = Theme.of(context); // 獲取主題以上色
    final allMarkers = [..._resultMarkers];
    if (_highlightMarker != null) allMarkers.add(_highlightMarker!);
    if (_myLocation != null) allMarkers.add(_buildMyLocationMarker());

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentMapCenter,
            initialZoom: 15,
            onMapReady: () {
              if (mounted && !_isSearched) {
                setState(() {
                  _currentMapCenter = _mapController.camera.center;
                  _updateCenterText();
                });
              }
            },
            onTap: (_, __) {
              if (_selectedPoint != null) _selectPoint(_selectedPoint!);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileProvider: CancellableNetworkTileProvider(),
              userAgentPackageName: "me.myster.bus_scraper",
            ),
            Opacity(
              opacity: _satelliteOpacity,
              child: TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                tileProvider: CancellableNetworkTileProvider(),
                userAgentPackageName: "me.myster.bus_scraper",
              ),
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                    point: _isSearched
                        ? _searchCenterWhenSearched
                        : _currentMapCenter,
                    radius: _searchRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: Colors.red.withOpacity(0.2),
                    borderColor: Colors.red.withOpacity(0.6),
                    borderStrokeWidth: 3)
              ],
            ),
            PolylineLayer(polylines: _resultPolylines),
            MarkerLayer(markers: allMarkers),
          ],
        ),

        // 【核心修改】將版權資訊加回 Stack 的頂部
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: theme.colorScheme.surface,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'Map data © OpenStreetMap contributors, Imagery © Esri, Maxar, Earthstar Geo',
              style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),

        Positioned(
          bottom:
              (_selectedPoint != null ? (isLandscape ? 140.0 : 190.0) : 0) + 16,
          right: 16,
          child: _buildFloatingMapControls(Theme.of(context)),
        ),

        _buildInfoPanel(isLandscape: isLandscape),
      ],
    );
  }

  Widget _buildControlPanel(bool isLandscape) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(4.0),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimeButtonSection(theme, isLandscape: isLandscape),
              const SizedBox(height: 4),
              _buildRadiusSlider(theme, isLandscape: isLandscape),
              const SizedBox(height: 4),
              _buildLatLngAndSearchSection(theme, isLandscape: isLandscape),
              if (_availablePlates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _buildPlateFilterChip(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButtonSection(ThemeData theme, {required bool isLandscape}) {
    final startButton = _buildTimeButton(theme, "開始時間：", _startTime, true,
        isLandscape: isLandscape);
    final endButton = _buildTimeButton(theme, "結束時間：", _endTime, false,
        isLandscape: isLandscape);

    if (isLandscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [startButton, const SizedBox(height: 8), endButton],
      );
    }
    return Row(
      children: [startButton, const SizedBox(width: 8), endButton],
    );
  }

  Widget _buildLatLngAndSearchSection(ThemeData theme,
      {required bool isLandscape}) {
    final latLngInput = _buildLatLngInput(theme, isLandscape: isLandscape);
    final searchButton = _buildSearchAndClearButton(theme);
    final pasteButton = _isSearched
        ? const SizedBox.shrink()
        : IconButton(
            icon: const Icon(Icons.content_paste_go_outlined),
            iconSize: 20,
            tooltip: '貼上經緯度',
            onPressed: _pasteLatLng,
          );

    if (isLandscape) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.pin_drop_outlined, size: 20, color: Colors.grey),
              // 在橫向模式下，貼上按鈕空間更小，所以用 Transform 縮小一點
              Transform.scale(scale: 0.8, child: pasteButton),
            ],
          ),
          const SizedBox(height: 4),
          latLngInput,
          const SizedBox(height: 8),
          searchButton,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: latLngInput),
        pasteButton,
        const SizedBox(width: 4),
        searchButton
      ],
    );
  }

  Widget _buildLatLngInput(ThemeData theme, {required bool isLandscape}) {
    final latField = TextField(
      controller: _latController,
      enabled: !_isSearched,
      style: theme.textTheme.bodyMedium
          ?.copyWith(fontFeatures: [const FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: '緯度',
        labelStyle: theme.textTheme.labelSmall,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        disabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      onEditingComplete: _parseAndSetCenter,
    );

    final lonField = TextField(
      controller: _lonController,
      enabled: !_isSearched,
      style: theme.textTheme.bodyMedium
          ?.copyWith(fontFeatures: [const FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: '經度',
        labelStyle: theme.textTheme.labelSmall,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        isDense: true,
        disabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      onEditingComplete: _parseAndSetCenter,
    );

    if (isLandscape) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          latField,
          const SizedBox(height: 8),
          lonField,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: latField),
          const SizedBox(width: 8),
          Expanded(child: lonField),
        ],
      );
    }
  }

  // 【核心修改】修正拉桿文字旋轉問題
  Widget _buildRadiusSlider(ThemeData theme, {required bool isLandscape}) {
    final slider = Slider(
      value: _searchRadiusKm,
      min: 0.0,
      max: 0.3,
      divisions: 30,
      label: '${(_searchRadiusKm * 1000).toInt()}公尺',
      onChanged: _isSearched
          ? null
          : (double value) {
              setState(() => _searchRadiusKm = value);
            },
    );

    final label = Text(
      '${(_searchRadiusKm * 1000).toInt()}m',
      style: theme.textTheme.labelMedium?.copyWith(
          color: _isSearched ? Colors.grey : theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontFeatures: [const FontFeature.tabularFigures()]),
      textAlign: TextAlign.center,
    );

    if (isLandscape) {
      return SizedBox(
        height: 200,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.social_distance_outlined,
                    size: 18,
                    color: _isSearched ? Colors.grey : Colors.grey.shade600),
                const SizedBox(width: 8),
                label, // 文字標籤現在在 Row 裡，不會被旋轉
              ],
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3, // 只旋轉 Slider
                child: slider,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Icon(Icons.social_distance_outlined,
            size: 18, color: _isSearched ? Colors.grey : Colors.grey.shade600),
        Expanded(child: slider),
        SizedBox(width: 50, child: label),
      ],
    );
  }

  Widget _buildTimeButton(
      ThemeData theme, String label, DateTime time, bool isStart,
      {required bool isLandscape}) {
    final formatter = Static.displayDateFormatNoSec;

    final buttonContent = Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: _isSearched ? null : () => _pickTime(isStart),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text("$label\n${formatter.format(time)}",
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
                color:
                    _isSearched ? Colors.grey : theme.colorScheme.onSurface)),
      ),
    );

    // 【修復】只有在非橫向模式下才使用 Expanded
    if (!isLandscape) {
      return Expanded(child: buttonContent);
    }
    return buttonContent;
  }

  Widget _buildSearchAndClearButton(ThemeData theme) {
    final button = _isSearched
        ? FilledButton.icon(
            onPressed: () => _clearLayers(keepFilters: false),
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('清除'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          )
        : FilledButton.icon(
            onPressed: _performSearch,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 18),
            label: const Text('搜尋'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          );

    // 【修復】移除 SizedBox(width: double.infinity)，因為 Column 的
    // crossAxisAlignment: CrossAxisAlignment.stretch 已經處理了寬度
    return button;
  }

  Widget _buildFloatingMapControls(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: 40,
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.satellite_alt_outlined,
                    size: 18, color: theme.colorScheme.onSurface),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12.0),
                      ),
                      child: Slider(
                        value: _satelliteOpacity,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (v) => setState(() => _satelliteOpacity = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        FloatingActionButton.small(
          onPressed: _recenterMap,
          tooltip: '重新置中',
          elevation: 4,
          heroTag: 'recenter_btn_nearby',
          child: const Icon(Icons.center_focus_strong),
        ),
        const SizedBox(height: 4),
        FloatingActionButton.small(
          onPressed: _isLocating ? null : _locateMe,
          tooltip: '定位我的位置',
          elevation: 4,
          backgroundColor: _isLocating
              ? Colors.grey
              : theme.floatingActionButtonTheme.backgroundColor,
          heroTag: 'locate_me_btn_nearby',
          child: _isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.my_location),
        ),
      ],
    );
  }

  Marker _buildMyLocationMarker() {
    return Marker(
      point: _myLocation!,
      width: 20,
      height: 20,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }

  Widget _buildPlateFilterChip() {
    String displayText = _selectedPlates.isEmpty
        ? '所有車牌 (${_availablePlates.length})'
        : '已選 ${_selectedPlates.length} 個車牌';

    return InkWell(
      onTap: () async {
        await _showMultiSelectDialog(
          title: '篩選車牌',
          items: {for (var p in _availablePlates) p: p},
          initialSelectedValues: _selectedPlates,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiSelectDialog({
    required String title,
    required Map<String, String> items,
    required List<String> initialSelectedValues,
  }) async {
    final tempSelectedValues = Set<String>.from(initialSelectedValues);

    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              contentPadding: const EdgeInsets.only(top: 12.0),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final key = items.keys.elementAt(index);
                    final value = items.values.elementAt(index);

                    return InkWell(
                      onTap: () {
                        setStateDialog(() {
                          if (tempSelectedValues.contains(key)) {
                            tempSelectedValues.remove(key);
                          } else {
                            tempSelectedValues.add(key);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: tempSelectedValues.contains(key),
                              onChanged: (bool? isChecked) {
                                setStateDialog(() {
                                  if (isChecked == true) {
                                    tempSelectedValues.add(key);
                                  } else {
                                    tempSelectedValues.remove(key);
                                  }
                                });
                              },
                            ),
                            Expanded(child: Text(value)),
                            FilledButton.icon(
                              label: const Text("歷史紀錄"),
                              onPressed: () {
                                Navigator.pop(context); // 關閉對話框
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryPage(
                                      plate: key,
                                      initialStartTime: _startTime,
                                      initialEndTime: _endTime,
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12)),
                              icon: const Icon(Icons.history, size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () => Navigator.pop(context, null),
                ),
                FilledButton(
                  child: const Text('確定'),
                  onPressed: () =>
                      Navigator.pop(context, tempSelectedValues.toList()),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedPlates = result;
        _applyFiltersAndUpdateLayers();
      });
    }
  }

  Widget _buildInfoPanel({required bool isLandscape}) {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;

    // 【核心修改 1】根據佈局模式動態設定面板高度
    final double panelHeight = isLandscape ? 140.0 : 190.0;

    final route = _selectedRoute;
    final String plate = _selectedPoint?.plate ?? '未知';

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: isVisible ? 0 : -(panelHeight + 40),

      // 【核心修改 2】無論是橫向還是縱向，都讓面板的左右兩邊貼齊螢幕邊緣
      left: 0,
      right: 0,
      // <--- 將 right 設為 0

      child: SafeArea(
        top: false,
        child: Container(
          height: panelHeight,
          margin: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(38),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ]),
          child: !isVisible
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  Static.displayDateFormat
                                      .format(_selectedPoint!.dataTime),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold))),
                          IconButton(
                              icon: const Icon(Icons.map_sharp),
                              color: Colors.blueAccent,
                              tooltip: '在 Google Map 上查看',
                              onPressed: route == null
                                  ? null
                                  : () async {
                                      final mapTitle = "$plate | "
                                          "${route.name} | ${route.description} "
                                          "| 往 ${route.destination.isNotEmpty && route.departure.isNotEmpty ? (_selectedPoint!.goBack == 1 ? route.destination : route.departure) : '未知'} "
                                          "| ${_selectedPoint!.dutyStatus == 0 ? "營運" : "非營運"} "
                                          "| 駕駛：${Static.getDriverText(_selectedPoint!.driverId)} "
                                          "| ${Static.displayDateFormat.format(_selectedPoint!.dataTime)}";
                                      await launchUrl(Uri.parse(
                                          "https://www.google.com/maps?q=${_selectedPoint!.lat}"
                                          ",${_selectedPoint!.lon}($mapTitle)"));
                                    }),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _selectPoint(_selectedPoint!),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, thickness: 1, indent: 16, endIndent: 16),
                    if (_isFetchingRouteDetail)
                      const Expanded(
                          child: Center(child: CircularProgressIndicator()))
                    else if (route != null)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 6.0,
                            children: [
                              _buildInfoChip(
                                  icon: Icons.numbers,
                                  label: "車牌：$plate",
                                  color: theme.colorScheme.primary),
                              _buildInfoChip(
                                  icon: Icons.route_outlined,
                                  label: "${route.name} (${route.id})"),
                              _buildInfoChip(
                                  icon: Icons.description_outlined,
                                  label: route.description),
                              _buildInfoChip(
                                  icon: Icons.swap_horiz,
                                  label:
                                      "往 ${route.destination.isNotEmpty && route.departure.isNotEmpty ? (_selectedPoint!.goBack == 1 ? route.destination : route.departure) : '未知'}"),
                              _buildInfoChip(
                                icon: _selectedPoint!.dutyStatus == 0
                                    ? Icons.work_outline
                                    : Icons.work_off_outlined,
                                label: _selectedPoint!.dutyStatus == 0
                                    ? "營運"
                                    : "非營運",
                                color: _selectedPoint!.dutyStatus == 0
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              _buildInfoChip(
                                  icon: Icons.person_pin_circle_outlined,
                                  label:
                                      "駕駛：${Static.getDriverText(_selectedPoint!.driverId)}"),
                              InkWell(
                                borderRadius: BorderRadius.circular(16.0),
                                onTap: () {
                                  final lat = _selectedPoint!.lat;
                                  final lon = _selectedPoint!.lon;
                                  final latLonString = '$lat, $lon';
                                  Clipboard.setData(
                                      ClipboardData(text: latLonString));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('已複製經緯度：$latLonString'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        showCloseIcon: true,
                                      ),
                                    );
                                  }
                                },
                                child: _buildInfoChip(
                                    icon: Icons.gps_fixed,
                                    label:
                                        "${_selectedPoint!.lat}, ${_selectedPoint!.lon}"),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '無法載入路線 ${_selectedPoint!.routeId} 的詳細資訊。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      {required IconData icon, required String label, Color? color}) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon,
          size: 16, color: color ?? theme.colorScheme.onSurfaceVariant),
      label: Text(label, style: theme.textTheme.labelMedium),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
