import 'package:bus_scraper/data/bus_route.dart';
import 'package:bus_scraper/storage/city.dart';
import 'package:bus_scraper/utils/static.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract class FormatterUtils {
  static final DateFormat apiTimeFormat = DateFormat("yyyy-MM-dd'T'HH-mm-ss");
  static final DateFormat displayTimeFormatNoSec =
      DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat displayTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat displayDateFormat = DateFormat('yyyy/MM/dd');

  static final RegExp letterNumber = RegExp(r"[^a-zA-Z0-9]");

  static Map<String, dynamic> _parseRoute(String route) {
    String type = 'UNKNOWN';
    int? baseNum;
    String? baseStr;
    String suffixAlpha = '';
    String suffixNumeric = '';
    String suffixSpecial = '';
    String suffixParenthesis = '';

    String mainPart = route;
    if (route.contains('(')) {
      final match = RegExp(r'^(.*?)\((.*)\)$').firstMatch(route);
      if (match != null) {
        mainPart = match.group(1)!;
        suffixParenthesis = '(${match.group(2)!})';
      }
    }

    RegExpMatch? specialPrefixMatch =
        RegExp(r'^(\d+)([東西南北])$').firstMatch(mainPart);
    if (specialPrefixMatch != null) {
      type = 'SPECIAL_PREFIX';
      baseNum = int.tryParse(specialPrefixMatch.group(1)!);
      suffixSpecial = specialPrefixMatch.group(2)!;
    } else if (mainPart.startsWith('T')) {
      type = 'T';
      RegExpMatch? match = RegExp(r'^T(\d+)([A-Z]*)').firstMatch(mainPart);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        suffixAlpha = match.group(2) ?? '';
      } else {
        type = 'ALPHA';
        baseStr = mainPart;
      }
    } else if (RegExp(r'^\d').hasMatch(mainPart)) {
      type = 'NUMERIC';
      RegExpMatch? match = RegExp(r'^(\d+)(.*)').firstMatch(mainPart);
      if (match != null) {
        baseNum = int.tryParse(match.group(1)!);
        String remaining = match.group(2) ?? '';

        RegExpMatch? suffixMatch =
            RegExp(r'^([A-Z]*)(.*)').firstMatch(remaining);
        if (suffixMatch != null) {
          suffixAlpha = suffixMatch.group(1) ?? '';
          suffixSpecial = suffixMatch.group(2) ?? '';
        }
      }
    } else {
      type = 'ALPHA';
      RegExpMatch? match =
          RegExp(r'^([A-Z]+)(\d*)([A-Z]*)(.*)').firstMatch(mainPart);
      if (match != null) {
        baseStr = match.group(1)!;
        suffixNumeric = match.group(2) ?? '';
        suffixAlpha = match.group(3) ?? '';
        suffixSpecial = match.group(4) ?? '';
      } else {
        baseStr = mainPart;
      }
    }

    return {
      'original': route,
      'type': type,
      'baseNum': baseNum,
      'baseStr': baseStr,
      'suffixAlpha': suffixAlpha,
      'suffixNumeric': suffixNumeric,
      'suffixSpecial': suffixSpecial, // 新增
      'suffixParenthesis': suffixParenthesis,
    };
  }

  static int compareRoutes(String a, String b) {
    if (a == b) return 0;
    var pa = _parseRoute(a);
    var pb = _parseRoute(b);

    int typeOrder(String type) {
      if (type == 'SPECIAL_PREFIX') return 0; // 數字+中文最高優先級
      if (type == 'NUMERIC') return 1;
      if (type == 'ALPHA') return 2;
      if (type == 'T') return 3;
      return 4;
    }

    int typeComparison = typeOrder(pa['type']).compareTo(typeOrder(pb['type']));
    if (typeComparison != 0) return typeComparison;

    if (pa['baseNum'] != null && pb['baseNum'] != null) {
      int baseNumComparison = pa['baseNum'].compareTo(pb['baseNum']);
      if (baseNumComparison != 0) return baseNumComparison;
    } else if (pa['baseStr'] != null && pb['baseStr'] != null) {
      int baseStrComparison =
          (pa['baseStr'] ?? '').compareTo(pb['baseStr'] ?? '');
      if (baseStrComparison != 0) return baseStrComparison;
    }

    int getSpecialSuffixOrder(String suffix) {
      if (suffix.isEmpty) return 0;
      if (suffix == '區') return 1;
      if (suffix == '副') return 2;
      if (suffix == '直') return 3;
      if (suffix == '快') return 4;
      if (suffix == '夜') return 5;
      if (suffix == '通勤') return 6;
      if (suffix == '延') return 7;
      if (suffix.startsWith('經')) return 8;
      return 99;
    }

    int suffixAlphaComparison =
        (pa['suffixAlpha'] as String).compareTo(pb['suffixAlpha'] as String);
    if (suffixAlphaComparison != 0) return suffixAlphaComparison;

    int specialSuffixComparison =
        getSpecialSuffixOrder(pa['suffixSpecial'] as String)
            .compareTo(getSpecialSuffixOrder(pb['suffixSpecial'] as String));
    if (specialSuffixComparison != 0) return specialSuffixComparison;

    int rawSpecialSuffixComparison = (pa['suffixSpecial'] as String)
        .compareTo(pb['suffixSpecial'] as String);
    if (rawSpecialSuffixComparison != 0) return rawSpecialSuffixComparison;

    int paSuffixNumVal = (pa['suffixNumeric'] as String).isEmpty
        ? 0
        : int.parse(pa['suffixNumeric'] as String);
    int pbSuffixNumVal = (pb['suffixNumeric'] as String).isEmpty
        ? 0
        : int.parse(pb['suffixNumeric'] as String);
    int suffixNumComparison = paSuffixNumVal.compareTo(pbSuffixNumVal);
    if (suffixNumComparison != 0) return suffixNumComparison;

    return (pa['suffixParenthesis'] as String)
        .compareTo(pb['suffixParenthesis'] as String);
  }

  static bool hasDriverRemark(String driverId) {
    return Static.localStorage
        .getRemarksForCity(Static.city)
        .containsKey(driverId);
  }

  static String? getDriverRemark(String driverId) {
    return Static.localStorage.getRemarksForCity(Static.city)[driverId];
  }

  static String getDriverText(String? driverId) {
    if (driverId == null || driverId == "0" || driverId.isEmpty) {
      return "未知駕駛長";
    }
    return hasDriverRemark(driverId)
        ? "$driverId(${getDriverRemark(driverId)})"
        : driverId;
  }

  static String getBusDirectionName(BusRoute route, int goBack) {
    if (route.destination.isEmpty && route.departure.isEmpty) {
      return '未知';
    }

    if (Static.city == City.taipei) {
      switch (goBack) {
        case 0:
          return route.destination;
        case 1:
          return route.departure;
        default:
          return '未知';
      }
    } else {
      switch (goBack) {
        case 1:
          return route.destination;
        case 2:
          return route.departure;
        default:
          return '未知';
      }
    }
  }

  static ({String text, Color color}) getDutyStatusInfo(int dutyStatus) {
    if (Static.city == City.taipei) {
      switch (dutyStatus) {
        case 1:
          return (text: "營運", color: Colors.green.shade700);
        case 2:
          return (text: "非營運", color: Colors.orange.shade700);
        default:
          return (text: "未知", color: Colors.grey.shade600);
      }
    } else {
      switch (dutyStatus) {
        case 0:
          return (text: "營運", color: Colors.green.shade700);
        case 1:
          return (text: "非營運", color: Colors.orange.shade700);
        default:
          return (text: "未知", color: Colors.grey.shade600);
      }
    }
  }
}
