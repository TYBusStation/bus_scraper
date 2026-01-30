import 'package:bus_scraper/utils/formatter_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/static.dart';
import '../widgets/theme_provider.dart';

const String apkDownloadUrl =
    'https://github.com/TYBusStation/bus_scraper/releases/latest/download/app-release.apk';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  void _shareWebsite(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(ShareParams(
      uri: Uri.parse('https://tybusstation.github.io/bus_scraper/'),
      subject: '桃園公車站動態追蹤',
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _downloadApk(BuildContext context) async {
    final Uri uri = Uri.parse(apkDownloadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        FormatterUtils.showSnackbar(context, '無法開啟下載連結: $apkDownloadUrl',
            color: Colors.red);
      }
    }
  }

  Widget _buildAnnouncementCard(BuildContext context, ThemeData themeData) {
    if (Static.announcementMarkdown.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(FontAwesomeIcons.bullhorn,
                  color: themeData.colorScheme.primary),
              title: Text('最新公告', style: themeData.textTheme.titleLarge),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            MarkdownBody(data: Static.announcementMarkdown),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateInfoCard(BuildContext context, ThemeData themeData) {
    final currentVersion = Static.currentVersion;
    final versionNotes = Static.versionNotes;

    if (currentVersion == null || versionNotes == null) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(FontAwesomeIcons.rocket,
                  color: themeData.colorScheme.secondary),
              title: Text(
                '本次更新 (v$currentVersion)',
                style: themeData.textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              versionNotes,
              style: themeData.textTheme.bodyMedium?.copyWith(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      builder: (BuildContext context, ThemeData themeData) =>
          SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('分享此網站'),
                  onPressed: () => _shareWebsite(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: themeData.colorScheme.primary,
                    foregroundColor: themeData.colorScheme.onPrimary,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.android, size: 20),
                    label: const Text('下載 Android 版 (APK)'),
                    onPressed: () => _downloadApk(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      textStyle: const TextStyle(fontSize: 16),
                      backgroundColor: const Color(0xFF3DDC84),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildAnnouncementCard(context, themeData),
                const SizedBox(height: 4),
                _buildUpdateInfoCard(context, themeData),
                const SizedBox(height: 4),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      children: List.generate(contactItems.length, (index) {
                        final item = contactItems[index];
                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              leading: FaIcon(
                                item.icon,
                                size: 26,
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
                const SizedBox(height: 16),
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
    title: "Discord 公車交流群",
    icon: FontAwesomeIcons.discord,
    url: "https://tybusstation.github.io/discord",
  ),
  ContactItem(
    title: "Linktree",
    icon: FontAwesomeIcons.link,
    url: "https://tybusstation.github.io",
  ),
  ContactItem(
    title: "Instagram",
    icon: FontAwesomeIcons.instagram,
    url: "https://www.instagram.com/myster.bus/",
  ),
  ContactItem(
    title: "GitHub",
    icon: FontAwesomeIcons.github,
    url: "https://github.com/TYBusStation",
  ),
];
