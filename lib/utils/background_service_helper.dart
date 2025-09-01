// lib/background_service_helper.dart
import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// 這個 callback 必須是頂層函數或靜態方法，以便在 Isolate 中被調用
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 監聽從 UI 傳來的事件
  service.on('startDownload').listen((payload) async {
    if (payload == null) return;
    final String url = payload['url'];
    final String version = payload['version'];

    final directory = await getExternalStorageDirectory();
    final filePath = '${directory!.path}/app-release.apk';

    // 顯示一個前景服務通知
    await flutterLocalNotificationsPlugin.show(
      888,
      '下載更新中',
      '正在準備下載 v$version...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'apk_download_channel',
          'APK 下載',
          channelDescription: '用於顯示 APK 下載進度',
          importance: Importance.low,
          // 使用 low，這樣不會有提示音
          showProgress: true,
          progress: 0,
          maxProgress: 100,
          onlyAlertOnce: true,
          icon: 'ic_bg_service_small', // 注意：需要您在 drawable 中提供這個圖示
        ),
      ),
    );

    try {
      await Dio().download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            // 每隔 5% 更新一次通知，避免過於頻繁
            if (progress % 5 == 0) {
              flutterLocalNotificationsPlugin.show(
                888,
                '下載更新中 v$version',
                '$progress%',
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'apk_download_channel',
                    'APK 下載',
                    importance: Importance.low,
                    showProgress: true,
                    progress: progress,
                    maxProgress: 100,
                    onlyAlertOnce: true,
                    icon: 'ic_bg_service_small',
                  ),
                ),
              );
            }
            // 將進度傳回 UI
            service.invoke('update', {'progress': progress});
          }
        },
      );

      // 下載完成，取消進度通知並顯示完成通知
      await flutterLocalNotificationsPlugin.cancel(888);
      await flutterLocalNotificationsPlugin.show(
        889,
        '下載完成',
        '已成功下載 v$version，點擊以安裝。',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'apk_download_channel',
            'APK 下載',
            importance: Importance.high, // 使用 high，讓使用者容易看到
            icon: 'ic_bg_service_small',
          ),
        ),
        payload: filePath, // 將檔案路徑作為 payload
      );

      // 觸發安裝
      await OpenFilex.open(filePath);

      // 告訴 UI 下載已完成
      service.invoke('download_complete');
    } catch (e) {
      service.invoke('download_error', {'error': e.toString()});
    } finally {
      // 停止服務
      service.stopSelf();
    }
  });

  // 處理點擊「下載完成」通知的事件
  final notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    if (notificationAppLaunchDetails!.notificationResponse?.payload != null) {
      OpenFilex.open(
          notificationAppLaunchDetails.notificationResponse!.payload!);
    }
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'apk_download_channel',
    'APK 下載',
    description: '用於顯示 APK 下載進度',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'apk_download_channel',
      initialNotificationTitle: '準備更新',
      initialNotificationContent: '等待下載任務...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), // iOS 不支援此更新方式
  );
}
