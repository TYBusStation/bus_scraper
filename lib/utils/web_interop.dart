abstract class WebInterop {
  void hideFlutterLoader();

  factory WebInterop() => getWebInterop();
}

WebInterop getWebInterop() {
  throw UnsupportedError(
      'Cannot create a WebInterop without dart:html or dart:js');
}
