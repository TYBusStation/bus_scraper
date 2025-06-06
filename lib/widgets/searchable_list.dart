import 'package:flutter/material.dart';

// 假設你的 ThemeProvider 在這裡
// import 'theme_provider.dart';

/// 一個通用的、可搜尋的列表頁面元件。
///
/// 這個 StatefulWidget 封裝了搜尋框、列表顯示、空狀態和相關的邏輯，
/// 透過泛型 <T> 和回呼函式來適應不同的資料類型和需求。
class SearchableList<T> extends StatefulWidget {
  /// 原始的、未過濾的完整資料列表。
  final List<T> allItems;

  /// 用於搜尋框的提示文字。
  final String searchHintText;

  /// 過濾條件函式。根據使用者輸入的文字，判斷某個項目是否應被顯示。
  final bool Function(T item, String searchText) filterCondition;

  /// 建立列表中每個項目的 Widget。
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 當搜尋結果為空時，顯示的 Widget。
  final Widget emptyStateWidget;

  /// 用於排序過濾後列表的回呼函式。
  final int Function(T a, T b) sortCallback;

  const SearchableList({
    super.key,
    required this.allItems,
    required this.searchHintText,
    required this.filterCondition,
    required this.itemBuilder,
    required this.emptyStateWidget,
    required this.sortCallback,
  });

  @override
  State<SearchableList<T>> createState() => _SearchableListState<T>();
}

class _SearchableListState<T> extends State<SearchableList<T>> {
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController scrollController =
      ScrollController(keepScrollOffset: false);

  /// 儲存過濾後的項目列表。
  late List<T> filteredItems;

  @override
  void initState() {
    super.initState();
    // 監聽文字變化
    textEditingController.addListener(_onSearchChanged);
    // 初始載入時，根據 widget.allItems 初始化 filteredItems
    filteredItems = _getFilteredAndSortedItems();
  }

  // ******************** 核心修正點 ********************
  /// 當父元件更新此 Widget 的屬性時會被呼叫。
  @override
  void didUpdateWidget(covariant SearchableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 比較新舊 allItems 是否不同。使用 identityHashCode 是為了高效比較列表實例本身，
    // 而不是比較列表內容，這樣更高效。
    if (widget.allItems != oldWidget.allItems) {
      // 如果資料來源已改變 (例如從我的最愛中移除一項)，
      // 則重新計算過濾後的列表並觸發 UI 更新。
      setState(() {
        filteredItems = _getFilteredAndSortedItems();
      });
    }
  }

  // ******************************************************

  @override
  void dispose() {
    // 移除監聽器並釋放資源，防止記憶體洩漏
    textEditingController.removeListener(_onSearchChanged);
    textEditingController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  /// 當搜尋框文字改變時的處理函式。
  void _onSearchChanged() {
    // 只需要更新 filteredItems 即可，不需要做其他判斷
    setState(() {
      filteredItems = _getFilteredAndSortedItems();
    });
    // 如果列表控制器已經附加到 ListView，則將滾動位置跳回頂部
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  /// 根據目前的 allItems 和搜尋文字，返回一個過濾和排序後的新列表。
  /// 這個方法不直接呼叫 setState，使其可以在多個地方重用。
  List<T> _getFilteredAndSortedItems() {
    final searchText = textEditingController.text;
    // 從最新的 widget.allItems 開始過濾和排序
    return widget.allItems
        .where((item) => widget.filterCondition(item, searchText))
        .toList()
      ..sort(widget.sortCallback);
  }

  @override
  Widget build(BuildContext context) {
    // 注意：我移除了 ThemeProvider，因為它通常在更高層級注入 (例如 MaterialApp)。
    // 如果您確實需要它在這裡，可以將其加回來。
    // build 方法會自動從 context 獲取主題。
    final ThemeData themeData = Theme.of(context);

    return Column(
      children: [
        // --- 搜尋框 UI ---
        _buildSearchBar(themeData),
        // --- 列表內容 ---
        Expanded(
          child: Builder(
            builder: (context) {
              // 如果過濾後列表為空，顯示空狀態 Widget
              if (filteredItems.isEmpty) {
                return widget.emptyStateWidget;
              }
              // 否則，顯示可滾動的列表
              return ListView.separated(
                controller: scrollController,
                itemCount: filteredItems.length,
                // 使用傳入的 itemBuilder 來建立每個列表項
                itemBuilder: (context, index) =>
                    widget.itemBuilder(context, filteredItems[index]),
                separatorBuilder: (context, index) => const Divider(height: 5),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 建立搜尋框 Widget。
  Widget _buildSearchBar(ThemeData themeData) {
    // 現在isEmpty的判斷直接基於最新的filteredItems狀態
    final bool isEmpty =
        filteredItems.isEmpty && textEditingController.text.isNotEmpty;
    final Color primaryColor = themeData.colorScheme.primary;
    final Color errorColor = themeData.colorScheme.error;

    return Container(
      decoration: BoxDecoration(
        color: themeData.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(25),
      ),
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.only(left: 10, right: 5),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: isEmpty ? errorColor : primaryColor,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 5, right: 5, bottom: 5),
              child: TextField(
                // onChanged 現在由 addListener 處理，這裡可以移除
                // onChanged: (text) => _onSearchChanged(),
                style: TextStyle(
                  color: isEmpty ? errorColor : themeData.colorScheme.onSurface,
                ),
                cursorColor:
                    isEmpty ? errorColor : themeData.unselectedWidgetColor,
                controller: textEditingController,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isEmpty
                          ? errorColor
                          : themeData.unselectedWidgetColor,
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isEmpty ? errorColor : primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: "清除搜尋",
            icon: const Icon(Icons.clear),
            color: primaryColor,
            onPressed: () {
              if (textEditingController.text.isEmpty) return;
              textEditingController.clear();
              // 清除文字時，addListener 會自動觸發 _onSearchChanged
            },
          ),
        ],
      ),
    );
  }
}
