import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../data/car.dart';
import '../pages/car_timetable_page.dart';
import '../pages/driver_search_page.dart';
import '../pages/history_osm_page.dart';
import '../pages/history_page.dart';
import '../pages/live_osm_page.dart';
import '../pages/route_search_page.dart';
import '../utils/api_utils.dart';
import '../utils/formatter_utils.dart';
import '../utils/map_utils.dart';
import '../utils/static.dart';

void _showActionsDialog(BuildContext context, String carPlate) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      final compactDensity = const VisualDensity(horizontal: -4, vertical: -4);
      const edgePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.directions_bus, size: 20),
            const SizedBox(width: 8),
            Text('車輛操作: $carPlate', style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildCompactListTile(
                ctx,
                icon: Icons.directions_bus_rounded,
                title: '即時動態',
                density: compactDensity,
                padding: edgePadding,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LiveOsmPage(plate: carPlate)),
                ),
              ),
              _buildCompactListTile(
                ctx,
                icon: Icons.history_rounded,
                title: '歷史軌跡',
                density: compactDensity,
                padding: edgePadding,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HistoryPage(plate: carPlate)),
                ),
              ),
              _buildCompactListTile(
                ctx,
                icon: Icons.timeline_rounded,
                title: '最後軌跡',
                density: compactDensity,
                padding: edgePadding,
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return const Center(child: CircularProgressIndicator());
                    },
                  );

                  try {
                    final List<Car> updatedCars =
                        await ApiUtils.fetchCarsByPlates([carPlate]);

                    if (updatedCars.isEmpty ||
                        updatedCars.first.lastSeen == null) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        FormatterUtils.showSnackbar(context, '本車從未上線。');
                      }
                      return;
                    }
                    final Car updatedCar = updatedCars.first;

                    final index = Static.carData
                        .indexWhere((c) => c.plate == updatedCar.plate);
                    if (index != -1) {
                      Static.carData[index] = updatedCar;
                    }

                    final DateTime endTime = updatedCar.lastSeen!;
                    final DateTime startTime = endTime.subtract(Duration(
                        minutes: Static.localStorage.liveTrackDuration));
                    final String formattedStartTime =
                        FormatterUtils.apiTimeFormat.format(startTime);
                    final String formattedEndTime =
                        FormatterUtils.apiTimeFormat.format(endTime);

                    final url = Uri.parse(
                        "${Static.apiBaseUrl}/${Static.city.code}/bus_data/$carPlate?start_time=$formattedStartTime&end_time=$formattedEndTime");

                    final response = await Static.dio.getUri(url);

                    if (context.mounted) Navigator.of(context).pop();

                    if (response.statusCode == 200 && response.data != null) {
                      final List<dynamic> decodedData = response.data;
                      if (decodedData.isNotEmpty) {
                        final points = decodedData
                            .map((item) => BusPoint.fromJson(item))
                            .toList();
                        final segments =
                            MapUtils.processPointsIntoSegments(points);

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryOsmPage(
                                plate: carPlate,
                                segments: segments,
                                isFiltered: false,
                              ),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted)
                          FormatterUtils.showSnackbar(
                              context, '找不到此車輛最近的軌跡資料。');
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      FormatterUtils.showSnackbar(context,
                          '載入失敗: ${FormatterUtils.getErrorMessage(e)}');
                    }
                  }
                },
              ),
              const Divider(height: 1, thickness: 0.5),
              if (Static.city.code == 'taichung')
                _buildCompactListTile(
                  ctx,
                  icon: Icons.calendar_today_rounded,
                  title: '查詢班表',
                  density: compactDensity,
                  padding: edgePadding,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            CarTimetablePage(plate: carPlate)),
                  ),
                ),
              if (Static.city.hasDriverInfo)
                _buildCompactListTile(
                  ctx,
                  icon: Icons.person_search_rounded,
                  title: '查詢駕駛長',
                  density: compactDensity,
                  padding: edgePadding,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            DriverSearchPage(plate: carPlate)),
                  ),
                ),
              _buildCompactListTile(
                ctx,
                icon: Icons.route_rounded,
                title: '查詢路線',
                density: compactDensity,
                padding: edgePadding,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RouteSearchPage(plate: carPlate)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

Widget _buildCompactListTile(
  BuildContext dialogCtx, {
  required IconData icon,
  required String title,
  required VisualDensity density,
  required EdgeInsets padding,
  required VoidCallback onTap,
}) {
  return ListTile(
    dense: true,
    visualDensity: density,
    contentPadding: padding,
    leading: Icon(icon, size: 20),
    minLeadingWidth: 24,
    title: Text(title, style: const TextStyle(fontSize: 14)),
    onTap: () {
      Navigator.pop(dialogCtx);
      onTap();
    },
  );
}

class CarActionBtn extends StatelessWidget {
  final String carPlate;

  const CarActionBtn({super.key, required this.carPlate});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _showActionsDialog(context, carPlate),
      icon: const Icon(Icons.more_horiz_rounded, size: 16),
      label: const Text('操作'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class CarActionBtnMini extends StatelessWidget {
  final String carPlate;

  const CarActionBtnMini({super.key, required this.carPlate});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showActionsDialog(context, carPlate),
      child: const Icon(Icons.more_horiz_rounded, size: 16),
    );
  }
}
