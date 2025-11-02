import 'dart:js_interop';

import 'package:bus_scraper/utils/web_interop.dart';

@JS('hideFlutterLoader')
external void hideFlutterLoaderJS();

class WebInteropWeb implements WebInterop {
  @override
  void hideFlutterLoader() {
    hideFlutterLoaderJS();
  }
}

WebInterop getWebInterop() => WebInteropWeb();
