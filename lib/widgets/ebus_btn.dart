import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EbusBtn extends StatelessWidget {
  final String id;

  const EbusBtn({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async => await launchUrl(
          Uri.parse("https://ebus.tycg.gov.tw/ebus/driving-map/$id")),
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
      child: const Text('公車動態網', style: TextStyle(fontSize: 16)),
    );
  }
}
