import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class StorageHelper {
  // [MODIFIED] 將 'late final' 改為可選類型 '?'
  // 這讓我們可以檢查它是否已經被初始化。
  static Map? _data;

  static Future<void> init() async {
    // [MODIFIED] 冪等性檢查：如果 _data 已經被載入，就直接返回。
    if (_data != null) {
      return;
    }

    final file = await _getFile();
    final String jsonString;

    if (file.existsSync()) {
      jsonString = file.readAsStringSync();
    } else {
      jsonString = '{}';
    }

    _data = jsonDecode(jsonString);
  }

  static T get<T>(String key, [T? defaultValue]) {
    // [MODIFIED] 使用 '!' 斷言 _data 在此處不為 null。
    // 這是安全的，因為我們的 App 流程確保了 init() 會先被呼叫。
    return _data![key] ?? defaultValue;
  }

  static void set<T>(String key, T? value) {
    // [MODIFIED] 使用 '!'
    if (value == null) {
      _data!.remove(key);
    } else {
      _data![key] = value;
    }
    save();
  }

  static Future<void> save() async {
    // [MODIFIED] 如果 _data 為 null（雖然理論上不應該發生），則不做任何事。
    if (_data == null) return;

    final file = await _getFile();
    // [MODIFIED] 使用 '!'
    file.writeAsStringSync(jsonEncode(_data!));
  }

  static Future<File> _getFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(join(supportDirectory.path, 'local_storage.json'));
  }
}
