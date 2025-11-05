import 'bus_point.dart';

class TrajectorySegment {
  final List<BusPoint> points;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String routeId;
  final int goBack;
  final int dutyStatus;
  final String driverId;

  TrajectorySegment({required this.points})
      : startTime = points.first.dataTime,
        endTime = points.last.dataTime,
        duration = points.last.dataTime.difference(points.first.dataTime),
        routeId = points.first.routeId,
        goBack = points.first.goBack,
        dutyStatus = points.first.dutyStatus,
        driverId = points.first.driverId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrajectorySegment &&
          runtimeType == other.runtimeType &&
          startTime == other.startTime &&
          routeId == other.routeId &&
          driverId == other.driverId;

  @override
  int get hashCode => startTime.hashCode ^ routeId.hashCode ^ driverId.hashCode;
}
