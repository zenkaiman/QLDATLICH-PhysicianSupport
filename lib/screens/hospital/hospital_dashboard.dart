import 'package:flutter/material.dart';

class HospitalDashboard extends StatelessWidget {
  const HospitalDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard bệnh viện')),
      body: const Center(
        child: Text('Tổng quan hoạt động bệnh viện.'),
      ),
    );
  }
}
