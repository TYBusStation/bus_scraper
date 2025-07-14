import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart'; // <-- 步驟 1: 導入 share_plus 套件
import 'package:url_launcher/url_launcher.dart';

import '../widgets/theme_provider.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  // 處理分享功能的函式
  void _shareWebsite(BuildContext context) {
    // 獲取按鈕的位置，用於 iPad 上的分享彈出視窗
    final box = context.findRenderObject() as RenderBox?;

    SharePlus.instance.share(ShareParams(
      uri: Uri.parse('https://myster7494.github.io/bus_scraper/'),
      subject: '桃園公車動態資訊監測程式 (Bus Scraper)',
      text: '桃園公車動態資訊監測程式 (Bus Scraper)',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    ));
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
                const SizedBox(height: 20),
                Text(
                  "如有任何問題或建議\n請聯繫作者",
                  style: themeData.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: 32),
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

                // --- 新增的分享按鈕 ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('分享此網站'),
                  onPressed: () => _shareWebsite(context), // 呼叫分享函式
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: themeData.colorScheme.primary,
                    // 主題主要顏色
                    foregroundColor:
                        themeData.colorScheme.onPrimary, // 在主要顏色上的文字顏色
                  ),
                ),
                // --- 分享按鈕結束 ---

                const SizedBox(height: 30),
                Text(
                  "資料皆為爬蟲爬取\n並儲存於自架伺服器\n最早資料時間為 2025-06-08\n\n歡迎分享此網站給有興趣的人",
                  style:
                      themeData.textTheme.headlineSmall?.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
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
    title: "Discord",
    icon: FontAwesomeIcons.discord,
    url: "https://discordapp.com/users/716652855905222736",
  ),
  ContactItem(
    title: "GitHub",
    icon: FontAwesomeIcons.github,
    url: "https://github.com/Myster7494",
  ),
  ContactItem(
    title: "Instagram",
    icon: FontAwesomeIcons.instagram,
    url: "https://www.instagram.com/__myster___/",
  ),
];
