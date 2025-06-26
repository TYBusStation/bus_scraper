// lib/main_page.dart

import 'package:bus_scraper/pages/company_page.dart';
import 'package:bus_scraper/pages/favorite_page.dart';
import 'package:bus_scraper/pages/nearby_vehicles_page.dart'; // <--- 1. 導入新頁面
import 'package:flutter/material.dart';

import 'cars_page.dart';
import 'driver_plates_page.dart';
import 'info_page.dart';
import 'route_page.dart';
import 'settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 根據選擇的頁面動態設定 AppBar 標題
    final String appBarTitle = switch (selectedIndex) {
      0 => "資訊",
      1 => "路線",
      2 => "車輛",
      3 => "收藏",
      4 => "駕駛反查",
      5 => "公司",
      6 => "附近車輛", // <--- 4. 新增標題
      7 => "設定",
      _ => "BusScraper"
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: switch (selectedIndex) {
        0 => const InfoPage(),
        1 => const RoutePage(),
        2 => const CarsPage(),
        3 => const FavoritesPage(),
        4 => const DriverPlatesPage(),
        5 => const CompanyPage(),
        6 => const NearbyVehiclesPage(),
        7 => const SettingsPage(),
        _ => throw UnsupportedError('Invalid index: $selectedIndex'),
      },
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        selectedIndex: selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: '資訊',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: '路線',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: '車輛',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: '收藏',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '駕駛',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: '公司',
          ),
          // --- 3. 新增導航項目 ---
          NavigationDestination(
            icon: Icon(Icons.pin_drop_outlined),
            selectedIcon: Icon(Icons.pin_drop),
            label: '附近',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
