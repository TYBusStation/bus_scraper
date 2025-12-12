import 'package:bus_scraper/widgets/car_action_btn.dart';
import 'package:flutter/material.dart';

import '../data/car.dart';
import '../pages/history_page.dart';
import '../utils/formatter_utils.dart';
import 'favorite_button.dart';

class CarListItem extends StatelessWidget {
  const CarListItem({
    super.key,
    required this.car,
    this.drivingDates,
    this.driverId,
    this.routeId,
    this.margin,
  });

  final Car car;
  final List<String>? drivingDates;
  final String? driverId;
  final String? routeId;
  final EdgeInsetsGeometry? margin;

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
                  CarActionBtn(carPlate: car.plate),
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
