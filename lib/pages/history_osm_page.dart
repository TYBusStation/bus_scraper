// lib/pages/history_osm_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../static.dart';

class HistoryOsmPage extends StatefulWidget {
  final String plate;
  final List<BusPoint> points;

  const HistoryOsmPage({super.key, required this.plate, required this.points});

  @override
  State<HistoryOsmPage> createState() => _HistoryOsmPageState();
}

class _HistoryOsmPageState extends State<HistoryOsmPage> {
  // ... (所有狀態變數和 initState, _prepareMapData, Marker 創建方法等都保持不變) ...
  final MapController _mapController = MapController();
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;
  double _satelliteOpacity = 0.3;

  BusPoint? _selectedPoint;
  Marker? _highlightMarker;

  final List<Color> _segmentColors = const [
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

  @override
  void initState() {
    super.initState();
    _prepareMapData();
  }

  void _prepareMapData() {
    if (widget.points.isEmpty) return;

    if (widget.points.length > 1) {
      _bounds = LatLngBounds.fromPoints(
          widget.points.map((p) => LatLng(p.lat, p.lon)).toList());
    }

    final List<Polyline> segmentedPolylines = [];
    final List<Marker> allMarkers = [];

    if (widget.points.length > 1) {
      int colorIndex = 0;
      List<LatLng> currentSegmentPoints = [
        LatLng(widget.points.first.lat, widget.points.first.lon)
      ];

      for (int i = 1; i < widget.points.length; i++) {
        final currentPoint = widget.points[i];
        final previousPoint = widget.points[i - 1];
        final segmentColor = _segmentColors[colorIndex % _segmentColors.length];
        allMarkers.add(_createTrackPointMarker(previousPoint, segmentColor));
        final timeDifference =
            currentPoint.dataTime.difference(previousPoint.dataTime);
        bool isSegmentEnd = (currentPoint.routeId != previousPoint.routeId ||
            currentPoint.goBack != previousPoint.goBack ||
            timeDifference.inMinutes >= 10);
        if (isSegmentEnd) {
          segmentedPolylines.add(Polyline(
              points: List.from(currentSegmentPoints),
              color: segmentColor,
              strokeWidth: 4));
          colorIndex++;
          currentSegmentPoints = [
            LatLng(previousPoint.lat, previousPoint.lon),
            LatLng(currentPoint.lat, currentPoint.lon)
          ];
        } else {
          currentSegmentPoints.add(LatLng(currentPoint.lat, currentPoint.lon));
        }
      }
      final lastSegmentColor =
          _segmentColors[colorIndex % _segmentColors.length];
      if (currentSegmentPoints.length > 1) {
        segmentedPolylines.add(Polyline(
            points: currentSegmentPoints,
            color: lastSegmentColor,
            strokeWidth: 4));
      }
      allMarkers
          .add(_createTrackPointMarker(widget.points.last, lastSegmentColor));
    } else if (widget.points.isNotEmpty) {
      allMarkers.add(_createSinglePointMarker(widget.points.first));
    }

    if (widget.points.length > 1) {
      allMarkers.add(_createStartEndMarker(widget.points.first, isStart: true));
      allMarkers.add(_createStartEndMarker(widget.points.last, isStart: false));
    }

    setState(() {
      _polylines = segmentedPolylines;
      _markers = allMarkers;
    });
  }

  Marker _createTrackPointMarker(BusPoint point, Color color) {
    return Marker(
      point: LatLng(point.lat, point.lon),
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

  Marker _createSinglePointMarker(BusPoint point) {
    return Marker(
      point: LatLng(point.lat, point.lon),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _selectPoint(point),
        child: const Icon(Icons.directions_bus, color: Colors.pink, size: 40),
      ),
    );
  }

  Marker _createStartEndMarker(BusPoint point, {required bool isStart}) {
    return Marker(
      point: LatLng(point.lat, point.lon),
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => _selectPoint(point),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isStart ? Colors.green : Colors.red).withOpacity(0.2),
              ),
            ),
            Icon(
              isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded,
              color: isStart
                  ? Colors.greenAccent.shade700
                  : Colors.redAccent.shade700,
              size: 32,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
            ),
          ],
        ),
      ),
    );
  }

  void _selectPoint(BusPoint point) {
    setState(() {
      if (_selectedPoint == point) {
        _selectedPoint = null;
        _highlightMarker = null;
      } else {
        _selectedPoint = point;
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
              shadows: const [
                Shadow(
                    color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.plate} 軌跡地圖')),
        body: const Center(child: Text('沒有可顯示的點位數據。')),
      );
    }

    final theme = Theme.of(context);
    final List<Marker> allMarkersToShow = [..._markers];
    if (_highlightMarker != null) {
      allMarkersToShow.add(_highlightMarker!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 軌跡地圖'),
        backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  LatLng(widget.points.first.lat, widget.points.first.lon),
              initialZoom: widget.points.length == 1 ? 17.0 : 12.0,
              initialCameraFit: widget.points.length > 1 && _bounds != null
                  ? CameraFit.bounds(
                      bounds: _bounds!, padding: const EdgeInsets.all(50.0))
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
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              Opacity(
                opacity: _satelliteOpacity,
                child: TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: allMarkersToShow),
              Align(
                alignment: Alignment.topRight,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(8.0),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Esri, Maxar, Earthstar Geo, and the GIS User Community',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  Widget _buildInfoPanel() {
    final theme = Theme.of(context);
    final isVisible = _selectedPoint != null;
    // *** 修改點 2: 微調面板高度以適應新的 Chip 樣式 ***
    const double panelHeight = 190.0;

    final route = isVisible
        ? Static.routeData.firstWhere((r) => r.id == _selectedPoint!.routeId)
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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isVisible
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Static.displayDateFormat
                                .format(_selectedPoint!.dataTime),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedPoint = null;
                                _highlightMarker = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, thickness: 1, indent: 16, endIndent: 16),
                    Expanded(
                      // 使用 Expanded + SingleChildScrollView 確保內容過多時可滾動
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 6.0,
                            children: [
                              // *** 修改點 3: 使用 _buildInfoChip 替換所有 _buildInfoChipForPanel ***
                              _buildInfoChip(
                                icon: Icons.route_outlined,
                                label: "${route!.name} (${route.id})",
                              ),
                              _buildInfoChip(
                                icon: Icons.description_outlined,
                                label: route.description,
                              ),
                              _buildInfoChip(
                                icon: Icons.swap_horiz,
                                label:
                                    "往 ${_selectedPoint!.goBack == 1 ? route.destination : route.departure}",
                              ),
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
                                    "駕駛：${_selectedPoint!.driverId == "0" ? "未知" : _selectedPoint!.driverId}",
                              ),
                              _buildInfoChip(
                                icon: Icons.gps_fixed,
                                label:
                                    "${_selectedPoint!.lat.toStringAsFixed(5)}, ${_selectedPoint!.lon.toStringAsFixed(5)}",
                              ),
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

  // *** 修改點 1: 複製 history_page.dart 的 _buildInfoChip 方法過來 ***
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

  // _buildMapControls 保持不變
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
                      inactiveColor:
                          theme.colorScheme.onSurface.withOpacity(0.3),
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
          onPressed: () {
            if (widget.points.length > 1 && _bounds != null) {
              _mapController.fitCamera(CameraFit.bounds(
                  bounds: _bounds!, padding: const EdgeInsets.all(50)));
            } else if (widget.points.isNotEmpty) {
              _mapController.move(
                  LatLng(widget.points.first.lat, widget.points.first.lon),
                  17.0);
            }
          },
          tooltip: '重新置中',
          elevation: 4,
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }
}
