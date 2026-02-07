import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:bus_scraper/widgets/car_action_btn.dart';
import 'package:bus_scraper/widgets/favorite_button.dart';
import 'package:flutter/material.dart';

import '../data/bus_route.dart';
import '../utils/api_utils.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/ui_utils.dart';

class RouteTimetablePage extends StatefulWidget {
  final BusRoute route;

  const RouteTimetablePage({super.key, required this.route});

  @override
  State<RouteTimetablePage> createState() => _RouteTimetablePageState();
}

class _RouteTimetablePageState extends State<RouteTimetablePage> {
  late DateTime _selectedDate;
  bool _isLoading = false;

  List<Map<String, dynamic>> _outboundList = [];
  List<Map<String, dynamic>> _inboundList = [];

  bool get _isFutureDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (!selected.isAfter(today)) return false;
    if (selected.difference(today).inDays == 1 && now.hour >= 18) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    final int? routeIdInt = int.tryParse(widget.route.id);
    if (routeIdInt == null) return;

    setState(() {
      _isLoading = true;
      _outboundList = [];
      _inboundList = [];
    });

    try {
      final dateStr = FormatterUtils.apiDateFormat.format(_selectedDate);
      final data = await ApiUtils.fetchTaichungDailyTimeTable(
        routeId: routeIdInt,
        date: dateStr,
      );

      final tempOutbound = <Map<String, dynamic>>[];
      final tempInbound = <Map<String, dynamic>>[];

      for (var item in data) {
        final goBack = item['goBack']?.toString() ?? '1';

        if (goBack == '1') {
          tempOutbound.add(item);
        } else {
          tempInbound.add(item);
        }
      }

      int sortTime(Map<String, dynamic> a, Map<String, dynamic> b) {
        final timeA = a['scheduleTime'] as String? ?? '';
        final timeB = b['scheduleTime'] as String? ?? '';
        return timeA.compareTo(timeB);
      }

      tempOutbound.sort(sortTime);
      tempInbound.sort(sortTime);

      if (mounted) {
        setState(() {
          _outboundList = tempOutbound;
          _inboundList = tempInbound;
        });
      }
    } catch (e) {
      debugPrint("Error fetching timetable: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectDate() {
    UiUtils.selectDate(
      context: context,
      initialDate: _selectedDate,
      onDateSelected: (newDate) {
        if (newDate.year != _selectedDate.year ||
            newDate.month != _selectedDate.month ||
            newDate.day != _selectedDate.day) {
          setState(() {
            _selectedDate = newDate;
          });
          _fetchTimetable();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.route.name} 時刻表'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderInfo(context),
                  _buildDateSelector(context),
                  if (_isFutureDate)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '未來時刻表在前一日 18:00 前查詢通常不具參考價值。',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _buildTimetableContent(context),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.route.name,
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
                    widget.route.departure,
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
                    widget.route.destination,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (widget.route.description.isNotEmpty)
              Text(
                widget.route.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            Text(
              '編號：${widget.route.id}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "查詢日期",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          FormatterUtils.displayDateFormat
                              .format(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableContent(BuildContext context) {
    if (_outboundList.isEmpty && _inboundList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40.0),
        child: EmptyStateIndicator(
          icon: Icons.schedule_outlined,
          title: "尚無發車資訊",
          subtitle: "該日期可能無班次行駛，或無法取得資料。",
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 600;
        final double itemWidth =
            isWide ? constraints.maxWidth / 2 : constraints.maxWidth;

        return Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            if (_outboundList.isNotEmpty)
              SizedBox(
                width: itemWidth,
                child: _buildDirectionSection(
                  context,
                  title: '往 ${widget.route.destination}',
                  list: _outboundList,
                  isOutbound: true,
                ),
              ),
            if (_inboundList.isNotEmpty)
              SizedBox(
                width: itemWidth,
                child: _buildDirectionSection(
                  context,
                  title: '往 ${widget.route.departure}',
                  list: _inboundList,
                  isOutbound: false,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDirectionSection(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> list,
    required bool isOutbound,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color headerColor = isOutbound
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;
    final Color onHeaderColor = isOutbound
        ? colorScheme.onPrimaryContainer
        : colorScheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        isOutbound ? colorScheme.primary : colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  final time = item['scheduleTime'] as String? ?? '--:--';
                  final carPlate = item['carId'] as String? ?? '';
                  final displayTime =
                      time.length > 5 ? time.substring(0, 5) : time;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: headerColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayTime,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: onHeaderColor,
                          ),
                        ),
                      ),
                      title: Text(
                        carPlate.isNotEmpty ? carPlate : '排定班次',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FavoriteButton(plate: carPlate),
                          CarActionBtn(carPlate: carPlate),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
