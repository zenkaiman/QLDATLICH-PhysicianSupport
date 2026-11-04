import 'package:flutter/material.dart';

class ReceptionistHomeScreen extends StatelessWidget {
  const ReceptionistHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ lễ tân')),
      body: const Center(
        child: Text('Quản lý check-in và lịch hẹn'),
      ),
    );
  }
}
