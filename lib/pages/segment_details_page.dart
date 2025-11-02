import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/TrajectorySegment.dart';
import '../static.dart';
import 'history_osm_page.dart';

class SegmentDetailsPage extends StatelessWidget {
  final String plate;
  final TrajectorySegment segment;

  const SegmentDetailsPage(
      {super.key, required this.plate, required this.segment});

  @override
  Widget build(BuildContext context) {
    final route = Static.getRouteByIdSync(segment.routeId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${route.name} 軌跡段詳情'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        itemCount: segment.points.length,
        itemBuilder: (context, index) {
          final dataPoint = segment.points[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Static.displayTimeFormat.format(dataPoint.dataTime),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            iconSize: 20,
                            icon: const Icon(Icons.explore_outlined),
                            color: Theme.of(context).colorScheme.secondary,
                            tooltip: '在地圖上繪製此點',
                            onPressed: () {
                              final singlePointSegment =
                                  TrajectorySegment(points: [dataPoint]);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryOsmPage(
                                    plate: plate,
                                    segments: [singlePointSegment],
                                    isFiltered: true,
                                    backgroundSegments: null,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            iconSize: 20,
                            icon: const Icon(Icons.map_sharp),
                            color: Colors.blueAccent,
                            tooltip: '在 Google Map 上查看',
                            onPressed: () async => await launchUrl(Uri.parse(
                                "https://www.google.com/maps?q=${dataPoint.lat},${dataPoint.lon}(${Uri.encodeComponent('${route.name} | ${route.description} | 往 ${dataPoint.goBack == 1 ? route.destination : route.departure} | ${dataPoint.dutyStatus == 0 ? "營運" : "非營運"} | 駕駛長：${Static.getDriverText(dataPoint.driverId)} | ${Static.displayTimeFormat.format(dataPoint.dataTime)}')} )")),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 8),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: [
                      _buildInfoChip(
                        context,
                        icon: Icons.route_outlined,
                        label: "${route.name} (${route.id})",
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.description_outlined,
                        label: route.description,
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.swap_horiz,
                        label:
                            "往 ${route.destination.isNotEmpty && route.departure.isNotEmpty ? (dataPoint.goBack == 1 ? route.destination : route.departure) : '未知'}",
                      ),
                      _buildInfoChip(
                        context,
                        icon: dataPoint.dutyStatus == 0
                            ? Icons.work_outline
                            : Icons.work_off_outlined,
                        label: dataPoint.dutyStatus == 0 ? "營運" : "非營運",
                        color: dataPoint.dutyStatus == 0
                            ? Colors.green
                            : Colors.orange,
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.person_pin_circle_outlined,
                        label:
                            "駕駛長：${Static.getDriverText(dataPoint.driverId)}",
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.gps_fixed,
                        label:
                            "${dataPoint.lat.toString()}, ${dataPoint.lon.toString()}",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context,
      {required IconData icon, required String label, Color? color}) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon,
          size: 14, color: color ?? theme.colorScheme.onSurfaceVariant),
      label: Text(label, style: theme.textTheme.labelSmall),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
