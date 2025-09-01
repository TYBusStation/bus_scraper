// lib/platform_checker_io.dart

import 'dart:io';

/// 在原生平台上，我們直接使用 dart:io 來判斷。
bool get isAndroid => Platform.isAndroid;
