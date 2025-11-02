import 'package:flutter/material.dart';

import '../data/car.dart';
import '../pages/driver_search_page.dart';
import '../pages/history_page.dart';
import '../pages/live_osm_page.dart';
import '../pages/route_search_page.dart';
import '../static.dart';
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
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_search_rounded),
                title: const Text('查詢駕駛長'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverSearchPage(plate: car.plate),
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
                          "最後上線：${Static.displayTimeFormat.format(car.lastSeen)}",
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
