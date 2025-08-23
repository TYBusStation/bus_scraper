// lib/widgets/base_map_view.dart

import 'package:bus_scraper/widgets/point_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../data/bus_route.dart';
import '../data/route_detail.dart';
import '../pages/map_route_selection_page.dart';
import '../static.dart';

class BaseMapView extends StatefulWidget {
  static LatLng getDefaultCenter() {
    if (Static.localStorage.city == "taichung") {
      return const LatLng(24.137331792238204, 120.6869186637282);
    }

    return const LatLng(24.98893444390252, 121.31443803557084);
  }

  static const List<Color> segmentColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF00897B),
    Color(0xFF5E35B1),
    Color(0xFFFFB300),
    Color(0xFF039BE5),
    Color(0xFF6D4C41),
    Color(0xFFF4511E),
    Color(0xFFC0CA33),
    Color(0xFF00ACC1),
    Color(0xFF7CB342),
    Color(0xFF673AB7),
    Color(0xFF455A64),
  ];
  static List<Color> segmentColorsReverse = segmentColors.reversed.toList();
  static const double defaultZoom = 17;

  final String appBarTitle;
  final List<Widget>? appBarActions;
  final bool isLoading;
  final String? error;
  final List<BusPoint> points;
  final List<Polyline> polylines;
  final List<Marker> markers;
  final LatLngBounds? bounds;
  final bool hideAppBar;
  final VoidCallback? onErrorDismiss;
  final Function(BusPoint, String?)? onPointSelected;

  const BaseMapView({
    super.key,
    required this.appBarTitle,
    this.appBarActions,
    required this.isLoading,
    this.error,
    required this.points,
    required this.polylines,
    required this.markers,
    this.bounds,
    this.hideAppBar = false,
    this.onErrorDismiss,
    this.onPointSelected,
  });

  @override
  State<BaseMapView> createState() => BaseMapViewState();
}

class BaseMapViewState extends State<BaseMapView> {
  final MapController _mapController = MapController();
  double _satelliteOpacity = 0.25;
  BusPoint? _selectedPoint;
  Marker? _highlightMarker;
  String? _selectedPlate;
  LatLng? _currentLocation;
  bool _isLocating = false;
  BusRoute? _selectedRoute;
  bool _isFetchingRouteDetail = false;
  Map<String, RouteDirectionSelection> _userRouteSelections = {};
  List<Polyline> _userSelectedPolylines = [];
  List<Marker> _userSelectedMarkers = [];
  bool _isProcessingUserRoutes = false;
  (StationEdge, BusRoute, int)? _selectedStation;
  BusRoute? _panelRoute;
  bool _isFetchingPanelRoute = false;

  @override
  void didUpdateWidget(covariant BaseMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounds != null && oldWidget.bounds == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _recenterMap();
        }
      });
    }
  }

  Future<void> _fetchAndSetRouteDetail(String routeId) async {
    final route = await Static.getRouteById(routeId);
    if (mounted) {
      if (_selectedPoint != null && _selectedPoint!.routeId == routeId) {
        setState(() {
          _selectedRoute = route;
          _isFetchingRouteDetail = false;
        });
      }
    }
  }

  void selectPoint(BusPoint point, {String? plate}) {
    setState(() {
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
        _selectedPlate = null;
        _selectedRoute = null;
        _isFetchingRouteDetail = false;
      } else {
        _selectedPoint = point;
        _selectedPlate = plate;
        _highlightMarker = Marker(
          point: LatLng(point.lat, point.lon),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: Icon(
              Icons.location_on,
              color: Colors.blue.shade600,
              size: 40,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        );
        _selectedRoute = null;
        _isFetchingRouteDetail = false;
        _selectedStation = null;
        _isFetchingRouteDetail = true;
        _fetchAndSetRouteDetail(point.routeId);
      }
    });
  }

  void _recenterMap() {
    if (widget.points.isEmpty && _userSelectedPolylines.isEmpty) {
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, BaseMapView.defaultZoom);
      }
      return;
    }
    LatLngBounds? boundsToFit = widget.bounds;
    if (_userSelectedPolylines.isNotEmpty) {
      final allPoints = _userSelectedPolylines.expand((p) => p.points).toList();
      if (allPoints.isNotEmpty) {
        boundsToFit = LatLngBounds.fromPoints(allPoints);
      }
    }
    if (boundsToFit != null) {
      if (boundsToFit.southWest == boundsToFit.northEast) {
        _mapController.move(boundsToFit.center, BaseMapView.defaultZoom);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
              bounds: boundsToFit,
              padding: const EdgeInsets.all(50),
              maxZoom: BaseMapView.defaultZoom),
        );
      }
    } else if (widget.points.isNotEmpty) {
      final lastPoint = widget.points.last;
      _mapController.move(
          LatLng(lastPoint.lat, lastPoint.lon), BaseMapView.defaultZoom);
    }
  }

  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    ThemeData theme = Theme.of(context);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('請開啟裝置的定位服務'),
          showCloseIcon: true,
          backgroundColor: theme.colorScheme.primary,
        ));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('您已拒絕位置權限'),
            showCloseIcon: true,
            backgroundColor: theme.colorScheme.primary,
          ));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('位置權限已被永久拒絕，請至應用程式設定中開啟'),
          showCloseIcon: true,
          backgroundColor: theme.colorScheme.primary,
        ));
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = newLocation);
      _mapController.move(newLocation, 17.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('無法獲取位置: $e'),
          showCloseIcon: true,
          backgroundColor: theme.colorScheme.primary,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _openRouteSelection() async {
    final result = await Navigator.push<Map<String, RouteDirectionSelection>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapRouteSelectionPage(
          initialSelections: _userRouteSelections,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _isProcessingUserRoutes = true;
        _userRouteSelections = result;
      });
      await _updateUserSelectedLayers();
      if (mounted) {
        setState(() {
          _isProcessingUserRoutes = false;
        });
        if (_userSelectedPolylines.isNotEmpty) {
          _recenterMap();
        }
      }
    }
  }

  Future<void> _updateUserSelectedLayers() async {
    final newPolylines = <Polyline>[];
    final newMarkers = <Marker>[];
    int colorIndex = 0;
    for (final entry in _userRouteSelections.entries) {
      final routeId = entry.key;
      final selection = entry.value;
      if (!selection.isSelected) continue;
      final route = await Static.getRouteById(routeId);
      if (route == BusRoute.unknown) {
        Static.log("Skipping route $routeId.");
        continue;
      }
      final detail = await Static.fetchRoutePathAndStops(routeId);

      // --- [MODIFICATION START] ---
      // Logic changed to assign colors only for visible paths to ensure
      // better color distribution and prevent premature color repetition.
      if (selection.go && detail.goPath.isNotEmpty) {
        final color = BaseMapView.segmentColorsReverse[
            colorIndex % BaseMapView.segmentColorsReverse.length];
        colorIndex++; // Consume a color only when a polyline is added
        newPolylines.add(Polyline(
            points: detail.goPath,
            color: color.withOpacity(0.7),
            strokeWidth: 5.0));
        for (final station in detail.goStations) {
          newMarkers.add(
              _createStationMarker(station, route, color.withOpacity(0.7), 1));
        }
      }
      if (selection.back && detail.backPath.isNotEmpty) {
        final color = BaseMapView.segmentColorsReverse[
            colorIndex % BaseMapView.segmentColorsReverse.length];
        colorIndex++; // Consume a color only when a polyline is added
        newPolylines.add(Polyline(
            points: detail.backPath,
            color: color.withOpacity(0.7),
            strokeWidth: 5.0));
        for (final station in detail.backStations) {
          newMarkers.add(
              _createStationMarker(station, route, color.withOpacity(0.7), 2));
        }
      }
      // --- [MODIFICATION END] ---
    }
    if (mounted) {
      setState(() {
        _userSelectedPolylines = newPolylines;
        _userSelectedMarkers = newMarkers;
      });
    }
  }

  Future<void> _prepareStationInfoPanel(BusRoute route, String routeId) async {
    setState(() {
      _panelRoute = route;
      _isFetchingPanelRoute = false;
    });
  }

  void _selectStation(StationEdge station, BusRoute route, int goBack) {
    setState(() {
      final selectionKey =
          '${station.position.latitude}-${station.position.longitude}-${route.id}-$goBack';
      final currentKey = _selectedStation != null
          ? '${_selectedStation!.$1.position.latitude}-${_selectedStation!.$1.position.longitude}-${_selectedStation!.$2.id}-${_selectedStation!.$3}'
          : null;

      if (selectionKey == currentKey) {
        _selectedStation = null;
        _panelRoute = null;
      } else {
        _selectedStation = (station, route, goBack);
        if (_selectedPoint != null) {
          _selectedPoint = null;
          _highlightMarker = null;
        }
        _prepareStationInfoPanel(route, route.id);
      }
    });
  }

  Marker _createStationMarker(
      StationEdge station, BusRoute route, Color color, int goBack) {
    final selectionKey =
        '${station.position.latitude}-${station.position.longitude}-${route.id}-$goBack';
    final currentKey = _selectedStation != null
        ? '${_selectedStation!.$1.position.latitude}-${_selectedStation!.$1.position.longitude}-${_selectedStation!.$2.id}-${_selectedStation!.$3}'
        : null;
    final bool isSelected = selectionKey == currentKey;
    final double iconSize = isSelected ? 40.0 : 30.0;
    return Marker(
      point: station.position,
      width: iconSize,
      height: iconSize,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _selectStation(station, route, goBack),
        child: Icon(
          Icons.location_on,
          size: iconSize,
          color: isSelected ? Colors.amber.shade700 : color,
          shadows: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Marker> interactiveMarkers = [];
    for (final marker in widget.markers) {
      if (marker.child is GestureDetector) {
        interactiveMarkers.add(marker);
      } else if (marker is PointMarker) {
        interactiveMarkers.add(
          PointMarker(
            busPoint: marker.busPoint,
            width: marker.width,
            height: marker.height,
            alignment: marker.alignment,
            child: GestureDetector(
              onTap: () => selectPoint(marker.busPoint),
              child: marker.child,
            ),
          ),
        );
      } else {
        interactiveMarkers.add(marker);
      }
    }
    final List<Marker> allMarkersToShow = [
      ..._userSelectedMarkers,
      ...interactiveMarkers
    ];
    if (_highlightMarker != null) {
      allMarkersToShow.add(_highlightMarker!);
    }
    if (_currentLocation != null) {
      allMarkersToShow.add(Marker(
          point: _currentLocation!,
          width: 20,
          height: 20,
          child: IgnorePointer(
              child: Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ])))));
    }
    final allPolylinesToShow = [...widget.polylines, ..._userSelectedPolylines];

    final body = LayoutBuilder(
      builder: (context, constraints) {
        // --- [MODIFICATION START] ---
        final isLandscape = constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth > 800;
        final double panelHeight = isLandscape ? 140.0 : 190.0;
        const double panelMargin = 12.0;
        const double controlsPadding = 16.0;

        final bool isPanelVisible =
            _selectedPoint != null || _selectedStation != null;
        final double controlsBottom =
            (isPanelVisible ? panelHeight + panelMargin : 0.0) +
                controlsPadding;
        // --- [MODIFICATION END] ---

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // 根據 bounds 決定初始視圖
                // 1. 如果 bounds 是單一點，則直接置中並縮放
                initialCenter: (widget.bounds != null &&
                        widget.bounds!.southWest == widget.bounds!.northEast)
                    ? widget.bounds!.center
                    // 2. 如果沒有 bounds，使用預設中心點
                    : BaseMapView.getDefaultCenter(),
                initialZoom: BaseMapView.defaultZoom,

                // 如果 bounds 是一個有效的區域 (非單點)，則使用 fitCamera
                initialCameraFit: (widget.bounds != null &&
                        widget.bounds!.southWest != widget.bounds!.northEast)
                    ? CameraFit.bounds(
                        bounds: widget.bounds!,
                        padding: const EdgeInsets.all(50.0),
                        maxZoom: BaseMapView.defaultZoom)
                    : null,
                onTap: (_, __) {
                  setState(() {
                    if (_selectedPoint != null) {
                      _selectedPoint = null;
                      _highlightMarker = null;
                    }
                    if (_selectedStation != null) {
                      _selectedStation = null;
                    }
                  });
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
                    )),
                PolylineLayer(polylines: allPolylinesToShow),
                MarkerLayer(markers: allMarkersToShow),
              ],
            ),
            if (widget.isLoading || _isProcessingUserRoutes)
              const Center(child: CircularProgressIndicator())
            else if (widget.error != null)
              Center(
                  child: Card(
                      color: theme.colorScheme.primaryContainer,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      elevation: 4,
                      child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 40,
                                color: theme.colorScheme.onPrimaryContainer),
                            const SizedBox(height: 16),
                            Text(widget.error!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onPrimaryContainer)),
                            if (widget.onErrorDismiss != null) ...[
                              const SizedBox(height: 20),
                              TextButton(
                                  onPressed: widget.onErrorDismiss,
                                  style: TextButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primaryFixedDim,
                                      foregroundColor:
                                          theme.colorScheme.onPrimaryFixed),
                                  child: const Text('關閉'))
                            ]
                          ])))),
            Positioned(
              // --- [MODIFICATION] Use dynamic bottom value ---
              bottom: controlsBottom,
              right: 16,
              child: _buildMapControls(),
            ),
            // --- [MODIFICATION] Pass isLandscape flag ---
            _buildInfoPanel(isLandscape: isLandscape),
            _buildStationInfoPanel(isLandscape: isLandscape),
          ],
        );
      },
    );

    if (widget.hideAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: widget.appBarActions,
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(18.0),
            child: Container(
                color: theme.colorScheme.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                    'Map data © OpenStreetMap contributors, Imagery © Esri, Maxar, Earthstar Geo',
                    style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface.withOpacity(0.7))))),
      ),
      body: body,
    );
  }

  Widget _buildMapControls() {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12.0)),
                                child: Slider(
                                    value: _satelliteOpacity,
                                    activeColor: theme.colorScheme.primary,
                                    onChanged: (v) => setState(
                                        () => _satelliteOpacity = v)))))
                  ]))),
      const SizedBox(height: 4),
      FloatingActionButton.small(
          onPressed: _isProcessingUserRoutes ? null : _openRouteSelection,
          tooltip: '選擇繪製路線',
          elevation: 4,
          heroTag: 'select_route_layer_btn',
          child: const Icon(Icons.layers_outlined)),
      const SizedBox(height: 4),
      FloatingActionButton.small(
          onPressed: _recenterMap,
          tooltip: '重新置中',
          elevation: 4,
          heroTag: 'recenter_btn_nearby',
          child: const Icon(Icons.center_focus_strong)),
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
              : const Icon(Icons.my_location)),
      const SizedBox(height: 16),
    ]);
  }

  // --- [MODIFICATION] Add isLandscape parameter and use it ---
  Widget _buildStationInfoPanel({required bool isLandscape}) {
    final theme = Theme.of(context);
    final isVisible = _selectedStation != null;
    final double panelHeight = isLandscape ? 140.0 : 190.0;
    final station = _selectedStation?.$1;
    final goBack = _selectedStation?.$3;
    final BusRoute? routeForDisplay = _panelRoute;
    String direction = "未知";
    if (routeForDisplay != null) {
      if (goBack == 1) {
        direction = routeForDisplay.destination;
      } else if (goBack == 2) {
        direction = routeForDisplay.departure;
      }
    }
    final String stationOrder = station != null ? '第 ${station.orderNo} 站' : '';
    final latLonString = station != null
        ? '${station.position.latitude.toString()}, ${station.position.longitude.toString()}'
        : '';
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
          child: !isVisible || station == null
              ? const SizedBox.shrink()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                      child: Row(children: [
                        Expanded(
                            child: Text(station.name,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis)),
                        IconButton(
                            icon: const Icon(Icons.map_sharp),
                            color: Colors.blueAccent,
                            tooltip: '在 Google Map 上查看',
                            onPressed: () async => await launchUrl(Uri.parse(
                                "https://www.google.com/maps?q=${station.position.latitude},${station.position.longitude}(${Uri.encodeComponent(station.name)})"))),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _selectedStation = null))
                      ])),
                  const Divider(
                      height: 1, thickness: 1, indent: 16, endIndent: 16),
                  if (_isFetchingPanelRoute)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (routeForDisplay != null)
                    Expanded(
                        child: SingleChildScrollView(
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: [
                                      _buildInfoChip(
                                          icon: Icons.route_outlined,
                                          label:
                                              "${routeForDisplay.name} (${routeForDisplay.id})"),
                                      if (routeForDisplay
                                          .description.isNotEmpty)
                                        _buildInfoChip(
                                            icon: Icons.description_outlined,
                                            label: routeForDisplay.description),
                                      _buildInfoChip(
                                          icon: Icons.swap_horiz,
                                          label: "往 $direction"),
                                      _buildInfoChip(
                                          icon: Icons.format_list_numbered,
                                          label: stationOrder),
                                      InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(
                                                text: latLonString));
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          '已複製經緯度: $latLonString'),
                                                      duration: const Duration(
                                                          seconds: 2),
                                                      backgroundColor: theme
                                                          .colorScheme.primary,
                                                      showCloseIcon: true));
                                            }
                                          },
                                          child: _buildInfoChip(
                                              icon: Icons.gps_fixed,
                                              label: latLonString))
                                    ]))))
                  else
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '無法載入路線 ${_selectedStation?.$2.id} 的詳細資訊。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ),
                ]),
        ),
      ),
    );
  }

  // --- [MODIFICATION] Add isLandscape parameter and use it ---
  Widget _buildInfoPanel({required bool isLandscape}) {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    final double panelHeight = isLandscape ? 140.0 : 190.0;
    final route = _selectedRoute;
    final String? plate = _selectedPlate;
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
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                      child: Row(children: [
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
                                    final mapTitle = (plate != null
                                            ? "$plate | "
                                            : "") +
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
                            onPressed: () => selectPoint(_selectedPoint!))
                      ])),
                  const Divider(
                      height: 1, thickness: 1, indent: 16, endIndent: 16),
                  if (_isFetchingRouteDetail)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (route != null)
                    Expanded(
                        child: SingleChildScrollView(
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: [
                                      if (plate != null)
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
                                              : Colors.orange),
                                      _buildInfoChip(
                                          icon:
                                              Icons.person_pin_circle_outlined,
                                          label:
                                              "駕駛：${Static.getDriverText(_selectedPoint!.driverId)}"),
                                      InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                          onTap: () {
                                            final lat = _selectedPoint!.lat;
                                            final lon = _selectedPoint!.lon;
                                            final latLonString = '$lat, $lon';
                                            Clipboard.setData(ClipboardData(
                                                text: latLonString));
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          '已複製經緯度：$latLonString'),
                                                      duration: const Duration(
                                                          seconds: 2),
                                                      backgroundColor: theme
                                                          .colorScheme.primary,
                                                      showCloseIcon: true));
                                            }
                                          },
                                          child: _buildInfoChip(
                                              icon: Icons.gps_fixed,
                                              label:
                                                  "${_selectedPoint!.lat.toString()}, ${_selectedPoint!.lon.toString()}"))
                                    ]))))
                  else
                    Expanded(
                        child: Center(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                    '無法載入路線 ${_selectedPoint!.routeId} 的詳細資訊。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: theme.colorScheme.error)))))
                ]),
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
