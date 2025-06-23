// lib/widgets/base_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../data/bus_route.dart';
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

  LatLng? _currentLocation;
  bool _isLocating = false;

  // --- 變更開始: 新增狀態變數以處理未知路線 ---
  BusRoute? _selectedRoute;
  bool _isFetchingRouteDetail = false;

  // --- 變更結束 ---

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

  // --- 變更開始: 新增獲取路線詳情的方法 ---
  /// 異步獲取未知路線的詳細資訊並更新狀態。
  Future<void> _fetchAndSetRouteDetail(String routeId) async {
    // 使用 Static 類別來獲取未知路線的詳細資訊
    final route = await Static.fetchRouteDetailById(routeId);
    if (mounted) {
      // 確保當前選擇的點仍然是我們正在獲取的那個點
      if (_selectedPoint != null && _selectedPoint!.routeId == routeId) {
        setState(() {
          _selectedRoute = route; // 如果獲取失敗，route 會是 null
          _isFetchingRouteDetail = false;
        });
      }
    }
  }

  // --- 變更結束 ---

  // --- 變更開始: 修改 selectPoint 方法以處理未知路線 ---
  void selectPoint(BusPoint point, {String? plate}) {
    setState(() {
      if (_selectedPoint == point) {
        // --- 取消選擇 ---
        _selectedPoint = null;
        _highlightMarker = null;
        _selectedPlate = null;
        _selectedRoute = null; // 清除已選擇的路線
        _isFetchingRouteDetail = false; // 重置加載狀態
      } else {
        // --- 選擇新的點 ---
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

        // --- 處理路線資訊 ---
        _selectedRoute = null; // 先清除舊的路線
        _isFetchingRouteDetail = false; // 重置狀態

        // 在現有資料中尋找路線
        final routeIndex =
            Static.routeData.indexWhere((r) => r.id == point.routeId);

        if (routeIndex != -1) {
          // 在靜態資料中找到了路線
          _selectedRoute = Static.routeData[routeIndex];
        } else {
          // 沒有找到，需要從 API 獲取
          _isFetchingRouteDetail = true;
          // 呼叫非同步方法，不要在 setState 中 await
          _fetchAndSetRouteDetail(point.routeId);
        }
      }
    });
  }

  // --- 變更結束 ---

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

    if (_currentLocation != null) {
      allMarkersToShow.add(
        Marker(
          point: _currentLocation!,
          width: 24,
          height: 24,
          child: IgnorePointer(
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
                // selectPoint is now the single source of truth for deselection
                selectPoint(_selectedPoint!);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            PolylineLayer(polylines: widget.polylines),
            MarkerLayer(markers: allMarkersToShow),
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
          heroTag: 'recenter_btn',
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 4),
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

  // --- 變更開始: 修改 _buildInfoPanel 以顯示加載和錯誤狀態 ---
  Widget _buildInfoPanel() {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    const double panelHeight = 190.0;

    // 現在直接使用狀態變數
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
            ],
          ),
          child: !isVisible
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header (一直顯示) ---
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
                              // 當路線資訊還在加載或加載失敗時，禁用此按鈕
                              onPressed: route == null
                                  ? null
                                  : () async {
                                      final mapTitle = (plate != null
                                              ? "$plate | "
                                              : "") +
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
                            onPressed: () => selectPoint(_selectedPoint!),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, thickness: 1, indent: 16, endIndent: 16),

                    // --- Body (根據狀態條件性顯示) ---
                    if (_isFetchingRouteDetail)
                      // 狀態 1: 正在加載
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (route != null)
                      // 狀態 2: 成功加載路線資訊
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
                        ),
                      )
                    else
                      // 狀態 3: 加載失敗 (或無此路線)
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

  // --- 變更結束 ---

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
