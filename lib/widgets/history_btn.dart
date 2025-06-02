import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../static.dart';

class HistoryBtn extends StatelessWidget {
  final String plate;

  const HistoryBtn({super.key, required this.plate});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async => await launchUrl(Uri.parse(
          "${Static.apiBaseUrl}/bus_data/$plate?start_time=${Static.dateFormat.format(DateTime.now().subtract(const Duration(hours: 1)))}&end_time=${Static.dateFormat.format(DateTime.now())}")),
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
      child: const Text('歷史位置', style: TextStyle(fontSize: 16)),
    );
  }
}
