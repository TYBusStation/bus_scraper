// lib/platform_checker.dart

export 'platform_checker_web.dart' // 預設匯出 Web 版本
    if (dart.library.io) 'platform_checker_io.dart'; // 如果 dart:io 存在，則改為匯出 IO 版本
