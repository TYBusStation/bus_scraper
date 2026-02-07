import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SearchableList<T> extends StatefulWidget {
  final List<T> allItems;
  final String searchHintText;
  final bool Function(T item, String searchText) filterCondition;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget emptyStateWidget;
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

  late List<T> filteredItems;
  bool _isRegexError = false;

  @override
  void initState() {
    super.initState();
    textEditingController.addListener(_onSearchChanged);
    filteredItems = _getFilteredAndSortedItems();
  }

  @override
  void didUpdateWidget(covariant SearchableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allItems != oldWidget.allItems ||
        !listEquals(widget.allItems, oldWidget.allItems)) {
      setState(() {
        filteredItems = _getFilteredAndSortedItems();
      });
    }
  }

  @override
  void dispose() {
    textEditingController.removeListener(_onSearchChanged);
    textEditingController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      filteredItems = _getFilteredAndSortedItems();
    });
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  List<T> _getFilteredAndSortedItems() {
    final searchText = textEditingController.text.trim();
    if (searchText.isEmpty) {
      _isRegexError = false;
      return List.from(widget.allItems)..sort(widget.sortCallback);
    }

    final tokens = searchText.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    bool hasError = false;
    for (var token in tokens) {
      try {
        RegExp(token);
      } catch (_) {
        hasError = true;
        break;
      }
    }
    _isRegexError = hasError;

    return widget.allItems
        .where((item) => widget.filterCondition(item, searchText))
        .toList()
      ..sort(widget.sortCallback);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);

    return Column(
      children: [
        _buildSearchBar(themeData),
        Expanded(
          child: Builder(
            builder: (context) {
              if (filteredItems.isEmpty) {
                return widget.emptyStateWidget;
              }
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) =>
                    widget.itemBuilder(context, filteredItems[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData themeData) {
    final bool isInputInvalid = _isRegexError;
    final bool noResults =
        filteredItems.isEmpty && textEditingController.text.isNotEmpty;
    final bool showError = isInputInvalid || noResults;

    final Color primaryColor = themeData.colorScheme.primary;
    final Color errorColor = themeData.colorScheme.error;

    return Container(
      decoration: BoxDecoration(
        color: themeData.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(25),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: showError ? errorColor : primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: TextStyle(
                fontSize: 14,
                color: showError ? errorColor : themeData.colorScheme.onSurface,
              ),
              cursorColor:
                  showError ? errorColor : themeData.unselectedWidgetColor,
              controller: textEditingController,
              decoration: InputDecoration(
                hintText: widget.searchHintText,
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 4),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                suffixText: _isRegexError ? "Regex 語法錯誤 " : null,
                suffixStyle: TextStyle(color: errorColor, fontSize: 10),
              ),
            ),
          ),
          IconButton(
            tooltip: "清除搜尋",
            icon: const Icon(Icons.clear, size: 20),
            color: primaryColor,
            onPressed: () {
              if (textEditingController.text.isEmpty) return;
              textEditingController.clear();
            },
          ),
        ],
      ),
    );
  }
}
