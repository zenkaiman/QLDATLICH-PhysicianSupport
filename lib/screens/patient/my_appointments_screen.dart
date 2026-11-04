import 'package:flutter/material.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch hẹn của tôi')),
      body: const Center(
        child: Text('Chưa có lịch hẹn nào.'),
      ),
    );
  }
}
