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
  // 確保 Flutter 綁定已初始化，這對於調用異步方法是必要的。
  WidgetsFlutterBinding.ensureInitialized();
  // 注意：這裡不再 await Static.init()。
  // 我們將這個 Future 交給 FutureBuilder 處理。
  runApp(const AppLoader());
}

// 新增 Widget：AppLoader
// 這個 Widget 的職責是處理應用的初始加載過程。
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 FutureBuilder 來監聽 Static.init() 的完成狀態
    return FutureBuilder(
      // future 屬性接收一個 Future。當這個 Future 完成時，builder 會被重新觸發。
      future: Static.init(),
      // builder 是一個函數，它根據 Future 的快照（snapshot）來構建 UI。
      builder: (context, snapshot) {
        // 1. 檢查 Future 是否仍在執行中 (等待中)
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 如果仍在加載，顯示一個加載畫面。
          // 我們需要一個 MaterialApp 來提供基本的佈局和主題支持。
          return MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 顯示一個圓形的進度指示器（等待動畫）
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    // 提示用戶正在加載
                    Text(
                      '資料載入中，請稍候...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 2. 檢查 Future 是否已完成，但發生了錯誤
        if (snapshot.hasError) {
          // 如果加載出錯，顯示一個錯誤訊息畫面。
          // 這在調試時非常有用。
          final themeData = ThemeData.dark(useMaterial3: true);
          return MaterialApp(
            title: 'BusScraper',
            theme: themeData,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              appBar: AppBar(
                title: const Text("BusScraper"),
              ),
              body: SingleChildScrollView(
                // 確保內容在較小螢幕上可以滾動
                padding: const EdgeInsets.all(20.0), // 設定整體內邊距
                child: Center(
                  // 水平置中 Column 的內容
                  child: ConstrainedBox(
                    // 在較大螢幕上限制內容的寬度
                    constraints: const BoxConstraints(maxWidth: 600),
                    // 最大寬度設為 600
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      // 主軸居中對齊 (垂直方向)
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // 交叉軸延展 (使按鈕等填滿寬度)
                      children: [
                        const SizedBox(height: 20), // 頂部間距
                        Text(
                          "初始化失敗：\n${snapshot.error}",
                          style: themeData.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "請嘗試重新開啟程式\n如仍有任何問題\n請聯繫作者",
                          style: themeData.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                          textAlign: TextAlign.center, // 文字置中對齊
                        ),
                        const SizedBox(height: 30), // 標題與卡片間的間距
                        Card(
                          elevation: 2, // 卡片陰影深度
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // 卡片圓角
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            // 卡片內部垂直方向的邊距
                            child: Column(
                              children:
                                  List.generate(contactItems.length, (index) {
                                final item = contactItems[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      leading: FaIcon(
                                        // 左側圖示
                                        item.icon,
                                        size: 28,
                                        color: themeData
                                            .colorScheme.primary, // 使用主題的主要顏色
                                      ),
                                      title: Text(
                                        // 標題文字
                                        item.title,
                                        style: themeData.textTheme.titleMedium,
                                      ),
                                      trailing: OutlinedButton(
                                        // 右側按鈕
                                        onPressed: () async => await launchUrl(
                                            Uri.parse(item.url)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: themeData.colorScheme
                                                  .primary), // 按鈕邊框顏色
                                        ),
                                        child: const Text("前往"),
                                      ),
                                      // 提示文字
                                      onTap: () async => await launchUrl(
                                          Uri.parse(
                                              item.url)), // 使整個 ListTile 可點擊
                                    ),
                                    if (index <
                                        contactItems.length - 1) // 如果不是最後一個項目
                                      const Divider(
                                          indent: 20, endIndent: 20, height: 1),
                                    // 加入分隔線
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20), // 底部間距
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 3. 如果 Future 成功完成且沒有錯誤
        // 則渲染主要的 App Widget。
        return const App();
      },
    );
  }
}

// 原始的 App Widget 保持不變。
// 它現在只會在 Static.init() 成功完成後被構建。
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 提供者 1: 用於主題管理
        ChangeNotifierProvider(
          // 此時 Static.localStorage 已經被初始化，所以可以安全訪問
          create: (_) => ThemeChangeNotifier(Static.localStorage.appTheme),
        ),
        // 提供者 2: 用於收藏管理
        ChangeNotifierProvider(
          // 此時 Static.localStorage 已經被初始化，所以可以安全訪問
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
