import 'dart:convert';
import 'package:bus_scraper/static.dart'; // 假設您的 Static 類在此
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';

import 'company_page.dart';
import 'favorite_page.dart';
import 'nearby_vehicles_page.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndUpdateCheck();
    });
  }

  Future<void> _loadAndUpdateCheck() async {
    await _loadUpdateNotes();
    if (mounted) {
      _checkForUpdates();
    }
  }

  Future<void> _loadUpdateNotes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/versions.json');
      final decodedJson = jsonDecode(jsonString) as Map<String, dynamic>;
      setState(() {
        _updateNotes = decodedJson.map(
              (key, value) => MapEntry(key, value.toString()),
        );
      });
    } catch (e) {
      debugPrint('Failed to load version notes: $e');
      setState(() {
        _updateNotes = {};
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_updateNotes == null || _updateNotes!.isEmpty) {
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final lastShownVersion = Static.localStorage.lastShownVersion;

    if (currentVersion != lastShownVersion && _updateNotes!.containsKey(currentVersion)) {
      if (mounted) {
        _showUpdateDialog(
          context,
          currentVersion,
          _updateNotes![currentVersion]!,
        );
      }
      Static.localStorage.lastShownVersion = currentVersion;
    }
  }

  void _showUpdateDialog(BuildContext context, String version, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('應用程式更新資訊 (v$version)'),
          content: SingleChildScrollView(
            child: Text(notes),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('我知道了'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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