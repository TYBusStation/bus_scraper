import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yaml/yaml.dart';

class VersionCheckService {
  // URL 指向您 GitHub 上的 raw pubspec.yaml
  final String _versionInfoUrl =
      'https://raw.githubusercontent.com/TYBusStation/bus_scraper/main/pubspec.yaml';

  // Repository slug 用於組合下載連結
  final String _repoSlug = 'TYBusStation/bus_scraper';

  /// 抓取並解析 pubspec.yaml 以獲取最新版本資訊
  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await Dio().get<String>(_versionInfoUrl);
      if (response.statusCode == 200 && response.data != null) {
        // 使用 yaml 套件解析 YAML 內容
        final doc = loadYaml(response.data!);

        // 從 YAML 中取得版本字串 (例如 "1.0.7+1")
        final fullVersion = doc['version'] as String;
        // 我們只需要版本號部分，所以移除 build number (例如 "+1")
        final version = fullVersion.split('+').first;

        // 根據版本號，組合出 GitHub Release 的下載連結
        // 假設您的 release tag 格式為 "v版本號"，例如 "v1.0.8"
        final apkUrl =
            'https://github.com/$_repoSlug/releases/download/v$version/app-release.apk';

        return {
          'version': version,
          'url': apkUrl,
        };
      }
    } catch (e) {
      debugPrint('檢查版本失敗: $e');
    }
    return null;
  }

  /// 檢查是否需要更新
  Future<bool> isUpdateRequired() async {
    // 只在 Android 平台執行版本檢查
    if (!Platform.isAndroid) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final latestVersionInfo = await getLatestVersionInfo();

    if (latestVersionInfo != null) {
      final latestVersion = latestVersionInfo['version'];
      return _isVersionGreaterThan(latestVersion, currentVersion);
    }
    return false;
  }

  // 比較版本號 a 是否大於 b (例如 "1.0.8" > "1.0.7")
  bool _isVersionGreaterThan(String a, String b) {
    final partsA = a.split('.').map(int.parse).toList();
    final partsB = b.split('.').map(int.parse).toList();
    final length =
        partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < length; i++) {
      final vA = i < partsA.length ? partsA[i] : 0;
      final vB = i < partsB.length ? partsB[i] : 0;
      if (vA > vB) return true;
      if (vA < vB) return false;
    }
    return false;
  }

  /// 下載並觸發安裝 APK
  Future<void> downloadAndInstall(
    String url,
    void Function(double) onProgress,
  ) async {
    if (!Platform.isAndroid) return;

    // 1. 請求安裝權限
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        throw Exception('安裝權限被拒絕');
      }
    }

    // 2. 獲取儲存路徑並下載 APK
    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/app-release.apk';

    await Dio().download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    // 3. 打開 APK 檔案以觸發系統安裝程式
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('無法開啟安裝程式: ${result.message}');
    }
  }
}
