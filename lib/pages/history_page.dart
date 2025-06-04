import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/bus_point.dart';
import '../static.dart';

class HistoryPage extends StatefulWidget {
  final String plate;

  const HistoryPage({super.key, required this.plate});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = false; // 初始不加載，等待用戶操作
  List<BusPoint> _historyData = [];
  String? _error;
  String? _message; // 用於顯示一般信息，如 "請選擇時間" 或 "無數據"

  // 默認時間範圍：開始時間為1小時前，結束時間為現在
  DateTime _selectedStartTime =
      DateTime.now().subtract(const Duration(hours: 1));
  DateTime _selectedEndTime = DateTime.now();

  // 用於在按鈕上顯示的日期時間格式

  @override
  void initState() {
    super.initState();
    // 初始提示用戶選擇時間並查詢
    _message = "請選擇時間範圍後點擊查詢。";
    // 如果你想在頁面加載時就用默認時間查詢一次，可以取消下面這行的註釋
    // WidgetsBinding.instance.addPostFrameCallback((_) => _fetchHistory());
  }

  Future<void> _pickDateTime(BuildContext context, bool isStartTime) async {
    final DateTime initialDate =
        isStartTime ? _selectedStartTime : _selectedEndTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 6, 1),
      // 調整為合理的最小日期
      lastDate: DateTime.now().add(const Duration(days: 1)),
      // 允許選擇到明天，防止時區問題
      helpText: isStartTime ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate != null) {
      // ignore: use_build_context_synchronously
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: isStartTime ? '選擇開始時間' : '選擇結束時間',
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStartTime) {
            _selectedStartTime = newDateTime;
            // 確保開始時間不晚於結束時間
            if (_selectedStartTime.isAfter(_selectedEndTime)) {
              _selectedEndTime =
                  _selectedStartTime.add(const Duration(minutes: 1)); // 或其他調整邏輯
            }
          } else {
            _selectedEndTime = newDateTime;
            // 確保結束時間不早於開始時間
            if (_selectedEndTime.isBefore(_selectedStartTime)) {
              _selectedStartTime = _selectedEndTime
                  .subtract(const Duration(minutes: 1)); // 或其他調整邏輯
            }
          }
          _message = "時間已更新，請點擊查詢。"; // 更新提示
          _historyData = []; // 清空舊數據，等待重新查詢
          _error = null;
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    if (_selectedStartTime.isAfter(_selectedEndTime)) {
      setState(() {
        _error = "錯誤：開始時間不能晚於結束時間。";
        _message = null;
        _historyData = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
      _historyData = []; // 清空上一次的結果
    });

    try {
      final String formattedStartTime =
          Static.dateFormat.format(_selectedStartTime); // API 通常期望 UTC
      final String formattedEndTime =
          Static.dateFormat.format(_selectedEndTime); // API 通常期望 UTC

      final url = Uri.parse(
          "${Static.apiBaseUrl}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      debugPrint("Fetching URL: $url"); // 用於調試

      final response = await Static.dio.getUri(url);

      if (!mounted) return; // 如果 widget 在請求完成前被 dispose，則不繼續

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;
        if (decodedData.isEmpty) {
          setState(() {
            _message = "找不到公車車牌號碼 ${widget.plate} 在指定時間範圍內的資料。";
            _isLoading = false;
          });
        } else {
          setState(() {
            _historyData =
                decodedData.map((item) => BusPoint.fromJson(item)).toList();
            _isLoading = false;
          });
        }
      } else {
        debugPrint("API Error: ${response.statusCode} - ${response.data}");
        setState(() {
          _error =
              "無法獲取歷史數據 (狀態碼: ${response.statusCode})。詳情: ${response.data.length > 100 ? response.data.substring(0, 100) + '...' : response.data}";
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      // 特別捕捉 DioException
      if (!mounted) return;
      _isLoading = false; // 無論如何，請求結束了

      if (e.response != null) {
        // 如果 DioException 包含 response，表示伺服器有回應
        if (e.response!.statusCode == 404) {
          setState(() {
            _error = "找不到公車車牌號碼 ${widget.plate} 在指定時間範圍內的資料，或該車牌的資料表不存在。";
          });
        } else {
          // 處理其他 HTTP 錯誤 (例如 500, 401, 403 等)
          debugPrint(
              "API Error (DioException): ${e.response!.statusCode} - ${e.response!.data}");
          String errorDetail = e.response!.data.toString();
          if (errorDetail.length > 200)
            errorDetail = "${errorDetail.substring(0, 200)}...";
          setState(() {
            _error =
                "無法獲取歷史數據 (狀態碼: ${e.response!.statusCode})。詳情: $errorDetail";
          });
        }
      } else {
        // DioException 沒有 response，可能是網路問題、超時等
        debugPrint("DioException without response: $e");
        setState(() {
          _error = "網路請求錯誤: ${e.message}";
        });
      }
    } catch (e, s) {
      debugPrint("Exception during fetch: $e\n$s");
      if (!mounted) return;
      setState(() {
        _error = "獲取數據時發生錯誤: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 歷史位置'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                            '起: ${Static.displayDateFormatNoSec.format(_selectedStartTime)}'),
                        onPressed: () => _pickDateTime(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                            '迄: ${Static.displayDateFormatNoSec.format(_selectedEndTime)}'),
                        onPressed: () => _pickDateTime(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('查詢歷史軌跡'),
                  onPressed: _isLoading ? null : _fetchHistory,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    if (_message != null && _historyData.isEmpty) {
      // 只有在沒有數據且有 message 時顯示 message
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
    }

    if (_historyData.isEmpty) {
      // 如果沒有 _message 且數據為空，可以顯示一個通用無數據提示，但前面 _message 處理了大部分情況
      // return const Center(child: Text('沒有歷史數據可顯示。'));
      // 通常此情況會被 _message 覆蓋
      return const SizedBox.shrink(); // 不顯示任何東西，因為 _message 已經處理
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _historyData.length,
      itemBuilder: (context, index) {
        final dataPoint = _historyData[index];
        final routeStr = Static.routeData
            .where((route) => route.id == dataPoint.routeId)
            .first
            .name;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
          child: ListTile(
            title: Text('時間: ${dataPoint.dataTime}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '座標: ${dataPoint.lon.toStringAsFixed(6)}, ${dataPoint.lat.toStringAsFixed(6)}'),
                Text(
                    '狀態: ${dataPoint.dutyStatus == 0 ? "營運" : "非營運"} | 路線: $routeStr | 方向: ${dataPoint.goBack == 0 ? "去程" : "返程"}'),
              ],
            ),
            trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                runAlignment: WrapAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.map_sharp, color: Colors.blueAccent),
                    tooltip: '在 Google Map 上查看',
                    onPressed: () async => await launchUrl(Uri.parse(
                        "https://www.google.com/maps?q=${dataPoint.lat},${dataPoint.lon}(${widget.plate} | $routeStr)")),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map_outlined,
                        color: Colors.blueAccent),
                    tooltip: '在其他地圖上查看',
                    onPressed: () async => await launchUrl(Uri.parse(
                        "geo:${dataPoint.lat},${dataPoint.lon}?q=${dataPoint.lat},${dataPoint.lon}(${widget.plate} | $routeStr)")),
                  )
                ]),
            isThreeLine: true,
            // 調整為 false 如果內容不夠三行
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          ),
        );
      },
    );
  }
}
