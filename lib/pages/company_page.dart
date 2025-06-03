import 'dart:convert'; // 用於 JsonEncoder

import 'package:collection/collection.dart'; // 用於 deepEq
import 'package:flutter/material.dart';

import '../data/company.dart';
import '../static.dart';
import '../widgets/theme_provider.dart';

class CompanyDataViewerPage extends StatefulWidget {
  const CompanyDataViewerPage({super.key});

  @override
  State<CompanyDataViewerPage> createState() => _CompanyDataViewerPageState();
}

class _CompanyDataViewerPageState extends State<CompanyDataViewerPage> {
  // --- 狀態變數 ---
  List<Company> _companies = [];
  Company? _selectedCompany;

  final List<String> _dataTypes = ['cars', 'drivers'];
  final Map<String, String> _dataTypeDisplayNames = {
    'cars': '車輛',
    'drivers': '駕駛員',
  };
  String? _selectedDataType;

  List<String> _timestamps = [];
  String? _selectedTimestamp1;
  String? _selectedTimestamp2;

  dynamic _fetchedData1;
  dynamic _filteredData1;
  dynamic _fetchedData2;
  dynamic _filteredData2;

  Map<String, List<Map<String, dynamic>>>? _comparisonResult;

  bool _isLoadingCompanies = false;
  bool _isLoadingTimestamps = false;
  bool _isLoadingData1 = false;
  bool _isLoadingData2 = false;

  String? _error;
  final TextEditingController _searchController = TextEditingController();

  // --- 快取機制 ---
  final Map<String, dynamic> _cache = {};
  static const String _companiesCacheKey = 'companies_list';

  String _getTimestampsCacheKey(String companyCode, String dataType) {
    return 'timestamps_${companyCode}_$dataType';
  }

  String _getDataCacheKey(
      String companyCode, String dataType, String timestamp) {
    return 'data_${companyCode}_${dataType}_$timestamp';
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  // --- 資料清除輔助方法 ---
  void _clearTimestampsSelection() {
    setState(() {
      _selectedTimestamp1 = null;
      _selectedTimestamp2 = null;
      _clearFetchedData();
    });
  }

  void _clearTimestampsList() {
    setState(() {
      _timestamps = [];
      _clearTimestampsSelection();
    });
  }

  void _clearFetchedData() {
    setState(() {
      _fetchedData1 = null;
      _filteredData1 = null;
      _fetchedData2 = null;
      _filteredData2 = null;
      _comparisonResult = null;
    });
  }

  // --- 資料獲取方法 ---
  Future<void> _fetchCompanies() async {
    if (_cache.containsKey(_companiesCacheKey)) {
      setState(() {
        _companies = (_cache[_companiesCacheKey] as List)
            .map((companyJson) => Company.fromJson(companyJson))
            .toList();
        _isLoadingCompanies = false;
        _error = null;
      });
      print("公司列表從快取載入。");
      return;
    }

    setState(() {
      _isLoadingCompanies = true;
      _error = null;
      _companies = [];
      _selectedCompany = null;
      _clearTimestampsList();
      _clearFetchedData();
    });
    try {
      final response = await Static.dio.get('${Static.apiBaseUrl}/companies');
      if (response.statusCode == 200 && response.data is List) {
        _cache[_companiesCacheKey] = response.data;
        print("公司列表從 API 獲取並快取。");
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

  void _onCompanyChanged(Company? newCompany) {
    setState(() {
      _selectedCompany = newCompany;
      _clearTimestampsList();
      _clearFetchedData();
      if (_selectedCompany != null && _selectedDataType != null) {
        _fetchTimestamps();
      }
    });
  }

  void _onDataTypeChanged(String? newDataTypeInternalValue) {
    setState(() {
      _selectedDataType = newDataTypeInternalValue;
      _clearTimestampsList();
      _clearFetchedData();
      if (_selectedCompany != null && _selectedDataType != null) {
        _fetchTimestamps();
      }
    });
  }

  Future<void> _fetchTimestamps() async {
    if (_selectedCompany == null || _selectedDataType == null) return;

    final cacheKey =
        _getTimestampsCacheKey(_selectedCompany!.code, _selectedDataType!);
    if (_cache.containsKey(cacheKey)) {
      setState(() {
        _timestamps = List<String>.from(_cache[cacheKey] as List);
        _isLoadingTimestamps = false;
        _error = null;
        _clearTimestampsSelection();
      });
      print("時間戳 for ${_selectedCompany!.code}/$_selectedDataType 從快取載入。");
      return;
    }

    setState(() {
      _isLoadingTimestamps = true;
      _error = null;
      _clearTimestampsList();
      _clearFetchedData();
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/timestamps/${_selectedCompany!.code}/$_selectedDataType';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200 && response.data is List) {
        _cache[cacheKey] = response.data;
        print(
            "時間戳 for ${_selectedCompany!.code}/$_selectedDataType 從 API 獲取並快取。");
        setState(() {
          _timestamps = List<String>.from(response.data);
        });
      } else {
        throw Exception(
            '無法載入時間戳: ${response.statusCode} - ${response.data?['detail'] ?? response.statusMessage}');
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

  void _onTimestampChanged(String? newTimestamp, int target) {
    setState(() {
      if (target == 1) {
        _selectedTimestamp1 = newTimestamp;
        _fetchedData1 = null;
        _filteredData1 = null;
        _isLoadingData1 = false;
      } else {
        _selectedTimestamp2 = newTimestamp;
        _fetchedData2 = null;
        _filteredData2 = null;
        _isLoadingData2 = false;
      }
      _comparisonResult = null;

      if (newTimestamp != null) {
        _fetchCompanyDataFor(target);
      } else {
        _performComparison();
      }
    });
  }

  Future<void> _fetchCompanyDataFor(int target) async {
    if (_selectedCompany == null || _selectedDataType == null) return;
    final String? selectedTimestamp =
        (target == 1) ? _selectedTimestamp1 : _selectedTimestamp2;
    if (selectedTimestamp == null) return;

    final cacheKey = _getDataCacheKey(
        _selectedCompany!.code, _selectedDataType!, selectedTimestamp);
    if (_cache.containsKey(cacheKey)) {
      setState(() {
        if (target == 1) {
          _fetchedData1 = _cache[cacheKey];
          _isLoadingData1 = false;
        } else {
          _fetchedData2 = _cache[cacheKey];
          _isLoadingData2 = false;
        }
        _error = null;
        _applyFilter();
      });
      print(
          "資料 for ${_selectedCompany!.code}/$_selectedDataType/$selectedTimestamp (資料集 $target) 從快取載入。");
      return;
    }

    setState(() {
      if (target == 1) {
        _isLoadingData1 = true;
        _fetchedData1 = null;
        _filteredData1 = null;
      } else {
        _isLoadingData2 = true;
        _fetchedData2 = null;
        _filteredData2 = null;
      }
      _error = null;
      _comparisonResult = null;
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!.code}/$_selectedDataType/$selectedTimestamp';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200) {
        _cache[cacheKey] = response.data;
        print(
            "資料 for ${_selectedCompany!.code}/$_selectedDataType/$selectedTimestamp (資料集 $target) 從 API 獲取並快取。");
        setState(() {
          if (target == 1) {
            _fetchedData1 = response.data;
          } else {
            _fetchedData2 = response.data;
          }
          _applyFilter();
        });
      } else {
        throw Exception(
            '無法載入公司資料: ${response.statusCode} - ${response.data?['detail'] ?? response.statusMessage}');
      }
    } catch (e) {
      setState(() {
        _error = '載入資料集 $target 時發生錯誤: $e';
      });
    } finally {
      setState(() {
        if (target == 1) {
          _isLoadingData1 = false;
        } else {
          _isLoadingData2 = false;
        }
      });
    }
  }

  // --- 篩選與比較邏輯 ---
  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    _filteredData1 = _filterSingleData(_fetchedData1, query);
    _filteredData2 = _filterSingleData(_fetchedData2, query);

    _performComparison();
    setState(() {});
  }

  dynamic _filterSingleData(dynamic fetchedData, String query) {
    if (fetchedData == null) return null;
    if (query.isEmpty) return fetchedData;

    if (fetchedData is List) {
      return fetchedData.where((item) {
        if (item is Map) {
          return item.values.any((value) =>
              value != null && value.toString().toLowerCase().contains(query));
        }
        return item.toString().toLowerCase().contains(query);
      }).toList();
    } else if (fetchedData is Map) {
      return fetchedData;
    }
    return fetchedData;
  }

  void _performComparison() {
    if (_filteredData1 == null ||
        _filteredData2 == null ||
        _selectedDataType == null) {
      setState(() {
        _comparisonResult = null;
      });
      return;
    }

    if ((_selectedDataType == 'cars' || _selectedDataType == 'drivers') &&
        _filteredData1 is List &&
        _filteredData2 is List) {
      final List<dynamic> list1 = _filteredData1 as List<dynamic>;
      final List<dynamic> list2 = _filteredData2 as List<dynamic>;
      final String idField =
          (_selectedDataType == 'cars' || _selectedDataType == 'drivers')
              ? 'id'
              : '';

      if (idField.isEmpty) {
        setState(() {
          _comparisonResult = null;
          _error = "選定的資料類型無法進行項目級別的比較。";
        });
        return;
      }

      final List<Map<String, dynamic>> typedList1 =
          list1.whereType<Map<String, dynamic>>().toList();
      final List<Map<String, dynamic>> typedList2 =
          list2.whereType<Map<String, dynamic>>().toList();

      final Map<dynamic, Map<String, dynamic>> map1 = {
        for (var item in typedList1) item[idField]: item
      };
      final Map<dynamic, Map<String, dynamic>> map2 = {
        for (var item in typedList2) item[idField]: item
      };

      List<Map<String, dynamic>> added = [];
      List<Map<String, dynamic>> removed = [];
      List<Map<String, dynamic>> modified = [];

      for (var id2 in map2.keys) {
        final item2 = map2[id2]!;
        if (map1.containsKey(id2)) {
          final item1 = map1[id2]!;
          if (!const DeepCollectionEquality().equals(item1, item2)) {
            Map<String, Map<String, dynamic>> changes = {};
            Set<String> allKeys = {...item1.keys, ...item2.keys};
            for (String key in allKeys) {
              if (!const DeepCollectionEquality()
                  .equals(item1[key], item2[key])) {
                changes[key] = {'old': item1[key], 'new': item2[key]};
              }
            }
            modified.add({
              'id': id2,
              'item1': item1,
              'item2': item2,
              'changes': changes
            });
          }
        } else {
          added.add(item2);
        }
      }

      for (var id1 in map1.keys) {
        if (!map2.containsKey(id1)) {
          removed.add(map1[id1]!);
        }
      }

      setState(() {
        _comparisonResult = {
          'added': added,
          'removed': removed,
          'modified': modified
        };
      });
    } else {
      if (!const DeepCollectionEquality()
          .equals(_filteredData1, _filteredData2)) {
        setState(() {
          _comparisonResult = {
            'general_diff': [
              {'message': '資料內容不同，但非列表格式，無法逐項比較。'}
            ]
          };
        });
      } else {
        setState(() {
          _comparisonResult = {'added': [], 'removed': [], 'modified': []};
        });
      }
    }
  }

  // --- UI 建構輔助方法 ---
  Widget _buildDropdown<T>({
    required ThemeData themeData,
    required String hintText,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isLoading,
    String? loadingText,
    Map<String, String>? displayNames,
    bool enabled = true,
  }) {
    if (isLoading) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeData.colorScheme.primary,
                  )),
              const SizedBox(width: 8),
              Text(loadingText ?? "載入中...",
                  style: themeData.textTheme.bodyMedium),
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
            filled: !enabled,
            fillColor: themeData.disabledColor.withAlpha((0.1 * 255).round()),
          ),
          isExpanded: true,
          hint: Text(hintText,
              style: themeData.textTheme.bodyMedium
                  ?.copyWith(color: themeData.hintColor)),
          value: value,
          items: items.map((item) {
            String displayText = item.toString();
            if (item is Company) displayText = item.name;
            if (displayNames != null &&
                item is String &&
                displayNames.containsKey(item)) {
              displayText = displayNames[item]!;
            }
            return DropdownMenuItem<T>(
              value: item,
              child: Text(displayText,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: enabled && items.isNotEmpty ? onChanged : null,
          style: themeData.textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildDataPanel({
    required ThemeData themeData,
    required String title,
    required dynamic data,
    required bool isLoading,
    required String? selectedDataType,
  }) {
    String dataTypeDisplayName = selectedDataType != null
        ? (_dataTypeDisplayNames[selectedDataType] ?? selectedDataType)
        : '資料';

    Widget content;
    final placeholderColor =
        themeData.colorScheme.onSurface.withAlpha((0.6 * 255).round());

    if (isLoading) {
      content = Center(
          child:
              CircularProgressIndicator(color: themeData.colorScheme.primary));
    } else if (data == null) {
      content = Center(
          child: Text('請選擇時間戳以載入$dataTypeDisplayName。',
              style: TextStyle(color: placeholderColor)));
    } else if (data is List && data.isEmpty) {
      content = Center(
          child: Text(
              _searchController.text.isEmpty
                  ? '此時間戳下沒有$dataTypeDisplayName。'
                  : '沒有符合搜尋條件的$dataTypeDisplayName。',
              style: TextStyle(color: placeholderColor)));
    } else if ((selectedDataType == 'cars' || selectedDataType == 'drivers') &&
        data is List) {
      content = _buildListDisplay(themeData, data, selectedDataType!);
    } else {
      try {
        content = SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            child: Text(const JsonEncoder.withIndent('  ').convert(data),
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: themeData.textTheme.bodyMedium?.color)));
      } catch (e) {
        content = Center(
            child: Text("無法以 JSON 格式顯示資料: $e",
                style: TextStyle(color: themeData.colorScheme.error)));
      }
    }

    return Card(
      // Card 本身會佔用 Expanded 分配的空間
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: themeData.cardColor,
      child: Column(
        // Column 讓標題和內容垂直排列
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(title,
                style: themeData.textTheme.titleSmall,
                textAlign: TextAlign.center),
          ),
          Divider(height: 1, color: themeData.dividerColor),
          Expanded(
              // 內容部分使用 Expanded 以填滿 Card 內的剩餘空間
              child:
                  Padding(padding: const EdgeInsets.all(8.0), child: content)),
        ],
      ),
    );
  }

  Widget _buildListDisplay(
      ThemeData themeData, List<dynamic> dataList, String dataType) {
    return ListView.builder(
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        if (item is Map<String, dynamic>) {
          IconData listIcon;
          Color iconColor;
          if (dataType == 'cars') {
            listIcon = Icons.directions_car;
            iconColor = themeData.colorScheme.primary;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              color: themeData.colorScheme.surfaceVariant,
              child: ListTile(
                leading: Icon(listIcon, color: iconColor),
                title: Text(
                    item['model']?.toString() ??
                        item['plate_number']?.toString() ??
                        '未知車輛',
                    style: themeData.textTheme.titleMedium),
                subtitle: Text(
                    'ID: ${item['id']?.toString() ?? 'N/A'}\n'
                    '車牌: ${item['plate_number']?.toString() ?? 'N/A'}\n'
                    '狀態: ${item['status']?.toString() ?? 'N/A'}',
                    style: themeData.textTheme.bodySmall),
                isThreeLine: true,
              ),
            );
          } else if (dataType == 'drivers') {
            listIcon = Icons.person;
            iconColor = themeData.colorScheme.secondary;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              color: themeData.colorScheme.surfaceVariant,
              child: ListTile(
                leading: Icon(listIcon, color: iconColor),
                title: Text(item['name']?.toString() ?? '未知駕駛員',
                    style: themeData.textTheme.titleMedium),
                subtitle: Text(
                    'ID: ${item['id']?.toString() ?? 'N/A'}\n'
                    '駕照號碼: ${item['license_id']?.toString() ?? 'N/A'}\n'
                    '班別: ${item['shift']?.toString() ?? 'N/A'}',
                    style: themeData.textTheme.bodySmall),
                isThreeLine: true,
              ),
            );
          }
        }
        return ListTile(
            title:
                Text(item.toString(), style: themeData.textTheme.bodyMedium));
      },
    );
  }

  Widget _buildComparisonPanel(ThemeData themeData) {
    String? dataTypeDisplayName = _selectedDataType != null
        ? (_dataTypeDisplayNames[_selectedDataType] ?? _selectedDataType)
        : '項目';
    final placeholderColor =
        themeData.colorScheme.onSurface.withAlpha((0.6 * 255).round());
    final colorScheme = themeData.colorScheme;

    Widget content;

    if (_selectedTimestamp1 == null || _selectedTimestamp2 == null) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child:
            Text('請選擇兩個時間戳以進行比較。', style: TextStyle(color: placeholderColor)),
      ));
    } else if (_isLoadingData1 || _isLoadingData2) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('資料載入中，請稍候...', style: TextStyle(color: placeholderColor)),
      ));
    } else if (_comparisonResult == null) {
      if (_filteredData1 != null && _filteredData2 != null) {
        content = Center(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('正在準備比較結果或無明顯差異...',
              style: TextStyle(color: placeholderColor)),
        ));
      } else {
        content = Center(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('比較結果將顯示於此。', style: TextStyle(color: placeholderColor)),
        ));
      }
    } else if (_comparisonResult!['general_diff'] != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              _comparisonResult!['general_diff']![0]['message'].toString(),
              style: TextStyle(color: colorScheme.secondary)),
        ),
      );
    } else {
      final added = _comparisonResult!['added']!;
      final removed = _comparisonResult!['removed']!;
      final modified = _comparisonResult!['modified']!;

      if (added.isEmpty && removed.isEmpty && modified.isEmpty) {
        content = Center(
            child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('兩個資料集之間沒有差異。',
              style: TextStyle(color: colorScheme.primary)),
        ));
      } else {
        List<Widget> diffWidgets = [];
        if (added.isNotEmpty) {
          diffWidgets.add(Text('新增的$dataTypeDisplayName (僅存在於時間戳 2):',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: colorScheme.tertiary)));
          added.forEach((item) =>
              diffWidgets.add(_buildDiffItemCard(themeData, item, '新增')));
          diffWidgets.add(const SizedBox(height: 8));
        }
        if (removed.isNotEmpty) {
          diffWidgets.add(Text('移除的$dataTypeDisplayName (僅存在於時間戳 1):',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: colorScheme.error)));
          removed.forEach((item) =>
              diffWidgets.add(_buildDiffItemCard(themeData, item, '移除')));
          diffWidgets.add(const SizedBox(height: 8));
        }
        if (modified.isNotEmpty) {
          diffWidgets.add(Text('修改的$dataTypeDisplayName:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: colorScheme.secondary)));
          modified.forEach((mod) {
            final item1 = mod['item1'] as Map<String, dynamic>;
            final item2 = mod['item2'] as Map<String, dynamic>;
            final changes = mod['changes'] as Map<String, dynamic>;
            diffWidgets.add(_buildModifiedItemCard(
                themeData, mod['id'], item1, item2, changes));
          });
        }
        content = ListView(children: diffWidgets);
      }
    }

    // _buildComparisonPanel 現在返回 Card 包裹內容
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: themeData.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0), // 給 Card 內部內容一些 padding
        child: content, // content 可能是 Center 或 ListView
      ),
    );
  }

  Widget _buildDiffItemCard(
      ThemeData themeData, Map<String, dynamic> item, String type) {
    final Color cardColor;
    final Color iconColor;
    final Color textColor;
    final IconData icon;

    final colorScheme = themeData.colorScheme;

    if (type == '新增') {
      cardColor = colorScheme.tertiaryContainer;
      iconColor = colorScheme.tertiary;
      textColor = colorScheme.onTertiaryContainer;
      icon = Icons.add_circle_outline;
    } else {
      cardColor = colorScheme.errorContainer;
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.remove_circle_outline;
    }

    String title = '';
    String subtitle = 'ID: ${item['id']?.toString() ?? 'N/A'}';

    if (_selectedDataType == 'cars') {
      title = item['model']?.toString() ??
          item['plate_number']?.toString() ??
          '未知車輛';
      subtitle += '\n車牌: ${item['plate_number']?.toString() ?? 'N/A'}';
    } else if (_selectedDataType == 'drivers') {
      title = item['name']?.toString() ?? '未知駕駛員';
      subtitle += '\n駕照號碼: ${item['license_id']?.toString() ?? 'N/A'}';
    } else {
      title = item.entries
          .firstWhere((e) => e.value is String,
              orElse: () => MapEntry('', '未知項目 ${item['id']}'))
          .value;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(subtitle,
            style: TextStyle(color: textColor.withAlpha((0.8 * 255).round()))),
        isThreeLine:
            (_selectedDataType == 'cars' || _selectedDataType == 'drivers'),
      ),
    );
  }

  Widget _buildModifiedItemCard(
      ThemeData themeData,
      dynamic id,
      Map<String, dynamic> item1,
      Map<String, dynamic> item2,
      Map<String, dynamic> changes) {
    final colorScheme = themeData.colorScheme;
    final cardColor = colorScheme.secondaryContainer;
    final iconColor = colorScheme.secondary;
    final titleTextColor = colorScheme.onSecondaryContainer;
    final defaultTextStyle = themeData.textTheme.bodyMedium ??
        TextStyle(color: colorScheme.onSurface);

    List<Widget> changeDetails = [];
    changes.forEach((key, value) {
      final changeMap = value as Map<String, dynamic>;
      changeDetails.add(Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 2, bottom: 2),
        child: RichText(
          text: TextSpan(
            style: defaultTextStyle,
            children: <TextSpan>[
              TextSpan(
                  text: '$key: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: titleTextColor)),
              TextSpan(
                  text: '${changeMap['old']}',
                  style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: titleTextColor.withAlpha((0.7 * 255).round()))),
              TextSpan(
                  text: ' → ',
                  style:
                      TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
              TextSpan(
                  text: '${changeMap['new']}',
                  style:
                      TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ));
    });

    String title = '';
    if (_selectedDataType == 'cars') {
      title = item2['model']?.toString() ??
          item2['plate_number']?.toString() ??
          '未知車輛 (ID: $id)';
    } else if (_selectedDataType == 'drivers') {
      title = item2['name']?.toString() ?? '未知駕駛員 (ID: $id)';
    } else {
      title = item2.entries
          .firstWhere((e) => e.value is String,
              orElse: () => MapEntry('', '項目 ID: $id'))
          .value;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.edit, color: iconColor),
        iconColor: titleTextColor,
        collapsedIconColor: titleTextColor,
        title: Text(title, style: TextStyle(color: titleTextColor)),
        subtitle: Text('ID: $id 有變動',
            style: TextStyle(
                color: titleTextColor.withAlpha((0.8 * 255).round()))),
        children: changeDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) {
        final bool canSelectTimestamps =
            _selectedCompany != null && _selectedDataType != null;
        final colorScheme = themeData.colorScheme;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 上方控制區域 ---
              TextField(
                controller: _searchController,
                style: themeData.textTheme.bodyLarge,
                decoration: InputDecoration(
                  labelText: '搜尋已載入的資料',
                  labelStyle: themeData.textTheme.labelMedium,
                  hintText: '輸入關鍵字...',
                  hintStyle: themeData.textTheme.bodyMedium
                      ?.copyWith(color: themeData.hintColor),
                  prefixIcon:
                      Icon(Icons.search, color: themeData.colorScheme.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: themeData.colorScheme.onSurfaceVariant),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDropdown<Company>(
                      themeData: themeData,
                      hintText: '選擇公司',
                      value: _selectedCompany,
                      items: _companies,
                      onChanged: _onCompanyChanged,
                      isLoading: _isLoadingCompanies,
                      loadingText: "載入公司..."),
                  const SizedBox(width: 8),
                  _buildDropdown<String>(
                    themeData: themeData,
                    hintText: '選擇資料類型',
                    value: _selectedDataType,
                    items: _dataTypes,
                    onChanged: _onDataTypeChanged,
                    isLoading: false,
                    displayNames: _dataTypeDisplayNames,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildDropdown<String>(
                    themeData: themeData,
                    hintText: '選擇時間戳 1',
                    value: _selectedTimestamp1,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 1),
                    isLoading: _isLoadingTimestamps,
                    loadingText: "載入時間戳...",
                    enabled: canSelectTimestamps,
                  ),
                  const SizedBox(width: 8),
                  _buildDropdown<String>(
                    themeData: themeData,
                    hintText: '選擇時間戳 2',
                    value: _selectedTimestamp2,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 2),
                    isLoading: _isLoadingTimestamps && _timestamps.isEmpty,
                    loadingText: "載入時間戳...",
                    enabled: canSelectTimestamps,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- 錯誤訊息顯示 ---
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(_error!,
                      style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ),

              // --- 主要內容區域 (資料顯示與比較) ---
              Expanded(
                // 這個 Expanded 控制主要內容區在垂直方向上的佔用
                child: Row(
                  // 水平排列三個面板
                  crossAxisAlignment: CrossAxisAlignment.start, // 確保面板從頂部開始對齊
                  children: [
                    // 資料集 1 面板
                    Expanded(
                      flex: 1, // Flex 比例可以根據需要調整
                      child: _buildDataPanel(
                        themeData: themeData,
                        title: "資料集 1\n(${_selectedTimestamp1 ?? '未選擇'})",
                        data: _filteredData1,
                        isLoading: _isLoadingData1,
                        selectedDataType: _selectedDataType,
                      ),
                    ),
                    const SizedBox(width: 8), // 面板間隔

                    // 資料集 2 面板
                    Expanded(
                      flex: 1, // Flex 比例
                      child: _buildDataPanel(
                        themeData: themeData,
                        title: "資料集 2\n(${_selectedTimestamp2 ?? '未選擇'})",
                        data: _filteredData2,
                        isLoading: _isLoadingData2,
                        selectedDataType: _selectedDataType,
                      ),
                    ),
                    const SizedBox(width: 8), // 面板間隔

                    // 差異比較面板
                    Expanded(
                      flex: 1, // Flex 比例
                      child: Column(
                        // 差異比較區包含標題和內容
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        // 使標題和Divider充滿寬度
                        children: [
                          // 差異比較區標題
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.compare_arrows,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text("差異比對結果",
                                    style: themeData.textTheme.titleMedium),
                              ],
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            height: 1, // 緊湊的 Divider
                            color: themeData.dividerColor,
                          ),
                          // 比較內容本身需要 Expanded 以填充 Column 的剩餘垂直空間
                          Expanded(
                            child: _buildComparisonPanel(themeData),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
