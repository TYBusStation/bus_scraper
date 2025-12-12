import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../data/car.dart';
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
      return AlertDialog(
        title: Text('車輛操作: $carPlate'),
        contentPadding: const EdgeInsets.only(top: 8.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              dense: true,
              leading: const Icon(Icons.directions_bus_rounded),
              title: const Text('即時動態'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LiveOsmPage(plate: carPlate)),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.history_rounded),
              title: const Text('行駛記錄'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HistoryPage(plate: carPlate)),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.timeline_rounded),
              title: const Text('最後軌跡'),
              onTap: () async {
                Navigator.pop(ctx);

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

                  if (updatedCars.isEmpty) {
                    if (context.mounted) Navigator.of(context).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('找不到此車輛的最新狀態。')),
                      );
                    }
                    return;
                  }
                  final Car updatedCar = updatedCars.first;

                  final index = Static.carData
                      .indexWhere((c) => c.plate == updatedCar.plate);
                  if (index != -1) {
                    Static.carData[index] = updatedCar;
                  }

                  final DateTime endTime = updatedCar.lastSeen;
                  final DateTime startTime = endTime.subtract(
                      Duration(minutes: Static.localStorage.liveTrackDuration));
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('找不到此車輛最近的軌跡資料。')),
                        );
                      }
                    }
                  }
                } on DioException catch (e) {
                  if (context.mounted) Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('獲取軌跡失敗: ${e.message}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('發生未知錯誤: $e')),
                    );
                  }
                }
              },
            ),
            const Divider(height: 1),
            if (Static.city.hasDriverInfo)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_search_rounded),
                title: const Text('查詢駕駛長'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverSearchPage(plate: carPlate),
                    ),
                  );
                },
              ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.route_rounded),
              title: const Text('查詢路線'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteSearchPage(plate: carPlate),
                  ),
                );
              },
            ),
          ],
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
