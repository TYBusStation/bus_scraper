// lib/pages/segment_details_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';
import 'history_osm_page.dart';
import 'history_page.dart'; // 為了 TrajectorySegment

class SegmentDetailsPage extends StatelessWidget {
  final String plate;
  final TrajectorySegment segment;

  const SegmentDetailsPage(
      {super.key, required this.plate, required this.segment});

  @override
  Widget build(BuildContext context) {
    final route = Static.routeData.firstWhere((r) => r.id == segment.routeId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${route.name} 軌跡段詳情'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        itemCount: segment.points.length,
        itemBuilder: (context, index) {
          final dataPoint = segment.points[index];
          // 這個 Card 的結構與您舊版的 HistoryPage 列表完全相同
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Static.displayDateFormat.format(dataPoint.dataTime),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.explore_outlined),
                            color: Theme.of(context).colorScheme.secondary,
                            tooltip: '在地圖上繪製此點',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HistoryOsmPage(
                                  plate: plate,
                                  points: [dataPoint],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.map_sharp),
                            color: Colors.blueAccent,
                            tooltip: '在 Google Map 上查看',
                            onPressed: () async => await launchUrl(Uri.parse(
                                "https://www.google.com/maps?q=${dataPoint.lat},${dataPoint.lon}(${route.name} | ${route.description} | 往 ${dataPoint.goBack == 1 ? route.destination : route.departure} | ${dataPoint.dutyStatus == 0 ? "營運" : "非營運"} | 駕駛：${dataPoint.driverId == "0" ? "未知" : dataPoint.driverId} | ${Static.displayDateFormat.format(dataPoint.dataTime)})")),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 6.0,
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
                            "往 ${dataPoint.goBack == 1 ? route.destination : route.departure}",
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
                            "駕駛：${dataPoint.driverId == "0" ? "未知" : dataPoint.driverId}",
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.gps_fixed,
                        label:
                            "${dataPoint.lat.toStringAsFixed(5)}, ${dataPoint.lon.toStringAsFixed(5)}",
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

  // 輔助建立資訊 Chip 的 Widget
  Widget _buildInfoChip(BuildContext context,
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
