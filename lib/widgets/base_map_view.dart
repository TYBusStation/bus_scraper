// lib/widgets/base_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../static.dart';

// PointMarker class (無變更)
class PointMarker extends Marker {
  final BusPoint busPoint;

  PointMarker({
    required this.busPoint,
    required super.child,
    super.width = 30.0,
    super.height = 30.0,
    super.alignment,
  }) : super(point: LatLng(busPoint.lat, busPoint.lon));
}

// BaseMapView class (無變更)
class BaseMapView extends StatefulWidget {
  static const double defaultZoom = 17;

  static const List<Color> segmentColors = [
    Colors.red,
    Colors.teal,
    Colors.amber,
    Colors.greenAccent,
    Colors.orange,
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.lightGreen,
    Colors.cyan,
    Colors.brown,
    Colors.indigo,
    Colors.deepPurple,
  ];

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

  // ** 2. 新增狀態變數 **
  LatLng? _currentLocation;
  bool _isLocating = false;

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

  // selectPoint 方法 (無變更)
  void selectPoint(BusPoint point, {String? plate}) {
    setState(() {
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
        _selectedPlate = null;
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
      }
    });
  }

  // _recenterMap 方法 (無變更)
  void _recenterMap() {
    if (widget.points.isEmpty) {
      return;
    }

    if (widget.bounds != null) {
      final bounds = widget.bounds!;
      if (bounds.southWest == bounds.northEast) {
        _mapController.move(bounds.center, BaseMapView.defaultZoom);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
              maxZoom: BaseMapView.defaultZoom),
        );
      }
    } else {
      final lastPoint = widget.points.last;
      _mapController.move(
          LatLng(lastPoint.lat, lastPoint.lon), BaseMapView.defaultZoom);
    }
  }

  // ** 3. 新增定位方法 **
  Future<void> _locateMe() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('請開啟裝置的定位服務')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('您已拒絕位置權限')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('位置權限已被永久拒絕，請至應用程式設定中開啟')));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = newLocation;
      });

      _mapController.move(newLocation, 17.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法獲取位置: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
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

    final List<Marker> allMarkersToShow = [...interactiveMarkers];
    if (_highlightMarker != null) {
      allMarkersToShow.add(_highlightMarker!);
    }

    // ** 4. 新增當前位置的 Marker **
    if (_currentLocation != null) {
      allMarkersToShow.add(
        Marker(
          point: _currentLocation!,
          width: 24,
          height: 24,
          child: IgnorePointer(
            // 讓這個 marker 不可點擊
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ],
              ),
            ),
          ),
        ),
      );
    }

    final body = Stack(
      // ... Stack 內容 (無變更)
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.points.isNotEmpty
                ? LatLng(widget.points.last.lat, widget.points.last.lon)
                : const LatLng(24.986763, 121.314007),
            initialZoom: BaseMapView.defaultZoom,
            initialCameraFit: (widget.bounds != null &&
                    widget.bounds!.southWest != widget.bounds!.northEast)
                ? CameraFit.bounds(
                    bounds: widget.bounds!,
                    padding: const EdgeInsets.all(50.0),
                    maxZoom: BaseMapView.defaultZoom)
                : null,
            onTap: (_, __) {
              if (_selectedPoint != null) {
                setState(() {
                  _selectedPoint = null;
                  _highlightMarker = null;
                });
              }
            },
          ),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            Opacity(
              opacity: _satelliteOpacity,
              child: TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
            ),
            PolylineLayer(polylines: widget.polylines),
            MarkerLayer(markers: allMarkersToShow), // markers 已包含當前位置
          ],
        ),
        if (widget.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (widget.error != null)
          Center(
            child: Card(
              color: theme.colorScheme.primaryContainer,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (widget.onErrorDismiss != null) ...[
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: widget.onErrorDismiss,
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryFixedDim,
                          foregroundColor: theme.colorScheme.onPrimaryFixed,
                        ),
                        child: const Text('關閉'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: 15,
          right: 10,
          child: _buildMapControls(),
        ),
        _buildInfoPanel(),
      ],
    );

    // ... Scaffold 部分 (無變更)
    if (widget.hideAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: widget.appBarActions,
        backgroundColor: theme.colorScheme.surface.withAlpha(220),
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18.0),
          child: Container(
            color: theme.colorScheme.surface.withAlpha(200),
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
      ),
      body: body,
    );
  }

  Widget _buildMapControls() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 衛星圖層 Slider Card (已再次縮小)
        Card(
          elevation: 4,
          // --- 變更開始 ---
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          // 圓角可選地縮小
          child: Container(
            width: 40, // 原為 48
            height: 120, // 原為 150
            padding: const EdgeInsets.symmetric(vertical: 4), // 原為 6
            // --- 變更結束 ---
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.satellite_alt_outlined,
                    // --- 變更開始 ---
                    size: 18, // 原為 20
                    // --- 變更結束 ---
                    color: theme.colorScheme.onSurface),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    // --- 變更開始：使用 SliderTheme 來縮小滑桿本身 ---
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0, // 軌道高度 (厚度)
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0), // 滑塊圓點的大小
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12.0), // 按下時水波紋的大小
                      ),
                      child: Slider(
                        value: _satelliteOpacity,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (v) => setState(() => _satelliteOpacity = v),
                      ),
                    ),
                    // --- 變更結束 ---
                  ),
                ),
              ],
            ),
          ),
        ),
        // 重新置中按鈕 (維持縮小版)
        FloatingActionButton.small(
          onPressed: _recenterMap,
          tooltip: '重新置中',
          elevation: 4,
          heroTag: 'recenter_btn',
          child: const Icon(Icons.my_location),
        ),
        // 定位按鈕 (維持縮小版)
        FloatingActionButton.small(
          onPressed: _isLocating ? null : _locateMe,
          tooltip: '定位我的位置',
          elevation: 4,
          backgroundColor: _isLocating
              ? Colors.grey
              : theme.floatingActionButtonTheme.backgroundColor,
          heroTag: 'locate_me_btn',
          child: _isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_pin),
        ),
      ],
    );
  }

  // _buildInfoPanel 方法 (無變更)
  Widget _buildInfoPanel() {
    // ... 此方法內容完全不變 ...
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    const double panelHeight = 190.0;

    final route = isVisible
        ? Static.routeData.firstWhere((r) => r.id == _selectedPoint!.routeId,
            orElse: () => Static.routeData.first)
        : null;

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
            ],
          ),
          child: isVisible && _selectedPoint != null && route != null
              ? Column(
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
                              onPressed: () async {
                                final mapTitle = (plate != null
                                        ? "$plate | "
                                        : "") +
                                    "${route.name} | ${route.description} "
                                        "| 往 ${_selectedPoint!.goBack == 1 ? route.destination : route.departure} "
                                        "| ${_selectedPoint!.dutyStatus == 0 ? "營運" : "非營運"} "
                                        "| 駕駛：${_selectedPoint!.driverId == "0" ? "未知" : _selectedPoint!.driverId} "
                                        "| ${Static.displayDateFormat.format(_selectedPoint!.dataTime)}";

                                await launchUrl(Uri.parse(
                                    "https://www.google.com/maps?q=${_selectedPoint!.lat}"
                                    ",${_selectedPoint!.lon}($mapTitle)"));
                              }),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => selectPoint(_selectedPoint!),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, thickness: 1, indent: 16, endIndent: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 6.0,
                            children: [
                              if (plate != null)
                                _buildInfoChip(
                                  icon: Icons.numbers,
                                  label: "車牌：$plate",
                                  color: theme.colorScheme.primary,
                                ),
                              _buildInfoChip(
                                  icon: Icons.route_outlined,
                                  label: "${route.name} (${route.id})"),
                              _buildInfoChip(
                                  icon: Icons.description_outlined,
                                  label: route.description),
                              _buildInfoChip(
                                  icon: Icons.swap_horiz,
                                  label:
                                      "往 ${_selectedPoint!.goBack == 1 ? route.destination : route.departure}"),
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
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // _buildInfoChip 方法 (無變更)
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
