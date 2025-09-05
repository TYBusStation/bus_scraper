// lib/widgets/driving_record_list.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/car.dart';
import '../static.dart';
import 'car_list_item.dart';
import 'empty_state_indicator.dart';
import 'searchable_list.dart';

class DrivingRecord {
  final Car car;
  final List<String> dates;

  DrivingRecord({required this.car, required this.dates});
}

enum QueryType { byDriver, byRoute }

class DrivingRecordList extends StatefulWidget {
  final QueryType queryType;
  final String queryValue;
  final DateTime startDate;
  final DateTime endDate;
  final String? driverIdForListItem;

  const DrivingRecordList({
    super.key,
    required this.queryType,
    required this.queryValue,
    required this.startDate,
    required this.endDate,
    this.driverIdForListItem,
  });

  @override
  State<DrivingRecordList> createState() => _DrivingRecordListState();
}

class _DrivingRecordListState extends State<DrivingRecordList> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DrivingRecord> _allRecords = [];

  @override
  void initState() {
    super.initState();
    if (widget.queryValue.isNotEmpty) {
      _fetchDrivingRecords();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(DrivingRecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryValue != oldWidget.queryValue ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      if (widget.queryValue.isNotEmpty) {
        _fetchDrivingRecords();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _allRecords = [];
        });
      }
    }
  }

  Future<void> _fetchDrivingRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _allRecords = [];
    });

    try {
      final String endpoint = widget.queryType == QueryType.byDriver
          ? '/${Static.localStorage.city}/tools/find_driver_dates'
          : '/${Static.localStorage.city}/tools/find_route_vehicles';
      final String paramName =
          widget.queryType == QueryType.byDriver ? 'driver_id' : 'route_id';
      final apiStartTime = DateTime(
          widget.startDate.year, widget.startDate.month, widget.startDate.day);
      final apiEndTime = DateTime(
              widget.endDate.year, widget.endDate.month, widget.endDate.day)
          .add(const Duration(days: 1));
      final queryParameters = {
        paramName: widget.queryValue,
        'start_time': Static.apiDateFormat.format(apiStartTime),
        'end_time': Static.apiDateFormat.format(apiEndTime),
      };
      final response = await Static.dio.get(
        '${Static.apiBaseUrl}$endpoint',
        queryParameters: queryParameters,
      );
      final List<dynamic> responseData = response.data;
      final carMap = {for (var car in Static.carData) car.plate: car};

      if (mounted) {
        setState(() {
          _allRecords = responseData
              .map((item) {
                final String plate = item['plate'];
                final List<String> dates =
                    List<String>.from(item['dates'] ?? []);
                final Car? car = carMap[plate];
                if (car != null && dates.isNotEmpty) {
                  return DrivingRecord(car: car, dates: dates);
                }
                return null;
              })
              .where((record) => record != null)
              .cast<DrivingRecord>()
              .toList();
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        String message;
        if (e.response != null) {
          final errorDetail = e.response?.data['detail'] ?? '伺服器未提供詳細錯誤訊息';
          message = "錯誤 ${e.response?.statusCode}: $errorDetail";
        } else {
          message = "網路或連線錯誤，請檢查您的網路連線。";
        }
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "發生未預期的錯誤: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.queryValue.isEmpty && widget.queryType == QueryType.byDriver) {
      return const EmptyStateIndicator(
        icon: Icons.info_outline,
        title: "請先查詢",
        subtitle: "請輸入駕駛員 ID 後點擊查詢按鈕。",
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return EmptyStateIndicator(
        icon: Icons.error_outline_rounded,
        title: "查詢失敗",
        subtitle: _errorMessage!,
      );
    }
    if (_allRecords.isEmpty) {
      return const EmptyStateIndicator(
        icon: Icons.sentiment_dissatisfied_outlined,
        title: "查無結果",
        subtitle: "找不到符合條件的車輛紀錄。",
      );
    }

    return SearchableList<DrivingRecord>(
      allItems: _allRecords,
      searchHintText: "篩選車牌（如：${Static.getExamplePlate()}）",
      filterCondition: (record, text) =>
          record.car.plate.toUpperCase().contains(text.toUpperCase()),
      sortCallback: (a, b) => a.car.plate.compareTo(b.car.plate),
      itemBuilder: (context, record) {
        return CarListItem(
          car: record.car,
          showLiveButton: true,
          drivingDates: record.dates,
          driverId: widget.driverIdForListItem,
          // 【修改】在這裡傳遞 routeId
          routeId:
              widget.queryType == QueryType.byRoute ? widget.queryValue : null,
        );
      },
      emptyStateWidget: const EmptyStateIndicator(
        icon: Icons.search_off_rounded,
        title: "無篩選結果",
        subtitle: "找不到符合篩選條件的車牌。",
      ),
    );
  }
}
