import 'package:flutter/material.dart';

// 假設 HistoryPage 會放在同一個資料夾或你可以正確 import 的地方
import '../pages/history_page.dart';

class HistoryBtn extends StatelessWidget {
  final String plate;

  const HistoryBtn({super.key, required this.plate});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryPage(plate: plate),
          ),
        );
      },
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(10)),
      child: const Text('歷史位置', style: TextStyle(fontSize: 16)),
    );
  }
}
