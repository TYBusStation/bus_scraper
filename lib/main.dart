import 'package:bus_scraper/pages/main_page.dart';
import 'package:bus_scraper/static.dart';
import 'package:bus_scraper/widgets/theme_provider.dart';
import 'package:flutter/material.dart';

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
    return ThemeProvider(
      builder: (themeData) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BusScraper',
        theme: themeData,
        home: const MainPage(),
      ),
    );
  }
}
