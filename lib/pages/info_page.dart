import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/theme_provider.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (ThemeData themeData) => SingleChildScrollView(
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
                  "如有任何問題或建議\n請聯繫作者",
                  style: themeData.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: 36),
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
                      children: List.generate(contactItems.length, (index) {
                        final item = contactItems[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: FaIcon(
                                // 左側圖示
                                item.icon,
                                size: 28,
                                color:
                                    themeData.colorScheme.primary, // 使用主題的主要顏色
                              ),
                              title: Text(
                                // 標題文字
                                item.title,
                                style: themeData.textTheme.titleMedium,
                              ),
                              trailing: OutlinedButton(
                                // 右側按鈕
                                onPressed: () async =>
                                    await launchUrl(Uri.parse(item.url)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: themeData
                                          .colorScheme.primary), // 按鈕邊框顏色
                                ),
                                child: const Text("前往"),
                              ),
                              // 提示文字
                              onTap: () async => await launchUrl(
                                  Uri.parse(item.url)), // 使整個 ListTile 可點擊
                            ),
                            if (index < contactItems.length - 1) // 如果不是最後一個項目
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
  ContactItem(
    title: "Facebook",
    icon: FontAwesomeIcons.facebook,
    url: "https://www.facebook.com/profile.php?id=100021672037831",
  ),
  ContactItem(
    title: "Email",
    icon: FontAwesomeIcons.envelope, // 或者 Icons.email
    url: "mailto:jackychiu0101@gmail.com",
  ),
];
