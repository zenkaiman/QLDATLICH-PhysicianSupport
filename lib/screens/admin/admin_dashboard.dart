import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard quản trị')),
      body: const Center(
        child: Text('Quản lý hệ thống và người dùng.'),
      ),
    );
  }
}
