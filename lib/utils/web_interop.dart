// lib/utils/web_interop.dart

// 這個檔案是抽象層，定義了我們需要的功能
abstract class WebInterop {
  // 隱藏網頁載入動畫的函式
  void hideFlutterLoader();

  // 提供一個工廠建構子來根據平台回傳對應的實作
  factory WebInterop() => getWebInterop();
}

// 這個函式會在條件式匯入檔案中被實作
WebInterop getWebInterop() {
  // 這個擲出錯誤的實作會在非網頁平台被呼叫
  throw UnsupportedError(
      'Cannot create a WebInterop without dart:html or dart:js');
}
