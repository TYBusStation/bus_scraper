import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum City {
  taoyuan(
    "桃園",
    "taoyuan",
    Image(image: AssetImage('assets/taoyuan.png')),
    "https://ebus.tycg.gov.tw/ebus",
    true,
    "KKA-3822",
    "120031",
    LatLng(24.98893444390252, 121.31443803557084),
  ),
  taichung(
    "台中",
    "taichung",
    Image(image: AssetImage('assets/taichung.png')),
    "https://citybus.taichung.gov.tw/ebus",
    true,
    "EAL-1277",
    "14308",
    LatLng(24.137331792238204, 120.6869186637282),
  ),
  taipei(
    "大台北",
    "taipei",
    Image(image: AssetImage('assets/taipei.png')),
    "https://ebus.gov.taipei/",
    false,
    "EAL-3060",
    "",
    LatLng(25.047799286579576, 121.51684313085175),
  );

  final String name;
  final String code;
  final Widget icon;
  final String url;
  final bool hasDriverInfo;
  final String exPlate;
  final String exDriver;
  final LatLng exPos;

  const City(
    this.name,
    this.code,
    this.icon,
    this.url,
    this.hasDriverInfo,
    this.exPlate,
    this.exDriver,
    this.exPos,
  );

  static const City defaultCity = taoyuan;
}
