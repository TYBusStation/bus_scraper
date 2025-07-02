// lib/main_page.dart

import 'package:bus_scraper/pages/company_page.dart';
import 'package:bus_scraper/pages/favorite_page.dart';
import 'package:bus_scraper/pages/nearby_vehicles_page.dart';
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

  // 將導航項目抽離出來，方便在 NavigationBar 和 NavigationRail 中共用
  final List<NavigationDestination> destinations = const [
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
  ];

  // 將頁面內容抽離出來，方便共用
  Widget _buildPageContent(int index) {
    return switch (index) {
      0 => const InfoPage(),
      1 => const RoutePage(),
      2 => const CarsPage(),
      3 => const FavoritesPage(),
      4 => const DriverPlatesPage(),
      5 => const CompanyPage(),
      6 => const NearbyVehiclesPage(),
      7 => const SettingsPage(),
      _ => throw UnsupportedError('Invalid index: $index'),
    };
  }

  // 將 AppBar 標題抽離出來，方便共用
  String _getAppBarTitle(int index) {
    return switch (index) {
      0 => "資訊",
      1 => "路線",
      2 => "車輛",
      3 => "收藏",
      4 => "駕駛反查",
      5 => "公司",
      6 => "附近車輛",
      7 => "設定",
      _ => "BusScraper"
    };
  }

  @override
  Widget build(BuildContext context) {
    // 【修改】使用 LayoutBuilder 來偵測螢幕尺寸
    return LayoutBuilder(
      builder: (context, constraints) {
        // 判斷條件：當寬度大於高度時，視為橫向模式
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        // 【修改】將 Scaffold 包在判斷邏輯內，根據模式返回不同結構
        return Scaffold(
          appBar: AppBar(
            // 標題和頁面內容的邏輯保持不變
            title: Text(_getAppBarTitle(selectedIndex)),
          ),
          // 【修改】根據 isLandscape 決定是否顯示 body
          body: isLandscape
              ? _buildLandscapeLayout() // 橫向佈局
              : _buildPageContent(selectedIndex), // 縱向佈局（原始佈局）

          // 【修改】根據 isLandscape 決定是否顯示 bottomNavigationBar
          bottomNavigationBar: isLandscape
              ? null // 橫向模式下，不顯示底部導航欄
              : NavigationBar(
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  selectedIndex: selectedIndex,
                  destinations: destinations, // 使用抽離出的 destinations
                ),
        );
      },
    );
  }

  // 【新增】建立一個專門用於橫向佈局的 Widget
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 左側的 NavigationRail
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          // labelType 決定是否顯示標籤，可根據需求調整
          labelType: NavigationRailLabelType.all,
          destinations: destinations.map((dest) {
            // NavigationRail 需要 NavigationRailDestination
            return NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            );
          }).toList(),
        ),
        // 右側和 NavigationRail 之間的垂直分隔線，讓介面更清晰
        const VerticalDivider(thickness: 1, width: 1),
        // 右側的頁面內容
        Expanded(
          child: _buildPageContent(selectedIndex),
        ),
      ],
    );
  }
}
