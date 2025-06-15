// lib/pages/route_vehicles_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/bus_route.dart';
import '../widgets/driving_record_list.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/theme_provider.dart';

class RouteVehiclesPage extends StatefulWidget {
  final BusRoute route;

  const RouteVehiclesPage({super.key, required this.route});

  @override
  State<RouteVehiclesPage> createState() => _RouteVehiclesPageState();
}

class _RouteVehiclesPageState extends State<RouteVehiclesPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 2));
  DateTime _endDate = DateTime.now();
  final _displayDateFormat = DateFormat('yyyy/MM/dd');

  bool _hasSearched = false;
  Map<String, dynamic> _queryParameters = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDate = pickedDate;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = pickedDate;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
      });
    }
  }

  void _triggerSearch() {
    FocusScope.of(context).unfocus(); // 點擊查詢時收起鍵盤
    setState(() {
      _hasSearched = true;
      _queryParameters = {
        'routeId': widget.route.id,
        'startDate': _startDate,
        'endDate': _endDate,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.route.name} 行駛車輛查詢'),
      ),
      body: ThemeProvider(
        builder: (BuildContext context, ThemeData themeData) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildControlCard(),
              const SizedBox(height: 8),
              Expanded(
                child: _hasSearched
                    ? DrivingRecordList(
                        key: ValueKey(_queryParameters.toString()),
                        queryType: QueryType.byRoute,
                        queryValue: _queryParameters['routeId'],
                        startDate: _queryParameters['startDate'],
                        endDate: _queryParameters['endDate'],
                      )
                    : _buildInitialMessage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDatePicker(
                    label: "起始日期",
                    value: _startDate,
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDatePicker(
                    label: "結束日期",
                    value: _endDate,
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _triggerSearch,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text("查詢"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final displayText = _displayDateFormat.format(value);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_month_outlined, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialMessage() {
    return const EmptyStateIndicator(
      icon: Icons.directions_bus_filled_outlined,
      title: "查詢路線車輛",
      subtitle: "請選擇日期範圍後\n點擊查詢按鈕",
    );
  }
}
