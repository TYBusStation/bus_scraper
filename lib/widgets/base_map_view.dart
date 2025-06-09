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
  }) : super(
            point: LatLng(
                busPoint.lat, busPoint.lon)); // 使用 busPoint 的經緯度作為 Marker 的位置
}

/// 一個基礎的地圖視圖 Widget，封裝了共享的地圖 UI 和邏輯。
/// 包含地圖、圖層、控件和資訊面板。
class BaseMapView extends StatefulWidget {
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

  // --- 從父 Widget 傳入的數據 ---
  final String appBarTitle;
  final List<Widget>? appBarActions;
  final bool isLoading;
  final String? error;

  final List<BusPoint> points; // 用於地圖置中和初始位置
  final List<Polyline> polylines;
  final List<Marker> markers;
  final LatLngBounds? bounds;

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
  });

  @override
  State<BaseMapView> createState() => _BaseMapViewState();
}

class _BaseMapViewState extends State<BaseMapView> {
  // --- 內部 UI 狀態 ---
  final MapController _mapController = MapController();
  double _satelliteOpacity = 0.3;
  BusPoint? _selectedPoint;
  Marker? _highlightMarker;

  /// 處理用戶點擊軌跡點的事件
  void _selectPoint(BusPoint point) {
    setState(() {
      // 如果點擊同一個點，則取消選擇
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
      } else {
        _selectedPoint = point;
        // 創建一個高亮標記來顯示選擇的點
        _highlightMarker = Marker(
          point: LatLng(point.lat, point.lon),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            // 避免高亮標記本身被點擊
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

  /// 將地圖視圖重新置中以顯示所有軌跡
  void _recenterMap() {
    if (widget.points.length > 1 && widget.bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
            bounds: widget.bounds!, padding: const EdgeInsets.all(50)),
      );
    } else if (widget.points.isNotEmpty) {
      // 如果只有一個點或沒有邊界，則移動到最後一個點
      final lastPoint = widget.points.last;
      _mapController.move(LatLng(lastPoint.lat, lastPoint.lon), 17.0);
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

    // *** 核心修正點 ***
    // 處理傳入的 markers，為 PointMarker 添加點擊事件
    final processedMarkers = widget.markers.map((marker) {
      // 檢查 marker 是否是我們自定義的 PointMarker
      if (marker is PointMarker) {
        // 如果是，返回一個新的標準 Marker，
        // 其 child 被 GestureDetector 包裹，onTap 會呼叫內部的 _selectPoint 方法。
        return Marker(
          point: marker.point,
          width: marker.width,
          height: marker.height,
          alignment: marker.alignment,
          child: GestureDetector(
            onTap: () => _selectPoint(marker.busPoint), // 在這裡建立連接！
            child: marker.child,
          ),
        );
      }
      // 如果是普通 Marker，直接返回
      return marker;
    }).toList();

    // 將處理過的 markers 和高亮 marker 組合起來顯示
    final List<Marker> allMarkersToShow = [...processedMarkers];
    if (_highlightMarker != null) {
      allMarkersToShow.add(_highlightMarker!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: widget.appBarActions,
        backgroundColor: theme.colorScheme.surface.withAlpha(220),
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // 初始中心點設為最後一個點或台灣中心
              initialCenter: widget.points.isNotEmpty
                  ? LatLng(widget.points.last.lat, widget.points.last.lon)
                  : const LatLng(23.5, 121.0),
              initialZoom: 15.0,
              // 如果有邊界數據，則自動縮放到能容納所有點的視圖
              initialCameraFit: widget.bounds != null
                  ? CameraFit.bounds(
                      bounds: widget.bounds!,
                      padding: const EdgeInsets.all(50.0),
                    )
                  : null,
              // 點擊地圖空白處時取消選擇點
              onTap: (_, __) {
                if (_selectedPoint != null) {
                  setState(() {
                    _selectedPoint = null;
                    _highlightMarker = null;
                  });
                }
              },
              // 把 `onTap` 的邏輯轉發給 marker
              // 注意：這需要 `flutter_map` 的一個較新版本。
              // 如果 marker 上的 `onTap` 不起作用，可以將 `_selectPoint` 綁定到 `GestureDetector` 中。
              // 這裡的程式碼結構已將 onTap 放在 marker 的 GestureDetector 中，所以這裡不需要。
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              Opacity(
                opacity: _satelliteOpacity,
                child: TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
              ),
              PolylineLayer(polylines: widget.polylines),
              MarkerLayer(markers: allMarkersToShow),
              // 版權資訊
              Align(
                alignment: Alignment.topRight,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                        'Esri, Maxar, Earthstar Geo, and the GIS User Community',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ),
                ),
              ),
            ],
          ),
          // --- 疊加層 (Loading, Error) ---
          if (widget.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (widget.error != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 10)
                    ]),
                child: Text(widget.error!,
                    style: const TextStyle(fontSize: 16, color: Colors.red)),
              ),
            ),
          // --- 控件和資訊面板 ---
          Positioned(
            top: 30,
            right: 10,
            child: _buildMapControls(),
          ),
          _buildInfoPanel(),
        ],
      ),
    );
  }

  /// 建立地圖控件（衛星圖層滑桿和置中按鈕）
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

  /// 建立底部滑出的資訊面板
  Widget _buildInfoPanel() {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    const double panelHeight = 190.0;

    // 查找對應的路線資訊
    final route = isVisible
        ? Static.routeData.firstWhere((r) => r.id == _selectedPoint!.routeId,
            orElse: () => Static.routeData.first) // 找不到時的後備
        : null;

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
                            onPressed: () async => await launchUrl(Uri.parse(
                                "https://www.google.com/maps?q=${_selectedPoint!.lat},${_selectedPoint!.lon}(${route.name} | ${route.description} | 往 ${_selectedPoint!.goBack == 1 ? route.destination : route.departure} | ${_selectedPoint!.dutyStatus == 0 ? "營運" : "非營運"} | 駕駛：${_selectedPoint!.driverId == "0" ? "未知" : _selectedPoint!.driverId} | ${Static.displayDateFormat.format(_selectedPoint!.dataTime)})")),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _selectedPoint = null;
                              _highlightMarker = null;
                            }),
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

  /// 建立資訊面板中的小標籤 (Chip)
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
