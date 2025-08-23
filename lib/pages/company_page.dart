import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/company.dart';
import '../static.dart';
import '../widgets/theme_provider.dart';

// --- 通用的彈出式選擇對話框 (已新增搜尋框) ---
class SelectionDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? initialValue;
  final String Function(T item) itemBuilder;

  const SelectionDialog({
    super.key,
    required this.title,
    required this.items,
    this.initialValue,
    required this.itemBuilder,
  });

  @override
  State<SelectionDialog<T>> createState() => _SelectionDialogState<T>();
}

class _SelectionDialogState<T> extends State<SelectionDialog<T>> {
  late final TextEditingController _searchController;
  late List<T> _filteredItems;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = widget.items; // 初始顯示所有項目
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          // 使用傳入的 itemBuilder 來取得每個項目的字串表示以進行搜尋
          return widget.itemBuilder(item).toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title, style: themeData.textTheme.titleLarge),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        // 使用 Column 來放置搜尋框和列表
        child: Column(
          children: [
            // --- 搜尋框 ---
            TextField(
              controller: _searchController,
              autofocus: false, // 自動獲取焦點
              style: themeData.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: '搜尋...',
                hintStyle: themeData.textTheme.bodySmall
                    ?.copyWith(color: themeData.hintColor),
                prefixIcon: Icon(Icons.search,
                    color: themeData.colorScheme.primary, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
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
            const SizedBox(height: 12),
            // --- 項目列表 ---
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child:
                          Text('沒有符合的項目', style: themeData.textTheme.bodySmall))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return ListTile(
                          title: Text(widget.itemBuilder(item),
                              overflow: TextOverflow.ellipsis),
                          selected: item == widget.initialValue,
                          selectedTileColor:
                              themeData.colorScheme.primary.withOpacity(0.1),
                          onTap: () {
                            Navigator.of(context).pop(item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // 返回 null
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  // --- 狀態變數 ---
  List<Company> _companies = [];
  Company? _selectedCompany;

  final List<String> _dataTypes = ['cars', 'drivers'];
  final Map<String, String> _dataTypeDisplayNames = {
    'cars': '車輛',
    'drivers': '駕駛員'
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
  final Map<String, dynamic> _cache = <String, dynamic>{};
  static const String _companiesCacheKey = 'companies_list';

  String _getTimestampsCacheKey(String companyCode, String dataType) =>
      'timestamps_${companyCode}_$dataType';

  String _getDataCacheKey(
          String companyCode, String dataType, String timestamp) =>
      'data_${companyCode}_${dataType}_$timestamp';

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
          // 如果成功載入但列表為空，也給予提示
          if (_timestamps.isEmpty) {
            _error = "此類型下沒有可用的資料集。";
          }
        });
      } else {
        throw Exception(
            '無法載入資料集: ${response.statusCode} - ${response.data?['detail'] ?? response.statusMessage}');
      }
    } catch (e) {
      // --- 修改開始 ---
      String errorMessage = '載入資料集時發生錯誤: $e';
      // 判斷是否為 DioException 且狀態碼為 404
      if (e is DioException && e.response?.statusCode == 404) {
        final String dataTypeDisplayName =
            _dataTypeDisplayNames[_selectedDataType!] ?? _selectedDataType!;
        errorMessage = '無此資料類型 ($dataTypeDisplayName) 的資料集。';
      }
      setState(() {
        _error = errorMessage;
        _timestamps = []; // 確保時間戳列表為空
      });
      // --- 修改結束 ---
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
      // --- 修改開始 ---
      String errorMessage = '載入資料集 $target 時發生錯誤: $e';
      // 判斷是否為 DioException 且狀態碼為 404
      if (e is DioException && e.response?.statusCode == 404) {
        errorMessage = '資料集檔案不存在或已移除 (404 Not Found)。';
      }
      setState(() {
        _error = errorMessage;
      });
      // --- 修改結束 ---
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
    if (mounted) setState(() {});
  }

  dynamic _filterSingleData(dynamic fetchedData, String query) {
    if (fetchedData == null) return null;
    if (query.isEmpty) return fetchedData;

    if (fetchedData is List) {
      return fetchedData.where((item) {
        if (item is String) {
          return item.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }
    return fetchedData;
  }

  void _performComparison() {
    if (_filteredData1 == null || _filteredData2 == null) {
      if (mounted) setState(() => _comparisonResult = null);
      return;
    }

    if (_filteredData1 is List &&
        (_filteredData1.isEmpty || _filteredData1.first is String) &&
        _filteredData2 is List &&
        (_filteredData2.isEmpty || _filteredData2.first is String)) {
      final List<String> list1 = List<String>.from(_filteredData1 as List);
      final List<String> list2 = List<String>.from(_filteredData2 as List);

      final counts1 = <String, int>{};
      for (final item in list1) {
        counts1[item] = (counts1[item] ?? 0) + 1;
      }

      final counts2 = <String, int>{};
      for (final item in list2) {
        counts2[item] = (counts2[item] ?? 0) + 1;
      }

      final added = <Map<String, dynamic>>[];
      final removed = <Map<String, dynamic>>[];
      final allKeys = (counts1.keys.toSet())..addAll(counts2.keys);

      for (final key in allKeys) {
        final count1 = counts1[key] ?? 0;
        final count2 = counts2[key] ?? 0;
        final diff = count2 - count1;

        if (diff > 0) {
          added.add({'value': key, 'count': diff});
        } else if (diff < 0) {
          removed.add({'value': key, 'count': -diff});
        }
      }

      if (mounted) {
        setState(() {
          _comparisonResult = {
            'added': added,
            'removed': removed,
            'modified': [],
          };
          _error = null;
        });
      }
    } else {
      if (!const DeepCollectionEquality()
          .equals(_filteredData1, _filteredData2)) {
        if (mounted) {
          setState(() {
            _comparisonResult = {
              'general_diff': [
                {'message': '資料內容不同，或資料格式非預期的純字串列表。'}
              ],
              'added': [],
              'removed': [],
              'modified': [],
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

  String _generateComparisonTextForClipboard() {
    if (_comparisonResult == null) {
      return "沒有可複製的比較結果。";
    }

    final buffer = StringBuffer();
    final String dataTypeDisplayName =
        _dataTypeDisplayNames[_selectedDataType] ?? '項目';

    buffer.writeln(
        "--- 差異比對結果 (${_selectedCompany?.name ?? '未知公司'} / $dataTypeDisplayName) ---");
    buffer.writeln("資料集 1: ${_selectedTimestamp1 ?? 'N/A'}");
    buffer.writeln(
        '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!.code}/$_selectedDataType/$_selectedTimestamp1');
    buffer.writeln('資料集 2: ${_selectedTimestamp2 ?? 'N/A'}');
    buffer.writeln(
        '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!.code}/$_selectedDataType/$_selectedTimestamp2');
    buffer.writeln("-" * 20);

    final added = _comparisonResult!['added']!;
    final removed = _comparisonResult!['removed']!;

    if (added.isEmpty && removed.isEmpty) {
      buffer.writeln("兩個資料集之間沒有差異。");
    } else {
      if (added.isNotEmpty) {
        final totalAdded = added.fold<int>(
            0, (sum, item) => sum + (item['count'] as int? ?? 0));
        buffer.writeln("\n[新增的項目 (共 $totalAdded 筆)]");
        final addedItemsText =
            added.map((item) => item['value'] as String).join(', ');
        buffer.writeln(addedItemsText);
      }
      if (removed.isNotEmpty) {
        final totalRemoved = removed.fold<int>(
            0, (sum, item) => sum + (item['count'] as int? ?? 0));
        buffer.writeln("\n[移除的項目 (共 $totalRemoved 筆)]");
        final removedItemsText =
            removed.map((item) => item['value'] as String).join(', ');
        buffer.writeln(removedItemsText);
      }
    }
    return buffer.toString();
  }

  Future<void> _copyComparisonResult() async {
    if (!mounted) return;
    if (_comparisonResult == null ||
        (_comparisonResult!['added']!.isEmpty &&
            _comparisonResult!['removed']!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('沒有可複製的差異內容。'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final comparisonText = _generateComparisonTextForClipboard();
    await Clipboard.setData(ClipboardData(text: comparisonText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('比較結果已複製到剪貼簿！'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyDataLink(String? timestamp, String panelName) async {
    if (timestamp == null ||
        _selectedCompany == null ||
        _selectedDataType == null) {
      return;
    }
    if (!mounted) return;

    final url =
        '${Static.apiBaseUrl}/company_data/file/${_selectedCompany!.code}/$_selectedDataType/$timestamp';

    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$panelName 的資料連結已複製！'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Widget 建構方法 ---

  Widget _buildSelectionButton<T>({
    required BuildContext context,
    required ThemeData themeData,
    required String hintText,
    required String dialogTitle,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isLoading,
    String? loadingText,
    required String Function(T item) itemToString,
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
                      strokeWidth: 2, color: themeData.colorScheme.primary)),
              const SizedBox(width: 8),
              Text(loadingText ?? "載入中...",
                  style: themeData.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final bool isEnabled = enabled && items.isNotEmpty;
    final String currentText = value != null ? itemToString(value) : hintText;
    final Color textColor = value != null
        ? themeData.textTheme.bodyMedium!.color!
        : themeData.hintColor;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            side: BorderSide(
                color: themeData.colorScheme.outline.withOpacity(0.5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            backgroundColor: !isEnabled
                ? themeData.disabledColor.withAlpha((0.1 * 255).round())
                : null,
          ),
          onPressed: !isEnabled
              ? null
              : () async {
                  // 注意：這裡現在調用的是我們修改後的 SelectionDialog
                  final selectedValue = await showDialog<T>(
                    context: context,
                    builder: (BuildContext context) => SelectionDialog<T>(
                      title: dialogTitle,
                      items: items,
                      initialValue: value,
                      itemBuilder: itemToString,
                    ),
                  );
                  // 處理返回的結果
                  if (selectedValue != null) {
                    onChanged(selectedValue);
                  }
                },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentText,
                  style: themeData.textTheme.bodyMedium
                      ?.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: isEnabled
                    ? themeData.colorScheme.onSurfaceVariant
                    : themeData.disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataPanel({
    required ThemeData themeData,
    required int panelIndex,
    required dynamic data,
    required bool isLoading,
    required String? selectedDataType,
  }) {
    final String? selectedTimestamp =
        (panelIndex == 1) ? _selectedTimestamp1 : _selectedTimestamp2;
    final String titleText = "資料集 $panelIndex:";
    final String timestampText = selectedTimestamp ?? '未選';
    String countText = '';
    if (data is List) {
      countText = ' (筆數: ${data.length})';
    }

    String dataTypeDisplayName = selectedDataType != null
        ? (_dataTypeDisplayNames[selectedDataType] ?? selectedDataType)
        : '資料';

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
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 40, 6),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: themeData.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(text: '$titleText$countText\n'),
                      TextSpan(
                        text: timestampText,
                        style: themeData.textTheme.bodySmall?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 4,
                bottom: 0,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.link,
                      size: 16, color: themeData.colorScheme.primary),
                  tooltip: '複製資料連結',
                  onPressed: selectedTimestamp == null
                      ? null
                      : () =>
                          _copyDataLink(selectedTimestamp, '資料集 $panelIndex'),
                ),
              ),
            ],
          ),
          Divider(height: 1, thickness: 1, color: themeData.dividerColor),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildListDisplay(ThemeData themeData, List<dynamic> dataList) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final item = dataList[index];
        if (item is String) {
          return Card(
            elevation: 0.5,
            margin: const EdgeInsets.all(4.0),
            color: themeData.colorScheme.surfaceContainerHighest.withAlpha(180),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(item, style: themeData.textTheme.bodySmall),
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
      cardColor = colorScheme.tertiary.withAlpha(150);
      iconColor = colorScheme.tertiary;
      textColor = colorScheme.onTertiaryContainer;
      icon = Icons.add_circle_outline;
    } else {
      cardColor = colorScheme.errorContainer.withAlpha(150);
      iconColor = colorScheme.error;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.remove_circle_outline;
    }

    final String title = item['value'] as String? ?? 'N/A';
    final int count = item['count'] as int? ?? 1;
    final String displayText = count > 1 ? '$title (數量: $count)' : title;

    return Card(
      elevation: 0.2,
      color: cardColor,
      margin: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          Expanded(
            child: Text(
              displayText,
              style: themeData.textTheme.bodySmall?.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPanel(ThemeData themeData) {
    String dataTypeDisplayName = "項目";
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
                ? '正在準備比較結果...'
                : '比較結果將顯示於此。',
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodySmall
                ?.copyWith(color: placeholderColor)),
      ));
    } else if (_comparisonResult!['general_diff'] != null) {
      content = Center(
        child: Text(
          _comparisonResult!['general_diff']![0]['message'].toString(),
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.secondary),
        ),
      );
    } else {
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
          final totalAdded = added.fold<int>(
              0, (sum, item) => sum + (item['count'] as int? ?? 0));
          diffWidgets.add(Text('新增的$dataTypeDisplayName (共 $totalAdded 筆):',
              textAlign: TextAlign.center,
              style: themeData.textTheme.labelLarge
                  ?.copyWith(color: colorScheme.tertiary)));
          for (var item in added) {
            diffWidgets.add(_buildDiffItemCard(themeData, item, '新增'));
          }
          diffWidgets.add(const SizedBox(height: 4));
        }
        if (removed.isNotEmpty) {
          final totalRemoved = removed.fold<int>(
              0, (sum, item) => sum + (item['count'] as int? ?? 0));
          diffWidgets.add(
            Text('移除的$dataTypeDisplayName (共 $totalRemoved 筆):',
                textAlign: TextAlign.center,
                style: themeData.textTheme.labelLarge
                    ?.copyWith(color: colorScheme.error)),
          );
          for (var item in removed) {
            diffWidgets.add(_buildDiffItemCard(themeData, item, '移除'));
          }
          diffWidgets.add(const SizedBox(height: 4));
        }
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
      builder: (BuildContext context, ThemeData themeData) {
        final bool canSelectTimestamps =
            _selectedCompany != null && _selectedDataType != null;
        final colorScheme = themeData.colorScheme;
        final bool canCopyComparison = _comparisonResult != null &&
            (_comparisonResult!['added']!.isNotEmpty ||
                _comparisonResult!['removed']!.isNotEmpty);

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
                  _buildSelectionButton<Company>(
                    context: context,
                    themeData: themeData,
                    hintText: '選擇公司',
                    dialogTitle: '選擇公司',
                    value: _selectedCompany,
                    items: _companies,
                    onChanged: _onCompanyChanged,
                    isLoading: _isLoadingCompanies,
                    loadingText: "載入公司...",
                    itemToString: (Company c) => "${c.name} (${c.code})",
                  ),
                  const SizedBox(width: 6),
                  _buildSelectionButton<String>(
                    context: context,
                    themeData: themeData,
                    hintText: '選擇資料類型',
                    dialogTitle: '選擇資料類型',
                    value: _selectedDataType,
                    items: _dataTypes,
                    onChanged: _onDataTypeChanged,
                    isLoading: false,
                    itemToString: (String s) => _dataTypeDisplayNames[s] ?? s,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildSelectionButton<String>(
                    context: context,
                    themeData: themeData,
                    hintText: '資料集 1',
                    dialogTitle: '選擇資料集 1',
                    value: _selectedTimestamp1,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 1),
                    isLoading: _isLoadingTimestamps,
                    loadingText: "載入資料集...",
                    enabled: canSelectTimestamps,
                    itemToString: (String s) => s,
                  ),
                  const SizedBox(width: 6),
                  _buildSelectionButton<String>(
                    context: context,
                    themeData: themeData,
                    hintText: '資料集 2',
                    dialogTitle: '選擇資料集 2',
                    value: _selectedTimestamp2,
                    items: _timestamps,
                    onChanged: (val) => _onTimestampChanged(val, 2),
                    isLoading: _isLoadingTimestamps,
                    loadingText: "載入資料集...",
                    enabled: canSelectTimestamps,
                    itemToString: (String s) => s,
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
                        panelIndex: 1,
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
                        panelIndex: 2,
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
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 2),
                                Icon(Icons.compare_arrows,
                                    size: 18, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text("差異比對",
                                    textAlign: TextAlign.center,
                                    style: themeData.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const Spacer(flex: 1),
                                IconButton(
                                  icon: Icon(Icons.content_copy,
                                      size: 16, color: colorScheme.primary),
                                  tooltip: '複製比較結果',
                                  onPressed: canCopyComparison
                                      ? _copyComparisonResult
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          Divider(
                              thickness: 1,
                              height: 1,
                              color: themeData.dividerColor),
                          Expanded(child: _buildComparisonPanel(themeData)),
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
