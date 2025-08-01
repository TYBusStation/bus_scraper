// lib/pages/car_search_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/vehicle_history.dart';
import '../static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';

/// 一個專門的頁面，用於顯示特定駕駛員在特定日期區間內駕駛過的車輛。
class CarSearchPage extends StatefulWidget {
  final String initialDriverId;
  final DateTime initialStartTime;
  final DateTime initialEndTime;

  const CarSearchPage({
    super.key,
    required this.initialDriverId,
    required this.initialStartTime,
    required this.initialEndTime,
  });

  @override
  State<CarSearchPage> createState() => _CarSearchPageState();
}

class _CarSearchPageState extends State<CarSearchPage> {
  late Future<List<PlateDrivingDates>> _searchFuture;
  final _displayFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    // 頁面初始化時，立即使用傳入的參數執行查詢
    _searchFuture = Static.findDriverDrivingDates(
      driverId: widget.initialDriverId,
      startDate: widget.initialStartTime,
      endDate: widget.initialEndTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 建立一個描述性的 AppBar 副標題
    final String subtitle =
        '駕駛: ${widget.initialDriverId} | 日期: ${_displayFormat.format(widget.initialStartTime)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('駕駛車輛查詢結果'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child:
                Text(subtitle, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      ),
      body: FutureBuilder<List<PlateDrivingDates>>(
        future: _searchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyStateIndicator(
              icon: Icons.error_outline_rounded,
              title: '查詢失敗',
              subtitle: snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EmptyStateIndicator(
              icon: Icons.no_transfer_rounded,
              title: '查無資料',
              subtitle: '該駕駛在此日期沒有任何駕駛記錄',
            );
          }

          final records = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              // 根據車牌號碼從 Static.carData 中查找完整的車輛資訊
              // 這樣可以獲取到車輛類型等詳細資料
              final car = Static.carData.firstWhere(
                (c) => c.plate == record.plate,
              );

              // 使用通用的 CarListItem 來顯示結果
              return CarListItem(
                car: car,
                showLiveButton: true, // 在結果頁面總是顯示「即時動態」按鈕
                // 傳入日期，這樣 CarListItem 會顯示對應的日期標籤
                drivingDates: record.dates,
                // 傳入駕駛員 ID，以保持上下文的完整性
                driverId: widget.initialDriverId,
              );
            },
          );
        },
      ),
    );
  }
}
