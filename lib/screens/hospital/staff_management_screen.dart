import 'package:flutter/material.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhân sự')),
      body: const Center(
        child: Text('Danh sách nhân sự bệnh viện.'),
      ),
    );
  }
}
