// lib/widgets/base_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../static.dart';

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
    this.onPointSelected, // **新增**
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

  @override
  void didUpdateWidget(covariant BaseMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 處理異步加載的情況 (例如 LiveOsmPage)
    // 當 bounds 從 null 變為有值時，觸發定位
    if (widget.bounds != null && oldWidget.bounds == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _recenterMap();
        }
      });
    }
  }

  void selectPoint(BusPoint point, {String? plate}) {
    setState(() {
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
        _selectedPlate = null; // 清除車牌
      } else {
        _selectedPoint = point;
        _selectedPlate = plate; // 存儲車牌
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

  // *** 核心修正點 1：修改 _recenterMap 方法 ***
  void _recenterMap() {
    if (widget.points.isEmpty) {
      // 如果沒有點，則不執行任何操作
      return;
    }

    if (widget.bounds != null) {
      final bounds = widget.bounds!;
      // 檢查邊界框是否為退化狀態（所有點都在同一個位置）
      if (bounds.southWest == bounds.northEast) {
        // 如果是，則將地圖移動到該單點，並使用固定的縮放層級
        _mapController.move(bounds.center, BaseMapView.defaultZoom);
      } else {
        // 否則，正常使用 fitCamera 來適應邊界
        _mapController.fitCamera(
          CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(50),
              maxZoom: BaseMapView.defaultZoom),
        );
      }
    } else {
      // 如果沒有提供 bounds，則回退到以最後一個點為中心
      final lastPoint = widget.points.last;
      _mapController.move(
          LatLng(lastPoint.lat, lastPoint.lon), BaseMapView.defaultZoom);
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

    // 我們需要創建一個新的 marker 列表來添加 GestureDetector
    final List<Marker> interactiveMarkers = [];
    for (final marker in widget.markers) {
      if (marker.child is GestureDetector) {
        // 如果 marker 已經是交互式的 (從 MultiLiveOsmPage 傳來)，直接添加
        interactiveMarkers.add(marker);
      } else if (marker is PointMarker) {
        // 如果是 PointMarker (從 LiveOsmPage 傳來)，為它包裝 GestureDetector
        interactiveMarkers.add(
          PointMarker(
            busPoint: marker.busPoint,
            width: marker.width,
            height: marker.height,
            alignment: marker.alignment,
            child: GestureDetector(
              onTap: () => selectPoint(marker.busPoint), // 不傳遞 plate
              child: marker.child,
            ),
          ),
        );
      } else {
        // 其他類型的 marker
        interactiveMarkers.add(marker);
      }
    }

    final List<Marker> allMarkersToShow = [...interactiveMarkers];
    if (_highlightMarker != null) {
      allMarkersToShow.add(_highlightMarker!);
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
            // *** 核心修正點 2：修改 initialCameraFit 屬性 ***
            // 同樣檢查 bounds 是否為退化狀態
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 56,
            height: 180,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.satellite_alt_outlined,
                    color: theme.colorScheme.onSurface),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _satelliteOpacity,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (v) => setState(() => _satelliteOpacity = v),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: _recenterMap,
          tooltip: '重新置中',
          elevation: 4,
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    const double panelHeight = 190.0;

    final route = isVisible
        ? Static.routeData.firstWhere((r) => r.id == _selectedPoint!.routeId,
            orElse: () => Static.routeData.first)
        : null;

    // 直接使用 state 中的 _selectedPlate
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
                                // 根據 plate 是否存在，動態構建 Google Maps 連結的標題
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
                            onPressed: () =>
                                selectPoint(_selectedPoint!), // 點擊關閉會取消選中
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
                              // **核心邏輯: 只有在 plate 不為 null 時才顯示車牌 Chip**
                              if (plate != null)
                                _buildInfoChip(
                                  icon: Icons.numbers,
                                  label: "車牌：$plate",
                                  color: theme.colorScheme.primary, // 給予突出的顏色
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
