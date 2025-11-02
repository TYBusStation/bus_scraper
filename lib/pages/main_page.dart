import 'package:flutter/material.dart';

import 'cars_page.dart';
import 'company_page.dart';
import 'driver_plates_page.dart';
import 'favorite_page.dart';
import 'info_page.dart';
import 'nearby_vehicles_page.dart';
import 'route_page.dart';
import 'settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;
  Map<String, String>? _updateNotes;

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
      label: '駕駛長',
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: '監理',
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

  @override
  void initState() {
    super.initState();
  }

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

  String _getAppBarTitle(int index) {
    return switch (index) {
      0 => "桃園公車站動態追蹤",
      1 => "路線",
      2 => "車輛",
      3 => "收藏車輛",
      4 => "駕駛長編號反查",
      5 => "監理資料",
      6 => "附近車輛",
      7 => "設定",
      _ => "桃園公車站動態追蹤"
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        return Scaffold(
          appBar: AppBar(
            title: Text(_getAppBarTitle(selectedIndex)),
          ),
          body: isLandscape
              ? _buildLandscapeLayout()
              : _buildPageContent(selectedIndex),
          bottomNavigationBar: isLandscape
              ? null
              : NavigationBar(
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  selectedIndex: selectedIndex,
                  destinations: destinations,
                ),
        );
      },
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          destinations: destinations.map((dest) {
            return NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            );
          }).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _buildPageContent(selectedIndex),
        ),
      ],
    );
  }
}
