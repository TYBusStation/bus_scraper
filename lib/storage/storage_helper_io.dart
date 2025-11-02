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
    if (_data == null) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw StateError(
          'StorageHelper.get() called before StorageHelper.init() was complete, and no defaultValue was provided.');
    }

    final value = _data![key];

    if (value == null) {
      return defaultValue as T;
    }

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
