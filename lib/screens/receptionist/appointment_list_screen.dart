import 'package:flutter/material.dart';

class AppointmentListScreen extends StatelessWidget {
  const AppointmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách lịch hẹn')),
      body: const Center(
        child: Text('Không có lịch hẹn nào.'),
      ),
    );
  }
}
