import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car.dart';
import '../utils/api_utils.dart';
import '../utils/static.dart';
import '../widgets/car_list_item.dart';
import '../widgets/empty_state_indicator.dart';
import '../widgets/searchable_list.dart';

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  bool _isRefreshing = false;

  /// 執行重整邏輯，重新抓取 API 資料並更新介面
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      Static.log("開始手動更新車輛列表與最後上線時間...");
      // 重新從伺服器獲取最新的車輛資料
      final newData = await ApiUtils.fetchCarData();

      if (newData.isNotEmpty) {
        setState(() {
          // 更新全域靜態資料
          Static.carData = newData;
        });
        if (mounted) {
          FormatterUtils.showSnackbar(context, "車輛資料已更新");
        }
      }
    } catch (e) {
      if (mounted) {
        FormatterUtils.showSnackbar(context, "更新車輛資料時發生錯誤: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 Scaffold 以放置 FloatingActionButton
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Consumer<FavoritesNotifier>(
          builder: (context, notifier, child) {
            // 直接顯示列表，不使用 RefreshIndicator
            return SearchableList<Car>(
              allItems: Static.carData,
              searchHintText: "搜尋車牌（支援 Regex）",
              filterCondition: (item, text) {
                final String plate = item.plate;
                final tokens =
                    text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

                return tokens.every((token) {
                  try {
                    return RegExp(token, caseSensitive: false).hasMatch(plate);
                  } catch (e) {
                    return plate.toUpperCase().contains(token.toUpperCase());
                  }
                });
              },
              sortCallback: (a, b) => a.plate.compareTo(b.plate),
              itemBuilder: (context, car) {
                return CarListItem(car: car);
              },
              emptyStateWidget: const EmptyStateIndicator(
                icon: Icons.search_off_rounded,
                title: "找不到符合的車牌",
                subtitle: "請檢查輸入，或該車牌尚未被記錄。",
              ),
            );
          },
        ),
      ),
      // 重整按鈕
      floatingActionButton: FloatingActionButton(
        onPressed: _isRefreshing ? null : _handleRefresh,
        tooltip: "更新車輛資料",
        child: _isRefreshing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }
}
