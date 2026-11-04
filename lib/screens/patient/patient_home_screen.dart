import 'package:flutter/material.dart';

import '../../config/app_routes.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {'title': 'Đặt lịch khám', 'route': AppRoutes.bookAppointment},
      {'title': 'Lịch hẹn của tôi', 'route': AppRoutes.myAppointments},
      {'title': 'Hồ sơ bệnh án', 'route': AppRoutes.medicalHistory},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ bệnh nhân'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(item['title'] as String),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, item['route'] as String),
            ),
          );
        },
      ),
    );
  }
}
