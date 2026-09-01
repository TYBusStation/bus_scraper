import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_route.dart';
import '../storage/city.dart';
import '../utils/api_utils.dart';
import '../utils/formatter_utils.dart';
import '../utils/static.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/ui_utils.dart';
import 'route_timetable_page.dart';
import 'route_vehicles_page.dart';

class CarTimetablePage extends StatefulWidget {
  final String plate;

  const CarTimetablePage({super.key, required this.plate});

  @override
  State<CarTimetablePage> createState() => _CarTimetablePageState();
}

class _CarTimetablePageState extends State<CarTimetablePage> {
  late DateTime _selectedDate;
  bool _isLoading = false;
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = FormatterUtils.apiDateFormat.format(_selectedDate);
      final data = await ApiUtils.fetchCarTimetable(
        plate: widget.plate,
        date: dateStr,
      );

      if (mounted) {
        setState(() {
          _trips = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSelectDate() {
    UiUtils.selectDate(
      context: context,
      initialDate: _selectedDate,
      firstDate:
          DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 1))),
      lastDate: DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1))),
      onDateSelected: (newDate) {
        if (newDate.year != _selectedDate.year ||
            newDate.month != _selectedDate.month ||
            newDate.day != _selectedDate.day) {
          setState(() {
            _selectedDate = newDate;
          });
          _fetchData();
        }
      },
    );
  }

  void _onDynamicWebsitePressed(BuildContext context, BusRoute route) async {
    if (Static.city == City.taipei) {
      final nid = route.nid;
      final pnid = route.pnid;
      final bool hasNid = nid != null && nid.isNotEmpty;
      final bool hasPnid = pnid != null && pnid.isNotEmpty;
      final bool areDifferent = hasNid && hasPnid && nid != pnid;

      if (areDifferent) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('選擇要開啟的路線網頁'),
            actions: [
              TextButton(
                  onPressed: () => _launchTaipeiUrl(nid),
                  child: Text("子路線 ($nid)")),
              TextButton(
                  onPressed: () => _launchTaipeiUrl(pnid),
                  child: Text('主路線 ($pnid)')),
            ],
          ),
        );
      } else if (hasNid) {
        _launchTaipeiUrl(nid);
      } else if (hasPnid) {
        _launchTaipeiUrl(pnid);
      }
    } else {
      final url = Uri.parse(Static.city != City.taichung
          ? "${Static.city.url}/ebus/driving-map/${route.id}"
          : "https://tybusstation.github.io/taichung_bus/");
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  void _launchTaipeiUrl(String routeId) async {
    final url = Uri.parse(
        'https://ebus.gov.taipei/Route/StopsOfRoute?routeid=$routeId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 班表'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDateHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trips.isEmpty
                    ? const EmptyStateIndicator(
                        icon: Icons.event_busy_rounded,
                        title: "查無排班資訊",
                        subtitle: "該日期此車輛可能無分配班次。",
                      )
                    : _buildTripList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _onSelectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              FormatterUtils.displayDateFormat.format(_selectedDate),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTripList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        final trip = _trips[index];
        final String routeId = trip['route'].toString();
        final String time = trip['time'] ?? '--:--';
        final int dir = trip['dir'] ?? 1;
        final route = ApiUtils.getRouteByIdSync(routeId);
        final String destinationText =
            dir == 1 ? route.destination : route.departure;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(
                route.name,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("往 $destinationText",
                  style: const TextStyle(fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        route.name,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.departure_board,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              route.departure,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.0),
                            child: Icon(Icons.arrow_forward, size: 16),
                          ),
                          const Icon(Icons.flag, size: 18, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              route.destination,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        route.description,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      Text(
                        '編號：${route.id}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _onDynamicWebsitePressed(context, route),
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('公車動態網'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: theme.textTheme.labelMedium,
                            ),
                          ),
                          if (Static.city == City.taichung) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            RouteTimetablePage(route: route)));
                              },
                              icon: const Icon(Icons.calendar_month_outlined,
                                  size: 16),
                              label: const Text('時刻表'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                textStyle: theme.textTheme.labelMedium,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          RouteVehiclesPage(route: route)));
                            },
                            icon: const Icon(
                                Icons.directions_bus_filled_outlined,
                                size: 16),
                            label: const Text('查詢車輛'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: theme.textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
