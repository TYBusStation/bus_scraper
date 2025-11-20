import 'package:bus_scraper/utils/api_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/bus_point.dart';
import '../data/car.dart';
import '../pages/driver_search_page.dart';
import '../pages/history_osm_page.dart';
import '../pages/history_page.dart';
import '../pages/live_osm_page.dart';
import '../pages/route_search_page.dart';
import '../utils/formatter_utils.dart';
import '../utils/map_utils.dart';
import '../utils/static.dart';
import 'favorite_button.dart';

class CarListItem extends StatelessWidget {
  const CarListItem({
    super.key,
    required this.car,
    required this.showLiveButton,
    this.drivingDates,
    this.driverId,
    this.routeId,
    this.margin,
  });

  final Car car;
  final bool showLiveButton;
  final List<String>? drivingDates;
  final String? driverId;
  final String? routeId;
  final EdgeInsetsGeometry? margin;

  void _showActionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('車輛操作: ${car.plate}'),
          contentPadding: const EdgeInsets.only(top: 8.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showLiveButton)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.directions_bus_rounded),
                  title: const Text('即時動態'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LiveOsmPage(plate: car.plate)),
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
                        builder: (context) => HistoryPage(plate: car.plate)),
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
                        await ApiUtils.fetchCarsByPlates([car.plate]);

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
                    final DateTime startTime = endTime.subtract(Duration(
                        minutes: Static.localStorage.liveTrackDuration));
                    final String formattedStartTime =
                        FormatterUtils.apiTimeFormat.format(startTime);
                    final String formattedEndTime =
                        FormatterUtils.apiTimeFormat.format(endTime);

                    final url = Uri.parse(
                        "${Static.apiBaseUrl}/${Static.city.code}/bus_data/${car.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

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
                                plate: car.plate,
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
                        builder: (context) =>
                            DriverSearchPage(plate: car.plate),
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
                      builder: (context) => RouteSearchPage(plate: car.plate),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bool hasDates = drivingDates != null && drivingDates!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FavoriteButton(
                    plate: car.plate,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.plate,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          car.typeDisplayName,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "最後上線：${FormatterUtils.displayTimeFormat.format(car.lastSeen)}",
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showActionsDialog(context),
                    icon: const Icon(Icons.more_horiz_rounded, size: 16),
                    label: const Text('操作'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              if (hasDates) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: drivingDates!
                      .map((date) => ActionChip(
                            label: Text(date),
                            labelStyle: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 12,
                            ),
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            onPressed: () {
                              final selectedDate = DateTime.parse(date);
                              final startTime = DateTime(selectedDate.year,
                                  selectedDate.month, selectedDate.day);
                              final endTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              ).add(const Duration(days: 1));
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryPage(
                                    plate: car.plate,
                                    initialStartTime: startTime,
                                    initialEndTime: endTime,
                                    initialDriverId: driverId,
                                    initialRouteId: routeId,
                                  ),
                                ),
                              );
                            },
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
