import 'package:flutter/material.dart';

import '../data/car.dart';
import '../static.dart';
import '../widgets/theme_provider.dart';
import 'history_page.dart';

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  final TextEditingController textEditingController = TextEditingController();
  final ScrollController scrollController =
      ScrollController(keepScrollOffset: false);
  late List<Car> cars;

  void modifyCars() {
    setState(() => cars = Static.carData
        .where((car) => car.plate
            .replaceAll(Static.letterNumber, "")
            .toUpperCase()
            .contains(textEditingController.text
                .replaceAll(Static.letterNumber, "")
                .toUpperCase()))
        .toList()
      ..sort((a, b) => a.plate.compareTo(b.plate)));
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  @override
  void initState() {
    super.initState();
    modifyCars();
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
                  color: cars.isEmpty
                      ? themeData.colorScheme.error
                      : themeData.colorScheme.primary,
                ),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.only(left: 5, right: 5, bottom: 5),
                    child: TextField(
                      onChanged: (text) => modifyCars(),
                      style: TextStyle(
                          color: cars.isEmpty
                              ? themeData.colorScheme.error
                              : themeData.colorScheme.onSurface),
                      cursorColor: cars.isEmpty
                          ? themeData.colorScheme.error
                          : themeData.unselectedWidgetColor,
                      controller: textEditingController,
                      decoration: InputDecoration(
                        hintText: "搜尋車牌",
                        isDense: true,
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: cars.isEmpty
                                  ? themeData.colorScheme.error
                                  : themeData.unselectedWidgetColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: cars.isEmpty
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
                    modifyCars();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (cars.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 100, color: themeData.colorScheme.primary),
                        const SizedBox(height: 10),
                        const Text(
                          "找不到符合的車牌\n或車牌尚未被記錄",
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
                  itemCount: cars.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(
                      cars[index].plate,
                      style: const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      cars[index].type.chinese,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                HistoryPage(plate: cars[index].plate),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(10)),
                      child: const Text('歷史位置', style: TextStyle(fontSize: 16)),
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
