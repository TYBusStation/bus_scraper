import 'package:bus_scraper/pages/main_page.dart';
import 'package:bus_scraper/static.dart';
import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:bus_scraper/widgets/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Static.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 提供者 1: 用於主題管理
        ChangeNotifierProvider(
          create: (_) => ThemeChangeNotifier(Static.localStorage.appTheme),
        ),
        // 提供者 2: 用於收藏管理
        ChangeNotifierProvider(
          create: (_) => FavoritesNotifier(Static.localStorage.favoritePlates),
        ),
      ],
      // *** 核心修改：直接在 MultiProvider 的 child 中使用 Consumer ***
      // 這樣可以完全取代原有的 ThemeProvider widget，讓結構更扁平化。
      child: ThemeProvider(
        builder: (BuildContext context, ThemeData themeData) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'BusScraper',
          theme: themeData,
          home: const MainPage(),
        ),
      ),
    );
  }
}
