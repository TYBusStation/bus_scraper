import 'package:bus_scraper/pages/info_page.dart';
import 'package:bus_scraper/pages/main_page.dart';
import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:bus_scraper/utils/static.dart';
import 'package:bus_scraper/utils/version_check_service.dart';
import 'package:bus_scraper/utils/web_interop.dart'
    if (dart.library.html) 'package:bus_scraper/utils/web_interop_web.dart'
    if (dart.library.io) 'package:bus_scraper/utils/web_interop_stub.dart';
import 'package:bus_scraper/widgets/favorite_provider.dart';
import 'package:bus_scraper/widgets/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InitializationResult {
  final bool updateRequired;
  final Map<String, dynamic>? updateInfo;

  InitializationResult({this.updateRequired = false, this.updateInfo});
}

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
  InitializationResult? _initializationResult;
  Object? _error;
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getWebInterop().hideFlutterLoader();
      _startInitialization();
    });
  }

  Future<void> _startInitialization() async {
    try {
      final result = await _initializeApp();
      if (mounted) {
        setState(() {
          _initializationResult = result;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
      }
    }
  }

  Future<InitializationResult> _initializeApp() async {
    final versionService = VersionCheckService();
    if (await versionService.isUpdateRequired()) {
      final updateInfo = await versionService.getLatestVersionInfo();
      return InitializationResult(updateRequired: true, updateInfo: updateInfo);
    } else {
      await Static.init();
      return InitializationResult(updateRequired: false);
    }
  }

  void _forceReload() {
    setState(() {
      _initializationResult = null;
      _error = null;
    });
    Static.forceSwitchApiAndReInit().then((_) => _startInitialization());
  }

  void _handleTap(BuildContext scaffoldContext) {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inSeconds > 1) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTapTime = now;
    if (_tapCount >= 5) {
      _tapCount = 0;
      FormatterUtils.showSnackbar(scaffoldContext, '強制切換 API 伺服器中...');
      _forceReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      Static.log(_error.toString());
      final themeData = ThemeData.dark(useMaterial3: true);
      return MaterialApp(
        title: '桃園公車站動態追蹤',
        theme: themeData,
        debugShowCheckedModeBanner: false,
        home: Builder(builder: (materialAppContext) {
          return Scaffold(
            appBar: AppBar(title: const Text("桃園公車站動態追蹤")),
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
                          "初始化失敗：\n$_error",
                          style: themeData.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 28),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "請嘗試重新開啟程式\n\n如仍有任何問題請聯繫作者",
                          style: themeData.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold, fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children:
                                  List.generate(contactItems.length, (index) {
                                final item = contactItems[index];
                                return Column(
                                  children: [
                                    ListTile(
                                      leading: FaIcon(item.icon,
                                          size: 28,
                                          color: themeData.colorScheme.primary),
                                      title: Text(item.title,
                                          style:
                                              themeData.textTheme.titleMedium),
                                      trailing: OutlinedButton(
                                        onPressed: () async => await launchUrl(
                                            Uri.parse(item.url)),
                                        style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                                color: themeData
                                                    .colorScheme.primary)),
                                        child: const Text("前往"),
                                      ),
                                      onTap: () async =>
                                          await launchUrl(Uri.parse(item.url)),
                                    ),
                                    if (index < contactItems.length - 1)
                                      const Divider(
                                          indent: 20, endIndent: 20, height: 1),
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

    if (_initializationResult != null) {
      final result = _initializationResult!;
      if (result.updateRequired) {
        return MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          debugShowCheckedModeBanner: false,
          home: UpdatePage(updateInfo: result.updateInfo!),
        );
      } else {
        return const App();
      }
    }

    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (materialAppContext) {
          return Scaffold(
            body: GestureDetector(
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
}

class UpdatePage extends StatefulWidget {
  final Map<String, dynamic> updateInfo;

  const UpdatePage({super.key, required this.updateInfo});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _isDownloading = false;
  bool _isInitializingForSkip = false;
  double _progress = 0.0;
  String _statusText = '發現新版本，請立即更新。';

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _statusText = '下載中，請勿離開此頁面';
      _progress = 0.0;
    });
    try {
      final service = VersionCheckService();
      await service.downloadAndInstall(widget.updateInfo['url'], (progress) {
        setState(() {
          _progress = progress;
        });
      });
    } catch (e) {
      setState(() {
        _statusText = '更新失敗: $e\n請檢查您的網路連線與儲存空間權限。';
        _isDownloading = false;
      });
    }
  }

  Future<void> _skipUpdate() async {
    setState(() {
      _isInitializingForSkip = true;
      _statusText = '正在準備應用程式...';
    });
    try {
      await Static.init();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const App()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = '準備失敗: $e\n請嘗試重新啟動應用程式。';
          _isInitializingForSkip = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final String newVersion = widget.updateInfo['version'] ?? 'N/A';
    return Scaffold(
      appBar:
          AppBar(title: const Text('應用程式更新'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.system_update, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text('發現新版本: v$newVersion',
                  style: themeData.textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(_statusText,
                  style: themeData.textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              if (_isDownloading)
                Column(
                  children: [
                    LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5)),
                    const SizedBox(height: 8),
                    Text('${(_progress * 100).toStringAsFixed(1)}%'),
                  ],
                )
              else if (_isInitializingForSkip)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在準備應用程式...'),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _startUpdate,
                      icon: const Icon(Icons.download),
                      label: const Text('立即更新'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: _skipUpdate, child: const Text('略過此版本')),
                  ],
                ),
            ],
          ),
        ),
      ),
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
            create: (_) => ThemeChangeNotifier(Static.localStorage.appTheme)),
        ChangeNotifierProvider(create: (_) => FavoritesNotifier()),
      ],
      child: ThemeProvider(
        builder: (BuildContext context, ThemeData themeData) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '桃園公車站動態追蹤',
          theme: themeData,
          home: const MainPage(),
        ),
      ),
    );
  }
}
