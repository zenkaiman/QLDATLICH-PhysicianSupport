import 'package:flutter/material.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: const Center(
        child: Text('Biểu đồ thống kê hoạt động bệnh viện.'),
      ),
    );
  }
}
