import 'package:collection/collection.dart'; // 用於 deepEq (深度相等比較)
import 'package:flutter/material.dart';

import '../data/company.dart'; // 公司資料模型 (假設仍然需要用於公司選擇)
import '../static.dart'; // 靜態資源，例如 API URL 和 dio 實例
import '../widgets/theme_provider.dart'; // 主題提供者

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  // --- 狀態變數 ---
  List<Company> _companies = [];
  Company? _selectedCompany;

  // 資料類型選擇仍然保留，因為它可能影響 API 端點
  // 但我們假設所有選定的資料類型最終都會返回 List<String> 格式的資料
  final List<String> _dataTypes = [
    'cars',
    'drivers',
  ]; // 示例：可增加實際的資料類型
  final Map<String, String> _dataTypeDisplayNames = {
    'cars': '車輛', // 更新顯示名稱以反映預期格式
    'drivers': '駕駛員',
  };
  String? _selectedDataType;

  List<String> _timestamps = [];
  String? _selectedTimestamp1;
  String? _selectedTimestamp2;

  dynamic _fetchedData1;
  dynamic _filteredData1; // 現在預期主要是 List<String>
  dynamic _fetchedData2;
  dynamic _filteredData2; // 現在預期主要是 List<String>

  // 比較結果將只包含 'added' 和 'removed'
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

  Future<void> _fetchCompanies() async {
    if (_cache.containsKey(_companiesCacheKey)) {
      setState(() {
        _companies = (_cache[_companiesCacheKey] as List)
            .map((companyJson) => Company.fromJson(companyJson))
            .toList();
        _isLoadingCompanies = false;
        _error = null;
      });
      Static.log("公司列表從快取載入。");
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
        Static.log("公司列表從 API 獲取並快取。");
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
      Static.log("資料集 for ${_selectedCompany!.code}/$_selectedDataType 從快取載入。");
      return;
    }

    setState(() {
      _isLoadingTimestamps = true;
      _error = null;
      _clearTimestampsList();
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/timestamps/${_selectedCompany!.code}/$_selectedDataType';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200 && response.data is List) {
        _cache[cacheKey] = response.data;
        Static.log(
            "資料集 for ${_selectedCompany!.code}/$_selectedDataType 從 API 獲取並快取。");
        setState(() {
          _timestamps = List<String>.from(response.data);
        });
      } else {
        throw Exception(
            '無法載入資料集: ${response.statusCode} - ${response.data?['detail'] ?? response.statusMessage}');
      }
    } catch (e) {
      setState(() {
        _error = '載入資料集時發生錯誤: $e';
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
        if (target == 1) {
          _fetchedData1 = null;
          _filteredData1 = null;
        } else {
          _fetchedData2 = null;
          _filteredData2 = null;
        }
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
      Static.log(
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
    });

    try {
      final url =
          '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!.code}/$_selectedDataType/$selectedTimestamp';
      final response = await Static.dio.get(url);
      if (response.statusCode == 200) {
        // 假設 API 對於這種類型總是返回 List<dynamic>，其中元素是 String
        if (response.data is List) {
          _cache[cacheKey] = response.data;
          Static.log(
              "資料 for ${_selectedCompany!.code}/$_selectedDataType/$selectedTimestamp (資料集 $target) 從 API 獲取並快取。");
          setState(() {
            if (target == 1) {
              _fetchedData1 = response.data;
            } else {
              _fetchedData2 = response.data;
            }
          });
        } else {
          throw Exception('API 返回的資料格式非預期的列表。');
        }
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
      _applyFilter();
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    _filteredData1 = _filterSingleData(_fetchedData1, query);
    _filteredData2 = _filterSingleData(_fetchedData2, query);
    _performComparison();
    if (mounted) {
      setState(() {});
    }
  }

  dynamic _filterSingleData(dynamic fetchedData, String query) {
    if (fetchedData == null) return null;
    if (query.isEmpty) return fetchedData;

    if (fetchedData is List) {
      // 主要處理 List<String>
      return fetchedData.where((item) {
        if (item is String) {
          return item.toLowerCase().contains(query);
        }
        // 如果列表中有非字串元素（理論上不應該發生，如果API總是返回List<String>）
        // 則回退到 toString 比較
        return item.toString().toLowerCase().contains(query);
      }).toList();
    }
    // 如果 fetchedData 不是 List (例如，API返回錯誤或非預期格式)，則不篩選
    return fetchedData;
  }

  void _performComparison() {
    if (_filteredData1 == null || _filteredData2 == null) {
      if (mounted) {
        setState(() {
          _comparisonResult = null;
        });
      }
      return;
    }

    // 主要處理兩個 List<String> 的比較
    if (_filteredData1 is List &&
        (_filteredData1.isEmpty || _filteredData1.first is String) &&
        _filteredData2 is List &&
        (_filteredData2.isEmpty || _filteredData2.first is String)) {
      final List<String> list1 = List<String>.from(_filteredData1 as List);
      final List<String> list2 = List<String>.from(_filteredData2 as List);

      final Set<String> set1 = list1.toSet();
      final Set<String> set2 = list2.toSet();

      final List<Map<String, dynamic>> added =
          set2.difference(set1).map((s) => {'value': s}).toList();
      final List<Map<String, dynamic>> removed =
          set1.difference(set2).map((s) => {'value': s}).toList();

      if (mounted) {
        setState(() {
          _comparisonResult = {
            'added': added,
            'removed': removed,
            'modified': [], // 對於 List<String>，我們不定義 "modified"
          };
          _error = null;
        });
      }
    } else {
      // 如果資料不是預期的 List<String> 格式，則進行通用比較或顯示錯誤
      if (!const DeepCollectionEquality()
          .equals(_filteredData1, _filteredData2)) {
        if (mounted) {
          setState(() {
            _comparisonResult = {
              'general_diff': [
                {'message': '資料內容不同，或資料格式非預期的純字串列表。'}
              ],
              'added': [], 'removed': [], 'modified': [], // 確保UI有預期鍵
            };
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _comparisonResult = {'added': [], 'removed': [], 'modified': []};
          });
        }
      }
    }
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeData.colorScheme.primary,
                  )),
              const SizedBox(width: 8),
              Text(loadingText ?? "載入中...",
                  style: themeData.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: DropdownButtonFormField<T>(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: !enabled,
            fillColor: themeData.disabledColor.withAlpha((0.1 * 255).round()),
          ),
          isExpanded: true,
          isDense: true,
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
    required dynamic data, // 預期是 List<String> 或 null
    required bool isLoading,
    // selectedDataType 仍然可以傳遞，但 _buildListDisplay 已不依賴它來顯示 List<String>
    required String? selectedDataType,
  }) {
    String dataTypeDisplayName = selectedDataType != null
        ? (_dataTypeDisplayNames[selectedDataType] ?? selectedDataType)
        : '資料'; // Fallback display name

    Widget content;
    final placeholderColor =
        themeData.colorScheme.onSurface.withAlpha((0.5 * 255).round());

    if (isLoading) {
      content = Center(
          child:
              CircularProgressIndicator(color: themeData.colorScheme.primary));
    } else if (data == null) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('請選擇資料集以載入$dataTypeDisplayName。',
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (data is List && data.isEmpty) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
            _searchController.text.isEmpty
                ? '此資料集下沒有$dataTypeDisplayName。'
                : '沒有符合搜尋條件的$dataTypeDisplayName。',
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (data is List) {
      // 主要處理 List<String>
      content = _buildListDisplay(themeData, data);
    } else {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text("無法顯示資料",
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: themeData.colorScheme.error)),
      ));
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      color: themeData.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(title,
                style: themeData.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          Divider(height: 1, thickness: 1, color: themeData.dividerColor),
          Expanded(child: content),
        ],
      ),
    );
  }

  // 簡化 _buildListDisplay 以處理 List<String>
  Widget _buildListDisplay(ThemeData themeData, List<dynamic> dataList) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        if (item is String) {
          return Card(
            elevation: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
            color: themeData.colorScheme.surfaceContainerHighest.withAlpha(180),
            child: ListTile(
              visualDensity: VisualDensity.compact,
              title: Text(item, style: themeData.textTheme.titleSmall),
            ),
          );
        }
        // Fallback for any non-string items in the list (should ideally not happen)
        return ListTile(
            visualDensity: VisualDensity.compact,
            title: Text("非預期項目: ${item.toString()}",
                style: themeData.textTheme.bodyMedium));
      },
    );
  }

  // 簡化 _buildDiffItemCard 以顯示單個字串
  Widget _buildDiffItemCard(
      ThemeData themeData, Map<String, dynamic> item, String type) {
    // item is expected to be {'value': 'the-string-value'}
    final Color cardColor;
    final Color iconColor;
    final Color textColor;
    final IconData icon;

    final colorScheme = themeData.colorScheme;

    if (type == '新增') {
      cardColor = colorScheme.tertiaryContainer.withAlpha(150);
      iconColor = colorScheme.tertiary;
      textColor = colorScheme.onTertiaryContainer;
      icon = Icons.add_circle_outline;
    } else {
      // '移除'
      cardColor = colorScheme.errorContainer.withAlpha(150);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.remove_circle_outline;
    }

    String title = item['value']?.toString() ?? 'N/A';

    return Card(
      elevation: 0.2,
      color: cardColor,
      child: ListTile(
        contentPadding: const EdgeInsetsGeometry.only(left: 2.0, right: 2.0),
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: iconColor, size: 18),
        title: Text(title,
            style: themeData.textTheme.bodyMedium?.copyWith(color: textColor)),
      ),
    );
  }

  // _buildModifiedItemCard 已被移除

  Widget _buildComparisonPanel(ThemeData themeData) {
    String dataTypeDisplayName = "項目"; // 簡化顯示名稱
    themeData.colorScheme.onSurface.withAlpha((0.5 * 255).round());
    final colorScheme = themeData.colorScheme;
    final placeholderColor =
        themeData.colorScheme.onSurface.withAlpha((0.5 * 255).round());

    Widget content;

    if (_selectedTimestamp1 == null || _selectedTimestamp2 == null) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text('請選擇兩個資料集以進行比較。',
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (_isLoadingData1 || _isLoadingData2) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text('資料載入中，請稍候...',
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (_comparisonResult == null) {
      content = Center(
          child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
            (_filteredData1 != null && _filteredData2 != null)
                ? '正在準備比較結果或無明顯差異...'
                : '比較結果將顯示於此。',
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (_comparisonResult!['general_diff'] != null) {
      // 通用差異仍然可以作為回退
      content = Center(
        child: Text(
          _comparisonResult!['general_diff']![0]['message'].toString(),
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.secondary),
        ),
      );
    } else {
      // 僅處理 added 和 removed
      final added = _comparisonResult!['added']!;
      final removed = _comparisonResult!['removed']!;

      if (added.isEmpty && removed.isEmpty) {
        content = Center(
            child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text('兩個資料集之間沒有差異。',
              textAlign: TextAlign.center,
              style: themeData.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.primary)),
        ));
      } else {
        List<Widget> diffWidgets = [];
        if (added.isNotEmpty) {
          diffWidgets.add(Text('新增的$dataTypeDisplayName (僅於資料集2):',
              textAlign: TextAlign.center,
              style: themeData.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.tertiary)));
          for (var item in added) {
            diffWidgets.add(_buildDiffItemCard(themeData, item, '新增'));
          }
          diffWidgets.add(const SizedBox(height: 4));
        }
        if (removed.isNotEmpty) {
          diffWidgets.add(
            Text('移除的$dataTypeDisplayName (僅於資料集1):',
                textAlign: TextAlign.center,
                style: themeData.textTheme.labelLarge
                    ?.copyWith(color: colorScheme.error)),
          );
          for (var item in removed) {
            diffWidgets.add(_buildDiffItemCard(themeData, item, '移除'));
          }
          diffWidgets.add(const SizedBox(height: 4));
        }
        // "modified" 部分已移除
        content = ListView(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            children: diffWidgets);
      }
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      color: themeData.cardColor,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (ThemeData themeData) {
        final bool canSelectTimestamps =
            _selectedCompany != null && _selectedDataType != null;
        final colorScheme = themeData.colorScheme;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                style: themeData.textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  labelText: '搜尋已載入資料',
                  labelStyle: themeData.textTheme.labelMedium,
                  hintText: '輸入關鍵字...',
                  hintStyle: themeData.textTheme.bodySmall
                      ?.copyWith(color: themeData.hintColor),
                  prefixIcon: Icon(Icons.search,
                      color: themeData.colorScheme.primary, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: themeData.colorScheme.onSurfaceVariant),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 6),
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
                  const SizedBox(width: 6),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildDropdown<String>(
                    themeData: themeData,
                    hintText: '資料集 1',
                    value: _selectedTimestamp1,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 1),
                    isLoading: _isLoadingTimestamps,
                    loadingText: "載入資料集...",
                    enabled: canSelectTimestamps,
                  ),
                  const SizedBox(width: 6),
                  _buildDropdown<String>(
                    themeData: themeData,
                    hintText: '資料集 2',
                    value: _selectedTimestamp2,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 2),
                    isLoading: _isLoadingTimestamps,
                    loadingText: "載入資料集...",
                    enabled: canSelectTimestamps,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(_error!,
                      style: themeData.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildDataPanel(
                        themeData: themeData,
                        title: "資料集 1: ${_selectedTimestamp1 ?? '未選'}",
                        data: _filteredData1,
                        isLoading: _isLoadingData1,
                        selectedDataType: _selectedDataType,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: _buildDataPanel(
                        themeData: themeData,
                        title: "資料集 2: ${_selectedTimestamp2 ?? '未選'}",
                        data: _filteredData2,
                        isLoading: _isLoadingData2,
                        selectedDataType: _selectedDataType,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.compare_arrows,
                                    size: 18, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text("差異比對",
                                    textAlign: TextAlign.center,
                                    style: themeData.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Divider(
                            thickness: 1,
                            height: 1,
                            color: themeData.dividerColor,
                          ),
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
