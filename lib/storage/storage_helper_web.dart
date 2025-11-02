import 'dart:convert';
import 'dart:html' as html;

class StorageHelper {
  static Future<void> init() async {}

  static T get<T>(String key, [T? defaultValue]) {
    final value = html.window.localStorage[key];

    if (value != null) {
      try {
        return jsonDecode(value);
      } catch (e) {
        print('Error decoding JSON from localStorage for key "$key": $e');
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
