import 'package:bus_scraper/data/bus_route.dart';
import 'package:bus_scraper/widgets/ebus_btn.dart';
import 'package:flutter/material.dart';

import '../static.dart';
import '../widgets/theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController scrollController =
      ScrollController(keepScrollOffset: false);
  late List<BusRoute> routes;

  void modifyRoutes() {
    String text = textEditingController.text
        .replaceAll(Static.letterNumber, "")
        .toUpperCase();
    print(textEditingController.text.replaceAll(Static.letterNumber, ""));
    setState(() => routes = Static.routeData
        .where((route) =>
            route.name
                .replaceAll(Static.letterNumber, "")
                .toUpperCase()
                .contains(text) ||
            route.description
                .replaceAll(Static.letterNumber, "")
                .toUpperCase()
                .contains(text) ||
            route.id
                .replaceAll(Static.letterNumber, "")
                .toUpperCase()
                .contains(text))
        .toList()
      ..sort((a, b) {
        if (a.name.startsWith(RegExp(r'[^0-9]')) ||
            b.name.startsWith(RegExp(r'[^0-9]'))) {
          return a.name.compareTo(b.name);
        }
        String aNum = a.name.replaceAll(RegExp(r'[^0-9]'), '');
        String bNum = b.name.replaceAll(RegExp(r'[^0-9]'), '');
        if (aNum == bNum) {
          return a.name.compareTo(b.name);
        }
        return aNum.compareTo(bNum);
      }));
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  @override
  void initState() {
    super.initState();
    modifyRoutes();
  }

  @override
  void dispose() {
    super.dispose();
    textEditingController.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) => Column(
        children: [
          Container(
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
                  color: routes.isEmpty
                      ? themeData.colorScheme.error
                      : themeData.colorScheme.primary,
                ),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.only(left: 5, right: 5, bottom: 5),
                    child: TextField(
                      onChanged: (text) => modifyRoutes(),
                      style: TextStyle(
                          color: routes.isEmpty
                              ? themeData.colorScheme.error
                              : themeData.colorScheme.onSurface),
                      cursorColor: routes.isEmpty
                          ? themeData.colorScheme.error
                          : themeData.unselectedWidgetColor,
                      controller: textEditingController,
                      decoration: InputDecoration(
                        hintText: "搜尋路線名稱",
                        isDense: true,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: routes.isEmpty
                                  ? themeData.colorScheme.error
                                  : themeData.unselectedWidgetColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: routes.isEmpty
                                  ? themeData.colorScheme.error
                                  : themeData.colorScheme.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "清除搜尋",
                  icon: const Icon(Icons.clear),
                  color: themeData.colorScheme.primary,
                  onPressed: () {
                    if (textEditingController.text.isEmpty) {
                      return;
                    }
                    textEditingController.clear();
                    modifyRoutes();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (routes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 100, color: themeData.colorScheme.primary),
                        const SizedBox(height: 10),
                        const Text(
                          "找不到符合的路線",
                          style: TextStyle(
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  itemCount: routes.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(
                      routes[index].name,
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      "${routes[index].description}\n編號：${routes[index].id}",
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    trailing: EbusBtn(
                      id: routes[index].id,
                    ),
                  ),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 5),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
