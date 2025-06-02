import 'dart:convert'; // 用於 JsonEncoder，以防萬一需要備用顯示

import 'package:flutter/material.dart';

import '../static.dart';
import '../widgets/theme_provider.dart';

// 用於儲存 API 回應資料的模型
class Company {
  final String name; // 公司名稱
  final String code; // 公司代碼

  Company({required this.name, required this.code});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(name: json['name'], code: json['code']);
  }

  @override
  String toString() => name; // 用於 DropdownButton 顯示
}

class CompanyDataViewerPage extends StatefulWidget {
  const CompanyDataViewerPage({super.key});

  @override
  State<CompanyDataViewerPage> createState() => _CompanyDataViewerPageState();
}

class _CompanyDataViewerPageState extends State<CompanyDataViewerPage> {
  // 狀態變數
  List<Company> _companies = []; // 公司列表
  Company? _selectedCompany; // 目前選擇的公司

  final List<String> _dataTypes = ['cars', 'drivers']; // 固定的資料類型 (內部使用)
  // 用於顯示的中文名稱映射
  final Map<String, String> _dataTypeDisplayNames = {
    'cars': '車輛',
    'drivers': '駕駛員',
  };
  String? _selectedDataType; // 目前選擇的資料類型 (內部值，如 'cars' 或 'drivers')

  List<String> _timestamps = []; // 時間戳列表
  String? _selectedTimestamp; // 目前選擇的時間戳

  dynamic _fetchedData; // 從 API 獲取的原始資料 (可以是 Map 或 List)
  dynamic _filteredData; // 經過搜尋篩選後的資料

  bool _isLoadingCompanies = false; // 是否正在載入公司列表
  bool _isLoadingTimestamps = false; // 是否正在載入時間戳列表
  bool _isLoadingData = false; // 是否正在載入公司資料

  String? _error; // 錯誤訊息
  final TextEditingController _searchController =
  TextEditingController(); // 搜尋框控制器

  // 快取機制
  final Map<String, dynamic> _cache = {};
  static const String _companiesCacheKey = 'companies_list';

  String _getTimestampsCacheKey(String companyCode, String dataType) {
    return 'timestamps_${companyCode}_$dataType';
  }

  String _getDataCacheKey(String companyCode, String dataType,
      String timestamp) {
    return 'data_${companyCode}_${dataType}_$timestamp';
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanies(); // 初始化時載入公司列表
    _searchController.addListener(_applyFilter); // 監聽搜尋框內容變化以套用篩選
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter); // 移除監聽器
    _searchController.dispose(); // 釋放控制器資源
    super.dispose();
  }

  // 載入公司列表
  Future<void> _fetchCompanies() async {
    // 檢查快取
    if (_cache.containsKey(_companiesCacheKey)) {
      setState(() {
        _companies = (_cache[_companiesCacheKey] as List)
            .map((companyJson) => Company.fromJson(companyJson))
            .toList();
        _isLoadingCompanies = false;
        _error = null;
      });
      print("Companies loaded from cache.");
      return;
    }

    setState(() {
      _isLoadingCompanies = true;
      _error = null;
      _companies = [];
      _selectedCompany = null;
      _clearTimestamps();
      _clearData();
    });
    try {
      final response = await Static.dio.get('${Static.apiBaseUrl}/companies');
      if (response.statusCode == 200 && response.data is List) {
        // 存入快取
        _cache[_companiesCacheKey] = response.data;
        print("Companies fetched from API and cached.");
        setState(() {
          _companies = (response.data as List)
              .map((companyJson) => Company.fromJson(companyJson))
              .toList();
        });
      } else {
        throw Exception('無法載入公司列表: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = '載入公司時發生錯誤: $e';
      });
    } finally {
      setState(() {
        _isLoadingCompanies = false;
      });
    }
  }

  // 當選擇的公司變更時觸發
  void _onCompanyChanged(Company? newCompany) {
    setState(() {
      _selectedCompany = newCompany;
      _clearTimestamps();
      _clearData();
      if (_selectedCompany != null && _selectedDataType != null) {
        _fetchTimestamps();
      }
    });
  }

  // 當選擇的資料類型變更時觸發
  void _onDataTypeChanged(String? newDataTypeInternalValue) {
    setState(() {
      _selectedDataType = newDataTypeInternalValue;
      _clearTimestamps();
      _clearData();
      if (_selectedCompany != null && _selectedDataType != null) {
        _fetchTimestamps();
      }
    });
  }

  // 載入時間戳列表
  Future<void> _fetchTimestamps() async {
    if (_selectedCompany == null || _selectedDataType == null) return;

    final cacheKey =
    _getTimestampsCacheKey(_selectedCompany!.code, _selectedDataType!);
    // 檢查快取
    if (_cache.containsKey(cacheKey)) {
      setState(() {
        _timestamps = List<String>.from(_cache[cacheKey] as List);
        _isLoadingTimestamps = false;
        _error = null;
        _selectedTimestamp = null; // 重新選擇時間戳
        _clearData();
      });
      print("Timestamps for ${_selectedCompany!
          .code}/$_selectedDataType loaded from cache.");
      return;
    }

    setState(() {
      _isLoadingTimestamps = true;
      _error = null;
      _clearTimestamps();
      _clearData();
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/timestamps/${_selectedCompany!
          .code}/$_selectedDataType';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200 && response.data is List) {
        // 存入快取
        _cache[cacheKey] = response.data;
        print("Timestamps for ${_selectedCompany!
            .code}/$_selectedDataType fetched from API and cached.");
        setState(() {
          _timestamps = List<String>.from(response.data);
        });
      } else {
        throw Exception(
            '無法載入時間戳: ${response.statusCode} - ${response
                .data?['detail'] ?? response.statusMessage}');
      }
    } catch (e) {
      setState(() {
        _error = '載入時間戳時發生錯誤: $e';
        _timestamps = [];
      });
    } finally {
      setState(() {
        _isLoadingTimestamps = false;
      });
    }
  }

  // 當選擇的時間戳變更時觸發
  void _onTimestampChanged(String? newTimestamp) {
    setState(() {
      _selectedTimestamp = newTimestamp;
      _clearData();
      if (_selectedTimestamp != null) {
        _fetchCompanyData();
      }
    });
  }

  // 載入公司特定資料檔案
  Future<void> _fetchCompanyData() async {
    if (_selectedCompany == null ||
        _selectedDataType == null ||
        _selectedTimestamp == null) return;

    final cacheKey = _getDataCacheKey(
        _selectedCompany!.code, _selectedDataType!, _selectedTimestamp!);
    // 檢查快取
    if (_cache.containsKey(cacheKey)) {
      setState(() {
        _fetchedData = _cache[cacheKey];
        _applyFilter();
        _isLoadingData = false;
        _error = null;
      });
      print("Data for ${_selectedCompany!
          .code}/$_selectedDataType/$_selectedTimestamp loaded from cache.");
      return;
    }

    setState(() {
      _isLoadingData = true;
      _error = null;
      _clearData();
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!
          .code}/$_selectedDataType/$_selectedTimestamp';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200) {
        // 存入快取
        _cache[cacheKey] = response.data;
        print("Data for ${_selectedCompany!
            .code}/$_selectedDataType/$_selectedTimestamp fetched from API and cached.");
        setState(() {
          _fetchedData = response.data;
          _applyFilter();
        });
      } else {
        throw Exception(
            '無法載入公司資料: ${response.statusCode} - ${response
                .data?['detail'] ?? response.statusMessage}');
      }
    } catch (e) {
      setState(() {
        _error = '載入資料時發生錯誤: $e';
      });
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  // 清除時間戳相關狀態
  void _clearTimestamps() {
    setState(() {
      _timestamps = [];
      _selectedTimestamp = null;
    });
  }

  // 清除已載入資料和錯誤訊息
  void _clearData() {
    setState(() {
      _fetchedData = null;
      _filteredData = null;
      // _error = null; // 讓錯誤持續顯示
    });
  }

  // 套用搜尋篩選到已載入的資料
  void _applyFilter() {
    if (_fetchedData == null) {
      setState(() {
        _filteredData = null;
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredData = _fetchedData;
      });
      return;
    }

    if (_fetchedData is List) {
      final List<dynamic> originalList = _fetchedData as List<dynamic>;
      final filteredList = originalList.where((item) {
        if (item is Map) {
          return item.values.any((value) =>
          value != null && value.toString().toLowerCase().contains(query));
        }
        return item.toString().toLowerCase().contains(query);
      }).toList();
      setState(() {
        _filteredData = filteredList;
      });
    } else if (_fetchedData is Map) {
      setState(() {
        _filteredData = _fetchedData;
      });
    } else {
      setState(() {
        _filteredData = _fetchedData;
      });
    }
  }

  // 建立下拉選單的輔助方法
  Widget _buildDropdown<T>({
    required String hintText,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isLoading,
    String? loadingText,
    Map<String, String>? displayNames, // 新增：用於顯示名稱的映射
  }) {
    if (isLoading) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text(loadingText ?? "載入中..."),
            ],
          ),
        ),
      );
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: DropdownButtonFormField<T>(
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          isExpanded: true,
          hint: Text(hintText),
          value: value,
          items: items.map((item) {
            String displayText = item.toString();
            if (displayNames != null && item is String &&
                displayNames.containsKey(item)) {
              displayText = displayNames[item]!;
            }
            return DropdownMenuItem<T>(
              value: item,
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }

  // 建立資料顯示區域的輔助方法
  Widget _buildDataDisplayArea() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredData == null) {
      return Center(
        child: Text(
          _selectedCompany == null
              ? '請先選擇公司'
              : _selectedDataType == null
              ? '請選擇資料類型'
              : _selectedTimestamp == null
              ? _isLoadingTimestamps
              ? '載入時間戳中...'
              : _timestamps.isEmpty && !_isLoadingTimestamps && _error == null
              ? '此公司和資料類型下沒有時間戳'
              : '請選擇時間戳以載入資料'
              : '沒有資料可顯示或載入失敗',
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      );
    }

    if ((_selectedDataType == 'cars' || _selectedDataType == 'drivers') &&
        _filteredData is List) {
      final List<dynamic> dataList = _filteredData as List<dynamic>;
      if (dataList.isEmpty) {
        return Center(child: Text(_searchController.text.isEmpty
            ? "此時間戳下沒有資料。"
            : "沒有符合搜尋條件的資料。"));
      }
      return ListView.builder(
        itemCount: dataList.length,
        itemBuilder: (context, index) {
          final item = dataList[index];
          if (item is Map<String, dynamic>) {
            if (_selectedDataType == 'cars') {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: ListTile(
                  leading: const Icon(Icons.directions_car,
                      color: Colors.blueAccent),
                  title: Text(item['model']?.toString() ??
                      item['plate_number']?.toString() ??
                      '未知車輛'),
                  subtitle: Text('ID: ${item['id']?.toString() ?? 'N/A'}\n'
                      '車牌: ${item['plate_number']?.toString() ?? 'N/A'}\n'
                      '狀態: ${item['status']?.toString() ?? 'N/A'}'),
                  isThreeLine: true,
                ),
              );
            } else if (_selectedDataType == 'drivers') {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.greenAccent),
                  title: Text(item['name']?.toString() ?? '未知駕駛員'),
                  subtitle: Text('ID: ${item['id']?.toString() ?? 'N/A'}\n'
                      '駕照號碼: ${item['license_id']?.toString() ?? 'N/A'}\n'
                      '班別: ${item['shift']?.toString() ?? 'N/A'}'),
                  isThreeLine: true,
                ),
              );
            }
          }
          return ListTile(title: Text(item.toString()));
        },
      );
    }

    try {
      return SingleChildScrollView(
        child: Text(
          const JsonEncoder.withIndent('  ').convert(_filteredData),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      );
    } catch (e) {
      return Center(child: Text("無法以 JSON 格式顯示資料: $e"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider( // 假設 ThemeProvider 仍有其他用途或依照原樣保留
      builder: (BuildContext context, ThemeData themeData) =>
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '搜尋已載入的資料',
                    hintText: '輸入關鍵字...',
                    prefixIcon: const Icon(Icons.search),
                    border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildDropdown<Company>(
                        hintText: '選擇公司',
                        value: _selectedCompany,
                        items: _companies,
                        onChanged: _onCompanyChanged,
                        isLoading: _isLoadingCompanies,
                        loadingText: "載入公司..."),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDropdown<String>(
                      hintText: '選擇資料類型',
                      value: _selectedDataType,
                      items: _dataTypes,
                      // 內部值
                      onChanged: _onDataTypeChanged,
                      isLoading: false,
                      displayNames: _dataTypeDisplayNames, // 傳入顯示名稱映射
                    ),
                    _buildDropdown<String>(
                        hintText: '選擇時間戳',
                        value: _selectedTimestamp,
                        items: _timestamps,
                        onChanged: (_selectedCompany == null ||
                            _selectedDataType == null ||
                            _timestamps.isEmpty)
                            ? (String? _) {} // 如果前置條件未滿足或沒有時間戳，則禁用
                            : _onTimestampChanged,
                        isLoading: _isLoadingTimestamps,
                        loadingText: "載入時間戳..."),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                // 新增清除快取按鈕 (可選)
                // if (_cache.isNotEmpty)
                //   ElevatedButton(
                //     onPressed: () {
                //       setState(() {
                //         _cache.clear();
                //         _error = "快取已清除，請重新載入資料。";
                //         // 可以選擇是否重置所有選擇或觸發重新載入
                //         _companies = [];
                //         _selectedCompany = null;
                //         _selectedDataType = null;
                //         _clearTimestamps();
                //         _clearData();
                //       });
                //       _fetchCompanies(); // 例如，重新載入公司列表
                //       print("Cache cleared by user.");
                //     },
                //     child: const Text("清除快取"),
                //   ),
                // const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildDataDisplayArea(),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}