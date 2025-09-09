// lib/utils/web_interop_stub.dart
import 'package:bus_scraper/utils/web_interop.dart';

// 這是給非網頁平台（如 Android）的實作
class WebInteropStub implements WebInterop {
  @override
  void hideFlutterLoader() {
    // 在 Android 上不需要做任何事，所以這個函式是空的
  }
}

// 當平台不是網頁時，回傳這個空的實作
WebInterop getWebInterop() => WebInteropStub();
