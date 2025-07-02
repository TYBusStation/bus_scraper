import 'package:bus_scraper/pages/info_page.dart';
import 'package:bus_scraper/pages/main_page.dart';
import 'package:bus_scraper/static.dart';
import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:bus_scraper/widgets/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppLoader());
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  late Future<void> _initFuture;
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initFuture = Static.init();
  }

  // [MODIFIED] 讓此方法接收一個 context 參數
  void _handleTap(BuildContext scaffoldContext) {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inSeconds > 1) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;

      // [MODIFIED] 使用傳入的 scaffoldContext，這是有效的 context
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(
          content: const Text('已強制切換 API 伺服器，正在重新載入...'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _initFuture = Static.forceSwitchApiAndReInit();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            debugShowCheckedModeBanner: false,
            home: Builder(
              // 使用 Builder 來獲取 MaterialApp 內部的 context
              builder: (materialAppContext) {
                return Scaffold(
                  body: GestureDetector(
                    // [MODIFIED] 在 onTap 中傳入有效的 materialAppContext
                    onTap: () => _handleTap(materialAppContext),
                    behavior: HitTestBehavior.opaque,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            '資料載入中，請稍候...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        // [MODIFIED] 錯誤頁面也需要同樣的處理
        if (snapshot.hasError) {
          Static.log(snapshot.error.toString());
          final themeData = ThemeData.dark(useMaterial3: true);
          return MaterialApp(
            title: 'BusScraper',
            theme: themeData,
            debugShowCheckedModeBanner: false,
            home: Builder(// 同樣使用 Builder
                builder: (materialAppContext) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text("BusScraper"),
                ),
                // 將 GestureDetector 包裹在 SingleChildScrollView 之外
                body: GestureDetector(
                  onTap: () => _handleTap(materialAppContext),
                  behavior: HitTestBehavior.opaque,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              "初始化失敗：\n${snapshot.error}",
                              style:
                                  themeData.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "請嘗試重新開啟程式\n\n如仍有任何問題請聯繫作者",
                              style:
                                  themeData.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: List.generate(contactItems.length,
                                      (index) {
                                    final item = contactItems[index];
                                    return Column(
                                      children: [
                                        ListTile(
                                          leading: FaIcon(
                                            item.icon,
                                            size: 28,
                                            color:
                                                themeData.colorScheme.primary,
                                          ),
                                          title: Text(
                                            item.title,
                                            style:
                                                themeData.textTheme.titleMedium,
                                          ),
                                          trailing: OutlinedButton(
                                            onPressed: () async =>
                                                await launchUrl(
                                                    Uri.parse(item.url)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: themeData
                                                      .colorScheme.primary),
                                            ),
                                            child: const Text("前往"),
                                          ),
                                          onTap: () async => await launchUrl(
                                              Uri.parse(item.url)),
                                        ),
                                        if (index < contactItems.length - 1)
                                          const Divider(
                                              indent: 20,
                                              endIndent: 20,
                                              height: 1),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }

        return const App();
      },
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeChangeNotifier(Static.localStorage.appTheme),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesNotifier(Static.localStorage.favoritePlates),
        ),
      ],
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
