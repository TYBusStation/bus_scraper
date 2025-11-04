import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../data/car.dart';
import '../static.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

class _MapDisplayData {
  final List<Polyline> polylines;
  final List<Marker> markers;
  final LatLngBounds? bounds;

  _MapDisplayData({
    required this.polylines,
    required this.markers,
    this.bounds,
  });
}

class _ColorCycler {
  int _index = 0;

  Color get nextColor {
    final color =
        BaseMapView.segmentColors[_index % BaseMapView.segmentColors.length];
    _index++;
    return color;
  }
}

class MultiHistoryOsmPage extends StatefulWidget {
  final List<Car> cars;

  const MultiHistoryOsmPage({super.key, required this.cars});

  @override
  State<MultiHistoryOsmPage> createState() => _MultiHistoryOsmPageState();
}

class _MultiHistoryOsmPageState extends State<MultiHistoryOsmPage> {
  bool _isLoading = true;
  String? _error;
  final Map<String, List<BusPoint>> _pointsByPlate = {};
  _MapDisplayData _mapData = _MapDisplayData(polylines: [], markers: []);
  final GlobalKey<BaseMapViewState> _baseMapStateKey =
      GlobalKey<BaseMapViewState>();

  @override
  void initState() {
    super.initState();
    _fetchAndDrawMap();
  }

  Future<void> _fetchAndDrawMap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<String> errorPlates = [];

      final futures = widget.cars.map((car) async {
        final DateTime? lastSeen = car.lastSeen;
        if (lastSeen == null) {
          return {'plate': car.plate, 'points': <BusPoint>[]};
        }

        final DateTime endTime = lastSeen;
        final DateTime startTime = endTime
            .subtract(Duration(minutes: Static.localStorage.liveTrackDuration));

        final formattedStartTime = Static.apiTimeFormat.format(startTime);
        final formattedEndTime = Static.apiTimeFormat.format(endTime);

        final url = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/bus_data/${car.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

        try {
          final response = await Static.dio.getUri(url);
          if (response.statusCode == 200 && response.data != null) {
            final List<dynamic> decodedData = response.data;
            final newPoints =
                decodedData.map((item) => BusPoint.fromJson(item)).toList();
            return {'plate': car.plate, 'points': newPoints};
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) {
            errorPlates.add(car.plate);
          }
        }
        return {'plate': car.plate, 'points': <BusPoint>[]};
      });

      final results = await Future.wait(futures);
      if (!mounted) return;

      for (var result in results) {
        final plate = result['plate'] as String;
        final newPoints = result['points'] as List<BusPoint>;
        _pointsByPlate[plate] = newPoints;
      }

      final newMapData = _prepareMapData();
      final allPoints =
          _pointsByPlate.values.expand((points) => points).toList();
      String? newError;

      if (allPoints.isEmpty) {
        newError = "找不到任何車輛在最後上線時間前的軌跡資料。";
      } else if (errorPlates.isNotEmpty) {
        newError = "部分車輛資料獲取失敗";
      }

      setState(() {
        _mapData = newMapData;
        _isLoading = false;
        _error = newError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "發生未知錯誤: $e";
        _isLoading = false;
      });
    }
  }

  _MapDisplayData _prepareMapData() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    final _colorCycler = _ColorCycler();
    final List<LatLng> allPointsForBounds = [];

    _pointsByPlate.forEach((plate, points) {
      if (points.isEmpty) return;

      final segmentColor = _colorCycler.nextColor;
      final segmentPoints = points.map((p) => LatLng(p.lat, p.lon)).toList();
      allPointsForBounds.addAll(segmentPoints);

      allPolylines.add(Polyline(
        points: segmentPoints,
        color: segmentColor,
        strokeWidth: 4,
      ));

      for (final point in points) {
        allMarkers.add(_createTrackPointMarker(point, segmentColor, plate));
      }

      allMarkers.add(_createStartEndMarker(points.first, plate, isStart: true));
      allMarkers.add(_createStartEndMarker(points.last, plate, isStart: false));
    });

    return _MapDisplayData(
      polylines: allPolylines,
      markers: allMarkers,
      bounds: allPointsForBounds.isNotEmpty
          ? LatLngBounds.fromPoints(allPointsForBounds)
          : null,
    );
  }

  PointMarker _createTrackPointMarker(
      BusPoint point, Color color, String plate) {
    return PointMarker(
      busPoint: point,
      width: 14,
      height: 14,
      child: GestureDetector(
        onTap: () {
          _baseMapStateKey.currentState?.selectPoint(point, plate: plate);
        },
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

  PointMarker _createStartEndMarker(BusPoint point, String plate,
      {required bool isStart}) {
    final IconData iconData =
        isStart ? Icons.flag_circle_rounded : Icons.stop_circle_rounded;
    final Color iconColor = isStart ? Colors.greenAccent : Colors.redAccent;
    const double iconSize = 32.0;

    return PointMarker(
      busPoint: point,
      width: 100,
      height: 50,
      child: GestureDetector(
        onTap: () {
          _baseMapStateKey.currentState?.selectPoint(point, plate: plate);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                plate,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Icon(
              iconData,
              color: iconColor,
              size: iconSize,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPoints = _pointsByPlate.values.expand((p) => p).toList();
    final bool hasData = allPoints.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('群組最後位置'),
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
      body: hasData
          ? BaseMapView(
              key: _baseMapStateKey,
              appBarTitle: '',
              hideAppBar: true,
              isLoading: _isLoading,
              error: _error,
              points: allPoints,
              polylines: _mapData.polylines,
              markers: _mapData.markers,
              bounds: _mapData.bounds,
              onErrorDismiss: () => setState(() => _error = null),
            )
          : Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_error ?? '沒有可顯示的軌跡數據。'),
            ),
    );
  }
}
