import 'package:bus_scraper/utils/map_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_point.dart';
import '../data/car.dart';
import '../data/trajectory_segment.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/base_map_view.dart';
import '../widgets/point_marker.dart';

class MultiHistoryOsmPage extends StatefulWidget {
  final String title;
  final List<Car> cars;
  final DateTime? endTime;
  final DateTime? startTime;

  const MultiHistoryOsmPage({
    super.key,
    required this.title,
    required this.cars,
    this.endTime,
    this.startTime,
  });

  @override
  State<MultiHistoryOsmPage> createState() => _MultiHistoryOsmPageState();
}

class _MultiHistoryOsmPageState extends State<MultiHistoryOsmPage> {
  bool _isLoading = true;
  String? _error;
  final Map<String, List<TrajectorySegment>> _segmentsByPlate = {};
  List<BusPoint> _allPoints = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  LatLngBounds? _bounds;

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
        if (car.lastSeen == null) {
          errorPlates.add(car.plate);
          return {'plate': car.plate, 'segments': <TrajectorySegment>[]};
        }
        final DateTime endTime = widget.endTime ?? car.lastSeen!;
        final DateTime startTime = widget.startTime ??
            endTime.subtract(
                Duration(minutes: Static.localStorage.liveTrackDuration));

        final formattedStartTime =
            FormatterUtils.apiTimeFormat.format(startTime);
        final formattedEndTime = FormatterUtils.apiTimeFormat.format(endTime);

        final url = Uri.parse(
            "${Static.apiBaseUrl}/${Static.city.code}/bus_data/${car.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

        try {
          final response = await Static.dio.getUri(url);
          if (response.statusCode == 200 && response.data != null) {
            final List<dynamic> decodedData = response.data;
            if (decodedData.isNotEmpty) {
              final points =
                  decodedData.map((item) => BusPoint.fromJson(item)).toList();
              final segments = MapUtils.processPointsIntoSegments(points);
              return {'plate': car.plate, 'segments': segments};
            }
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) {
            errorPlates.add(car.plate);
          }
        }
        return {'plate': car.plate, 'segments': <TrajectorySegment>[]};
      });

      final results = await Future.wait(futures);
      if (!mounted) return;

      for (var result in results) {
        final plate = result['plate'] as String;
        final segments = result['segments'] as List<TrajectorySegment>;
        if (segments.isNotEmpty) {
          _segmentsByPlate[plate] = segments;
        }
      }

      _prepareMapData();

      String? newError;
      if (_segmentsByPlate.isEmpty) {
        newError = "找不到任何車輛在最後上線時間前的軌跡資料。";
      } else if (errorPlates.isNotEmpty) {
        newError = "部分車輛資料獲取失敗: ${errorPlates.join(', ')}";
      }

      setState(() {
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

  void _prepareMapData() {
    final List<Polyline> allPolylines = [];
    final List<Marker> allMarkers = [];
    final List<BusPoint> allPointsForBounds = [];
    final colorCycler = ColorCycler();

    _segmentsByPlate.forEach((plate, segments) {
      if (segments.isEmpty) return;
      final allPointsForThisPlate = segments.expand((s) => s.points).toList();
      allPointsForBounds.addAll(allPointsForThisPlate);
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final segmentColor = colorCycler.nextColor;

        allPolylines.add(Polyline(
          points: segment.points.map((p) => LatLng(p.lat, p.lon)).toList(),
          color: segmentColor,
          strokeWidth: 4.5,
          borderStrokeWidth: 1.5,
          borderColor: Colors.black.withOpacity(0.4),
        ));

        if (i < segments.length - 1) {
          final nextSegment = segments[i + 1];
          if (segment.points.isNotEmpty && nextSegment.points.isNotEmpty) {
            final lastPointOfCurrent = segment.points.last;
            final firstPointOfNext = nextSegment.points.first;
            allPolylines.add(Polyline(
              points: [
                LatLng(lastPointOfCurrent.lat, lastPointOfCurrent.lon),
                LatLng(firstPointOfNext.lat, firstPointOfNext.lon),
              ],
              color: segmentColor,
              strokeWidth: 4.5,
              borderStrokeWidth: 1.5,
              borderColor: Colors.black.withOpacity(0.4),
            ));
          }
        }
      }

      final allPoints = segments.expand((s) => s.points).toList();
      for (final point in allPoints) {
        final parentSegment =
            segments.firstWhere((s) => s.points.contains(point));
        final segmentIndex = segments.indexOf(parentSegment);
        final color = MapUtils.segmentColors[
            (colorCycler.index - segments.length + segmentIndex) %
                MapUtils.segmentColors.length];
        allMarkers.add(_createTrackPointMarker(point, color, plate));
      }

      if (allPointsForThisPlate.isNotEmpty) {
        allMarkers.add(_createStartEndMarker(allPointsForThisPlate.first, plate,
            isStart: true));
        allMarkers.add(_createStartEndMarker(allPointsForThisPlate.last, plate,
            isStart: false));
      }
    });

    setState(() {
      _polylines = allPolylines;
      _markers = allMarkers;
      _allPoints = allPointsForBounds;
      if (allPointsForBounds.isNotEmpty) {
        _bounds = LatLngBounds.fromPoints(
            allPointsForBounds.map((p) => LatLng(p.lat, p.lon)).toList());
      } else {
        _bounds = null;
      }
    });
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
    final Color iconColor =
        isStart ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;

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
              size: 32.0,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 5)],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseMapView(
      key: _baseMapStateKey,
      appBarTitle: widget.title,
      points: _allPoints,
      polylines: _polylines,
      markers: _markers,
      bounds: _bounds,
      isLoading: _isLoading,
      error: _error,
      onErrorDismiss: () => setState(() => _error = null),
    );
  }
}
