import 'package:bus_scraper/utils/web_interop.dart';

class WebInteropStub implements WebInterop {
  @override
  void hideFlutterLoader() {}
}

WebInterop getWebInterop() => WebInteropStub();
