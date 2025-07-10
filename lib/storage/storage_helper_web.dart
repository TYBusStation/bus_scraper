// storage_helper_web.dart
import 'dart:convert';
import 'dart:html' as html;

class StorageHelper {
  static Future<void> init() async {}

  static T get<T>(String key, [T? defaultValue]) {
    final value = html.window.localStorage[key];

    if (value != null) {
      try {
        // 解碼並直接返回，讓類型檢查在外部進行
        return jsonDecode(value);
      } catch (e) {
        print('Error decoding JSON from localStorage for key "$key": $e');
        // 解碼失敗，視為沒有值，返回 defaultValue
        return defaultValue as T;
      }
    } else {
      return defaultValue as T;
    }
  }

  static void set<T>(String key, T value) {
    if (value == null) {
      html.window.localStorage.remove(key);
      return;
    }
    html.window.localStorage[key] = jsonEncode(value);
  }

  static Future<void> save() async {}
}
