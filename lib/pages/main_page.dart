import 'package:bus_scraper/pages/company_page.dart';
import 'package:flutter/material.dart';

import 'cars_page.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("BusScraper"),
      ),
      body: switch (selectedIndex) {
        0 => const RoutePage(),
        1 => const CarsPage(),
        2 => const CompanyDataViewerPage(),
        3 => const SettingsPage(),
        _ => throw UnsupportedError('Invalid index: $selectedIndex'),
      },
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        selectedIndex: selectedIndex,
        destinations: const [
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
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: '公司資料',
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
