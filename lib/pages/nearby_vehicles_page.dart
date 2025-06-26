// lib/pages/nearby_vehicles_page.dart

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../data/bus_route.dart';
import '../static.dart';
import '../widgets/base_map_view.dart';
import 'history_page.dart';

class NearbyVehiclesPage extends StatefulWidget {
  const NearbyVehiclesPage({super.key});

  @override
  State<NearbyVehiclesPage> createState() => _NearbyVehiclesPageState();
}

class _NearbyVehiclesPageState extends State<NearbyVehiclesPage> {
  final MapController _mapController = MapController();
  LatLng _currentMapCenter = const LatLng(24.986763, 121.314007);
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
    _mapEventSubscription = _mapController.mapEventStream.listen((mapEvent) {
      if (_isProgrammaticMove) return;
      if (mapEvent is MapEventMove && mounted && !_isSearched) {
        if (_currentMapCenter != mapEvent.camera.center) {
          setState(() => _currentMapCenter = mapEvent.camera.center);
        }
      }
    });
  }

  @override
  void dispose() {
    _mapEventSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _searchCenterWhenSearched = _currentMapCenter;
    });

    final double effectiveRadius = _searchRadiusKm > 0 ? _searchRadiusKm : 0.01;
    final dio = Static.dio;
    final url = "${Static.apiBaseUrl}/tools/find_nearby_vehicles";
    final queryParameters = {
      'lat': _searchCenterWhenSearched.latitude.toString(),
      'lon': _searchCenterWhenSearched.longitude.toString(),
      'radius': effectiveRadius.toString(),
      'start_time': Static.apiDateFormat.format(_startTime),
      'end_time': Static.apiDateFormat.format(_endTime),
    };

    try {
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
      // Handle error silently
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
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
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
        if (permission == LocationPermission.denied)
          throw Exception('您已拒絕位置權限');
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception('位置權限已被永久拒絕，請至應用程式設定中開啟');

      final position = await Geolocator.getCurrentPosition();
      final newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() => _myLocation = newLocation);
        _isProgrammaticMove = true;
        _mapController.move(newLocation, 17.0);
        await Future.delayed(const Duration(milliseconds: 500));
        _isProgrammaticMove = false;
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMarkers = [..._resultMarkers];
    if (_highlightMarker != null) allMarkers.add(_highlightMarker!);
    if (_myLocation != null) allMarkers.add(_buildMyLocationMarker());

    return Column(
      children: [
        Text(
          'Map data © OpenStreetMap contributors, Imagery © Esri, Maxar, Earthstar Geo',
          style: TextStyle(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        _buildTopControlPanel(theme),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentMapCenter,
                  initialZoom: 15,
                  onMapReady: () {
                    if (mounted && !_isSearched) {
                      setState(() =>
                          _currentMapCenter = _mapController.camera.center);
                    }
                  },
                  onTap: (_, __) {
                    if (_selectedPoint != null) _selectPoint(_selectedPoint!);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  Opacity(
                    opacity: _satelliteOpacity,
                    child: TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      tileProvider: CancellableNetworkTileProvider(),
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
              Positioned(
                bottom: (_selectedPoint != null ? 190.0 : 0) + 16,
                right: 16,
                child: _buildFloatingMapControls(theme),
              ),
              _buildInfoPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopControlPanel(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeButton(theme, "開始時間：", _startTime, true),
                const SizedBox(width: 8),
                _buildTimeButton(theme, "結束時間：", _endTime, false),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [Expanded(child: _buildRadiusSlider(theme))]),
            const SizedBox(height: 4),
            Row(children: [Expanded(child: _buildSearchAndClearButton(theme))]),
            if (_availablePlates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildPlateFilterChip(),
              )
          ],
        ),
      ),
    );
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
        const SizedBox(height: 8),
        FloatingActionButton.small(
          onPressed: _recenterMap,
          tooltip: '重新置中',
          elevation: 4,
          heroTag: 'recenter_btn_nearby',
          child: const Icon(Icons.center_focus_strong),
        ),
        const SizedBox(height: 8),
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
      width: 24,
      height: 24,
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

  // **修正點: 全新的對話框實現**
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

                    // **UI 修正: 每一行都是一個可點擊的 InkWell**
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
              // **佈局修正: 移除 Spacer**
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

  Widget _buildTimeButton(
      ThemeData theme, String label, DateTime time, bool isStart) {
    final formatter = Static.displayDateFormatNoSec;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          onPressed: _isSearched ? null : () => _pickTime(isStart),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text("$label\n${formatter.format(time)}",
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      _isSearched ? Colors.grey : theme.colorScheme.onSurface)),
        ),
      ),
    );
  }

  Widget _buildRadiusSlider(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.social_distance_outlined,
            size: 18, color: _isSearched ? Colors.grey : Colors.grey.shade600),
        Expanded(
          child: Slider(
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
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${(_searchRadiusKm * 1000).toInt()}m',
            style: theme.textTheme.labelMedium?.copyWith(
                color: _isSearched ? Colors.grey : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()]),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndClearButton(ThemeData theme) {
    if (_isSearched) {
      return FilledButton.icon(
        onPressed: () => _clearLayers(keepFilters: false),
        icon: const Icon(Icons.clear, size: 18),
        label: const Text('清除'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
      );
    } else {
      return FilledButton.icon(
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
    }
  }

  Widget _buildInfoPanel() {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    const double panelHeight = 190.0;
    final route = _selectedRoute;
    final String plate = _selectedPoint?.plate ?? '未知';
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: isVisible ? 0 : -(panelHeight + 40),
      left: 0,
      right: 0,
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
                                          "| 駕駛：${_selectedPoint!.driverId == "0" ? "未知" : _selectedPoint!.driverId} "
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
                                      "駕駛：${_selectedPoint!.driverId == "0" ? "未知" : _selectedPoint!.driverId}"),
                              _buildInfoChip(
                                  icon: Icons.gps_fixed,
                                  label:
                                      "${_selectedPoint!.lat.toStringAsFixed(5)}, ${_selectedPoint!.lon.toStringAsFixed(5)}"),
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
