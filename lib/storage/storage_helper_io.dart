// storage_helper_io.dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class StorageHelper {
  static Map<String, dynamic>? _data;

  static Future<void> init() async {
    if (_data != null) {
      return;
    }

    final file = await _getFile();
    if (file.existsSync()) {
      final jsonString = file.readAsStringSync();
      if (jsonString.isNotEmpty) {
        _data = jsonDecode(jsonString);
      } else {
        _data = {};
      }
    } else {
      _data = {};
    }
  }

  static T get<T>(String key, [T? defaultValue]) {
    // 【關鍵修正】在使用前檢查 _data 是否為 null
    if (_data == null) {
      // 這是個嚴重問題，表示 init() 還沒被呼叫
      // 在這種情況下，返回 defaultValue 是最安全的選擇
      if (defaultValue != null) {
        return defaultValue;
      }
      // 如果連 defaultValue 都沒有，就只能拋出錯誤了
      throw StateError(
          'StorageHelper.get() called before StorageHelper.init() was complete, and no defaultValue was provided.');
    }

    // 如果 _data 存在，則安全地返回值
    final value = _data![key];

    // 如果 key 不存在，返回 defaultValue
    if (value == null) {
      return defaultValue as T;
    }

    // 如果 key 存在，但類型不匹配，也返回 defaultValue
    if (value is T) {
      return value;
    }

    return defaultValue as T;
  }

  static void set<T>(String key, T? value) {
    if (_data == null) {
      throw StateError(
          'StorageHelper.set() called before StorageHelper.init() was complete.');
    }
    if (value == null) {
      _data!.remove(key);
    } else {
      _data![key] = value;
    }
    save();
  }

  static Future<void> save() async {
    if (_data == null) return;
    final file = await _getFile();
    file.writeAsStringSync(jsonEncode(_data!));
  }

  static Future<File> _getFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(join(supportDirectory.path, 'local_storage.json'));
  }
}
