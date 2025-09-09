// lib/utils/web_interop_web.dart
import 'dart:js_interop';

import 'package:bus_scraper/utils/web_interop.dart';

// 這是只有在網頁平台才會被匯入和使用的實作

@JS('hideFlutterLoader') // 這裡的名稱要和你 index.html 裡的 JavaScript 函式名稱完全一樣
external void hideFlutterLoaderJS();

class WebInteropWeb implements WebInterop {
  @override
  void hideFlutterLoader() {
    // 呼叫實際的 JavaScript 函式
    hideFlutterLoaderJS();
  }
}

// 當平台是網頁時，回傳這個網頁專用的實作
WebInterop getWebInterop() => WebInteropWeb();
