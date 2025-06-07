// 導入所需的套件
import 'package:dio/dio.dart'; // 用於發送 HTTP 請求
import 'package:flutter/material.dart'; // Flutter 的 Material Design UI 框架
import 'package:url_launcher/url_launcher.dart'; // 用於在外部應用程式中開啟 URL (例如 Google Maps)

// 導入專案內的檔案
import '../data/bus_point.dart'; // 公車數據點的資料模型
import '../static.dart'; // 存放靜態變數和方法的檔案 (如 API URL, Dio 實例, 日期格式)
import 'history_osm_page.dart'; // 導入顯示歷史軌跡的 OSM 地圖頁面

/// HistoryPage 是一個顯示特定車牌歷史軌跡的 StatefulWidget。
class HistoryPage extends StatefulWidget {
  // 接收從上一頁傳來的車牌號碼
  final String plate;

  const HistoryPage({super.key, required this.plate});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

/// HistoryPage 的狀態管理類別
class _HistoryPageState extends State<HistoryPage> {
  // --- 狀態變數 ---

  bool _isLoading = false; // 標記是否正在從 API 加載數據
  List<BusPoint> _allHistoryData = []; // 儲存從 API 獲取的完整歷史數據
  List<BusPoint> _filteredHistoryData = []; // 儲存經過篩選後，要顯示在列表中的數據
  String? _error; // 如果發生錯誤，儲存錯誤訊息
  String? _message; // 向用戶顯示的提示性訊息 (例如 "請選擇時間")

  // 用戶選擇的查詢時間範圍，預設為過去一小時
  DateTime _selectedStartTime =
      DateTime.now().subtract(const Duration(hours: 1));
  DateTime _selectedEndTime = DateTime.now();

  // 用戶選擇的篩選條件
  String? _selectedRouteId; // 當前篩選的路線 ID，null 表示不篩選

  // 從查詢結果中提取出的可用路線列表，用於填充篩選下拉選單
  List<dynamic> _availableRoutes = [];

  @override
  void initState() {
    super.initState();
    // 頁面初始化時，給予用戶提示
    _message = "請選擇時間範圍後點擊查詢。";
  }

  /// 彈出日期和時間選擇器，讓用戶選擇時間。
  /// [isStartTime] 用於區分是設定開始時間還是結束時間。
  Future<void> _pickDateTime(BuildContext context, bool isStartTime) async {
    final DateTime initialDate =
        isStartTime ? _selectedStartTime : _selectedEndTime;

    // 1. 顯示日期選擇器
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025, 6, 1),
      // 可選的最早日期
      lastDate: DateTime.now().add(const Duration(days: 1)),
      // 可選的最晚日期
      helpText: isStartTime ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate != null) {
      // 2. 如果選擇了日期，接著顯示時間選擇器
      final TimeOfDay? pickedTime = await showTimePicker(
        // ignore: use_build_context_synchronously
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        helpText: isStartTime ? '選擇開始時間' : '選擇結束時間',
      );

      if (pickedTime != null) {
        // 3. 組合日期和時間，並更新狀態
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
            // 自動校正：如果開始時間晚於結束時間，則將結束時間設為開始時間後一分鐘
            if (_selectedStartTime.isAfter(_selectedEndTime)) {
              _selectedEndTime =
                  _selectedStartTime.add(const Duration(minutes: 1));
            }
          } else {
            _selectedEndTime = newDateTime;
            // 自動校正：如果結束時間早于開始時間，則將開始時間設為結束時間前一分鐘
            if (_selectedEndTime.isBefore(_selectedStartTime)) {
              _selectedStartTime =
                  _selectedEndTime.subtract(const Duration(minutes: 1));
            }
          }
          // 更新狀態以提示用戶重新查詢
          _message = "時間已更新，請點擊查詢。";
          _allHistoryData = [];
          _filteredHistoryData = [];
          _resetFilters(); // 重置篩選器
          _error = null;
        });
      }
    }
  }

  /// 根據選擇的時間範圍，從後端 API 獲取歷史數據。
  Future<void> _fetchHistory() async {
    // 驗證時間範圍是否有效
    if (_selectedStartTime.isAfter(_selectedEndTime)) {
      setState(() {
        _error = "錯誤：開始時間不能晚於結束時間。";
        _message = null;
        _allHistoryData = [];
        _filteredHistoryData = [];
        _isLoading = false;
      });
      return;
    }

    // 開始查詢，設置加載狀態
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
      _allHistoryData = [];
      _filteredHistoryData = [];
      _resetFilters();
    });

    try {
      // 將時間格式化為 API 需要的字串格式
      final String formattedStartTime =
          Static.dateFormat.format(_selectedStartTime);
      final String formattedEndTime =
          Static.dateFormat.format(_selectedEndTime);

      // 組合 API 的 URL
      final url = Uri.parse(
          "${Static.apiBaseUrl}/bus_data/${widget.plate}?start_time=$formattedStartTime&end_time=$formattedEndTime");

      debugPrint("正在請求 URL: $url");

      // 使用 Dio 發送 GET 請求
      final response = await Static.dio.getUri(url);

      // 如果請求回來後頁面已經被銷毀，則不進行後續操作
      if (!mounted) return;

      // 處理成功的響應 (HTTP 狀態碼 200)
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> decodedData = response.data;
        if (decodedData.isEmpty) {
          // 如果數據為空，顯示提示訊息
          setState(() {
            _message = "找不到公車車牌號碼 ${widget.plate} 在指定時間範圍內的資料。";
            _isLoading = false;
          });
        } else {
          // 如果有數據，將 JSON 列表轉換為 BusPoint 物件列表
          setState(() {
            _allHistoryData =
                decodedData.map((item) => BusPoint.fromJson(item)).toList();
            _updateAvailableRoutes(); // 更新可用的路線篩選選項
            _applyFilters(); // 應用預設篩選（即顯示全部）
            _isLoading = false;
          });
        }
      } else {
        // 處理其他 HTTP 狀態碼錯誤
        debugPrint("API 錯誤: ${response.statusCode} - ${response.data}");
        setState(() {
          _error =
              "無法獲取歷史數據 (狀態碼: ${response.statusCode})。詳情: ${response.data.length > 100 ? response.data.substring(0, 100) + '...' : response.data}";
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      // 捕獲 Dio 相關的異常 (例如網路問題、超時)
      if (!mounted) return;
      _isLoading = false;

      if (e.response != null) {
        // 如果是 API 回傳的錯誤
        if (e.response!.statusCode == 404) {
          // 專門處理 404 Not Found 錯誤
          setState(() {
            _error = "找不到公車車牌號碼 ${widget.plate} 在指定時間範圍內的資料，或該車牌的資料表不存在。";
          });
        } else {
          debugPrint(
              "API 錯誤 (DioException): ${e.response!.statusCode} - ${e.response!.data}");
          String errorDetail = e.response!.data.toString();
          if (errorDetail.length > 200) {
            errorDetail = "${errorDetail.substring(0, 200)}...";
          }
          setState(() {
            _error =
                "無法獲取歷史數據 (狀態碼: ${e.response!.statusCode})。詳情: $errorDetail";
          });
        }
      } else {
        // 如果是請求本身的問題 (例如無法連接到伺服器)
        debugPrint("沒有響應的 DioException: $e");
        setState(() {
          _error = "網路請求錯誤: ${e.message}";
        });
      }
    } catch (e, s) {
      // 捕獲其他未預料到的異常
      debugPrint("獲取數據時發生異常: $e\n$s");
      if (!mounted) return;
      setState(() {
        _error = "獲取數據時發生錯誤: $e";
        _isLoading = false;
      });
    }
  }

  /// 重置所有篩選條件
  void _resetFilters() {
    setState(() {
      _selectedRouteId = null; // 清空選擇的路線
      _availableRoutes = []; // 清空可用路線列表
    });
  }

  /// 根據獲取的數據，更新篩選下拉選單中可用的路線
  void _updateAvailableRoutes() {
    if (_allHistoryData.isEmpty) {
      _availableRoutes = [];
      return;
    }
    // 提取所有不重複的路線 ID
    final uniqueRouteIds = _allHistoryData.map((p) => p.routeId).toSet();
    // 從靜態路線資料中，找出 ID 匹配的路線物件
    _availableRoutes = Static.routeData
        .where((route) => uniqueRouteIds.contains(route.id))
        .toList();
  }

  /// 根據當前選擇的篩選條件，更新 `_filteredHistoryData` 列表
  void _applyFilters() {
    // 從完整的數據列表開始
    List<BusPoint> temp = List.from(_allHistoryData);

    // 如果選擇了某條路線，則只保留該路線的數據
    if (_selectedRouteId != null) {
      temp = temp.where((p) => p.routeId == _selectedRouteId).toList();
    }

    // 注意：方向篩選功能已在此版本中移除

    // 更新狀態，觸發 UI 重建
    setState(() {
      _filteredHistoryData = temp;
    });
  }

  /// 構建整個頁面的 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.plate} 歷史位置'),
      ),
      body: Column(
        children: [
          _buildControlPanel(), // 上方的控制面板 (日期選擇、查詢按鈕、篩選器)
          const Divider(height: 1), // 分隔線
          Expanded(child: _buildResultsArea()), // 下方的結果顯示區域
        ],
      ),
    );
  }

  /// 構建控制面板 UI
  Widget _buildControlPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 開始和結束時間選擇按鈕
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
          const SizedBox(height: 12),
          // 查詢按鈕
          FilledButton.icon(
            icon: const Icon(Icons.explore_outlined),
            label: const Text('查詢歷史軌跡'),
            onPressed: _isLoading ? null : _fetchHistory, // 加載中時禁用
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          // 只有在查詢到數據後才顯示篩選器和地圖按鈕
          if (_allHistoryData.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFilterBar(), // 路線篩選器
            const SizedBox(height: 12),
            // 在地圖上顯示軌跡的按鈕
            FilledButton.icon(
              icon: const Icon(Icons.map),
              label: Text('在地圖上顯示篩選後的軌跡 (${_filteredHistoryData.length} 筆)'),
              onPressed: _filteredHistoryData.isNotEmpty // 篩選後有數據才可點擊
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryOsmPage(
                            plate: widget.plate,
                            // 將篩選後的數據點列表傳遞給地圖頁面 (反轉列表讓地圖顯示最新的點在最上面)
                            points: _filteredHistoryData.reversed.toList(),
                            routeName: _selectedRouteId != null
                                ? _availableRoutes
                                    .firstWhere((r) => r.id == _selectedRouteId)
                                    .name
                                : "多路線",
                          ),
                        ),
                      );
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ]
        ],
      ),
    );
  }

  /// 構建篩選列 UI (此處僅包含路線篩選)
  Widget _buildFilterBar() {
    return DropdownButtonFormField<String>(
      value: _selectedRouteId,
      hint: const Text('所有路線'),
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '路線',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: [
        // "全部路線" 選項
        const DropdownMenuItem<String>(
          value: null,
          child: Text('全部路線'),
        ),
        // 從 `_availableRoutes` 動態生成路線選項
        ..._availableRoutes.map<DropdownMenuItem<String>>((route) {
          return DropdownMenuItem<String>(
            value: route.id,
            child: Text(route.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (String? newValue) {
        // 當用戶選擇新的路線時，更新狀態並重新應用篩選
        setState(() {
          _selectedRouteId = newValue;
          _applyFilters();
        });
      },
    );
  }

  /// 構建結果顯示區域 UI
  Widget _buildResultsArea() {
    // 情況一：正在加載
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 情況二：發生錯誤
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

    // 情況三：有提示訊息且沒有數據 (通常是初始狀態)
    if (_message != null && _allHistoryData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    // 情況四：有總數據，但根據篩選條件沒有匹配的數據
    if (_allHistoryData.isNotEmpty && _filteredHistoryData.isEmpty) {
      return const Center(
          child: Text(
        '在此篩選條件下沒有資料。',
        style: TextStyle(fontSize: 16),
      ));
    }

    // 情況五：顯示篩選後的數據列表
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _filteredHistoryData.length,
      itemBuilder: (context, index) {
        final dataPoint = _filteredHistoryData[index];
        // 根據 routeId 找到對應的路線名稱
        final route = Static.routeData
            .firstWhere((route) => route.id == dataPoint.routeId);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Card(
          color: colorScheme.surfaceContainerHighest,
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
          child: ListTile(
            title: Text(
                '時間：${Static.displayDateFormat.format(dataPoint.dataTime)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '座標：${dataPoint.lon.toStringAsFixed(6)}, ${dataPoint.lat.toStringAsFixed(6)}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                Text(
                  '狀態：${dataPoint.dutyStatus == 0 ? "營運" : "非營運"}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                Text(
                  '路線 / 編號：${route.name} / ${route.id}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                Text(
                  '方向：${dataPoint.goBack == 1 ? "去程" : "返程"} | 往：${dataPoint.goBack == 1 ? route.destination : route.departure}',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              runAlignment: WrapAlignment.center,
              children: [
                // 按鈕 1: 使用 url_launcher 開啟外部 Google Map
                IconButton(
                  icon: const Icon(Icons.map_sharp, color: Colors.blueAccent),
                  tooltip: '在 Google Map 上查看',
                  onPressed: () async => await launchUrl(Uri.parse(
                      "https://www.google.com/maps?q=${dataPoint.lat},${dataPoint.lon}(${route.name} | ${dataPoint.goBack == 1 ? "去程" : "返程"} | 往：${dataPoint.goBack == 1 ? route.destination : route.departure} | ${Static.displayDateFormat.format(dataPoint.dataTime)})")),
                ),
                // 按鈕 2: 開啟 App 內部的地圖頁面，只顯示這一個點
                IconButton(
                  icon: const Icon(Icons.explore_outlined, color: Colors.teal),
                  tooltip: '在地圖上繪製此點', // 提示文字
                  onPressed: () {
                    // 使用 Navigator.push 導航到 HistoryOsmPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryOsmPage(
                          plate: widget.plate,
                          // 關鍵：傳遞一個只包含當前點的列表，以便地圖只顯示此單點
                          points: [dataPoint],
                          routeName: route.name,
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
            isThreeLine: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          ),
        );
      },
    );
  }
}
