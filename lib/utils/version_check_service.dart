// lib/version_check_service.dart

// 引入我們新建的平台檢查器
import 'package:bus_scraper/utils/platform_checker.dart';
// 移除了 'dart:io' 的 import
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yaml/yaml.dart';

class VersionCheckService {
  final String _versionInfoUrl =
      'https://raw.githubusercontent.com/TYBusStation/bus_scraper/main/pubspec.yaml';
  final String _repoSlug = 'TYBusStation/bus_scraper';

  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await Dio().get<String>(_versionInfoUrl);
      if (response.statusCode == 200 && response.data != null) {
        final doc = loadYaml(response.data!);
        final fullVersion = doc['version'] as String;
        final version = fullVersion.split('+').first;
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

  Future<bool> isUpdateRequired() async {
    // MODIFIED: 使用我們新的 isAndroid getter
    if (!isAndroid) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final latestVersionInfo = await getLatestVersionInfo();

    if (latestVersionInfo != null) {
      final latestVersion = latestVersionInfo['version'];
      return _isVersionGreaterThan(latestVersion, currentVersion);
    }
    return false;
  }

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

  Future<void> downloadAndInstall(
    String url,
    void Function(double) onProgress,
  ) async {
    // MODIFIED: 使用我們新的 isAndroid getter
    if (!isAndroid) return;

    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        throw Exception('安裝權限被拒絕');
      }
    }

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

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('無法開啟安裝程式: ${result.message}');
    }
  }
}
