import 'package:flutter/foundation.dart'
    show kIsWeb; // <-- 步驟 1: 導入 kIsWeb 以偵測平台
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/theme_provider.dart';

// --- 步驟 2: 定義您的 APK 下載連結 ---
// !!! 請務必將此連結替換為您自己的 APK 檔案實際託管的網址 !!!
const String apkDownloadUrl =
    'https://github.com/TYBusStation/bus_scraper/releases/latest/download/app-release.apk';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  // 處理分享功能的函式
  void _shareWebsite(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(ShareParams(
      uri: Uri.parse('https://tybusstation.github.io/bus_scraper/'),
      subject: '桃園公車站動態追蹤',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    ));
  }

  // --- 步驟 3: 新增處理 APK 下載的函式 ---
  Future<void> _downloadApk(BuildContext context) async {
    final Uri uri = Uri.parse(apkDownloadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // 如果無法開啟連結，顯示錯誤訊息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法開啟下載連結: $apkDownloadUrl'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) =>
          SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "歡迎使用 桃園公車站動態追蹤\n目前提供桃園和台中的資料\n可至設定切換城市\n如有任何問題或建議\n請聯繫作者",
                  style:
                      themeData.textTheme.headlineSmall?.copyWith(fontSize: 25),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: List.generate(contactItems.length, (index) {
                        final item = contactItems[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: FaIcon(
                                item.icon,
                                size: 28,
                                color: themeData.colorScheme.primary,
                              ),
                              title: Text(
                                item.title,
                                style: themeData.textTheme.titleMedium,
                              ),
                              trailing: OutlinedButton(
                                onPressed: () async =>
                                    await launchUrl(Uri.parse(item.url)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: themeData.colorScheme.primary),
                                ),
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
                const SizedBox(height: 30),

                // --- 分享按鈕 ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('分享此網站'),
                  onPressed: () => _shareWebsite(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: themeData.colorScheme.primary,
                    foregroundColor: themeData.colorScheme.onPrimary,
                  ),
                ),

                // --- 步驟 4: 新增下載 APK 按鈕 (僅在 Web 平台顯示) ---
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.android, size: 22),
                    label: const Text('下載 Android 版 (APK)'),
                    onPressed: () => _downloadApk(context), // 呼叫下載函式
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      textStyle: const TextStyle(fontSize: 18),
                      backgroundColor: const Color(0xFF3DDC84),
                      // Android 綠色
                      foregroundColor: Colors.black, // 在綠色上的文字顏色
                    ),
                  ),
                ],
                // --- 下載按鈕結束 ---

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContactItem {
  final String title;
  final IconData icon;
  final String url;

  ContactItem({required this.title, required this.icon, required this.url});
}

final List<ContactItem> contactItems = [
  ContactItem(
    title: "Website",
    icon: FontAwesomeIcons.link,
    url: "https://tybusstation.github.io",
  ),
  ContactItem(
    title: "Instagram",
    icon: FontAwesomeIcons.instagram,
    url: "https://www.instagram.com/myster.bus/",
  ),
  ContactItem(
    title: "Discord",
    icon: FontAwesomeIcons.discord,
    url: "https://discordapp.com/users/716652855905222736",
  ),
  ContactItem(
    title: "GitHub",
    icon: FontAwesomeIcons.github,
    url: "https://github.com/TYBusStation",
  ),
];
