import 'package:bus_scraper/utils/static.dart';
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

  final List<NavigationDestination> _allDestinations = const [
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

  late List<NavigationDestination> _destinations;
  late List<Widget Function()> _pageBuilders;
  late List<String> _appBarTitles;

  @override
  void initState() {
    super.initState();
    _buildDynamicDestinations();
  }

  void _buildDynamicDestinations() {
    final List<NavigationDestination> destinations = [];
    final List<Widget Function()> pageBuilders = [];
    final List<String> appBarTitles = [];

    destinations.add(_allDestinations[0]);
    pageBuilders.add(() => const InfoPage());
    appBarTitles.add("桃園公車站動態追蹤");

    destinations.add(_allDestinations[1]);
    pageBuilders.add(() => const RoutePage());
    appBarTitles.add("路線");

    destinations.add(_allDestinations[2]);
    pageBuilders.add(() => const CarsPage());
    appBarTitles.add("車輛");

    destinations.add(_allDestinations[3]);
    pageBuilders.add(() => const FavoritesPage());
    appBarTitles.add("收藏車輛");

    if (Static.city.hasDriverInfo) {
      destinations.add(_allDestinations[4]);
      pageBuilders.add(() => const DriverPlatesPage());
      appBarTitles.add("駕駛長編號反查");
    }

    destinations.add(_allDestinations[5]);
    pageBuilders.add(() => const CompanyPage());
    appBarTitles.add("監理資料");

    destinations.add(_allDestinations[6]);
    pageBuilders.add(() => const NearbyVehiclesPage());
    appBarTitles.add("附近車輛");

    destinations.add(_allDestinations[7]);
    pageBuilders.add(() => const SettingsPage());
    appBarTitles.add("設定");

    _destinations = destinations;
    _pageBuilders = pageBuilders;
    _appBarTitles = appBarTitles;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildDynamicDestinations();
    if (selectedIndex >= _destinations.length) {
      selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        return Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitles[selectedIndex]),
          ),
          body: isLandscape
              ? _buildLandscapeLayout()
              : _pageBuilders[selectedIndex](),
          bottomNavigationBar: isLandscape
              ? null
              : NavigationBar(
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  selectedIndex: selectedIndex,
                  destinations: _destinations,
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
          destinations: _destinations.map((dest) {
            return NavigationRailDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            );
          }).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _pageBuilders[selectedIndex](),
        ),
      ],
    );
  }
}
