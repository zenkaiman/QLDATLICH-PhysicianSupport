import 'package:flutter/material.dart';

class AssistantHomeScreen extends StatelessWidget {
  const AssistantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ bác sĩ')),
      body: const Center(
        child: Text('Quản lý hàng chờ và cập nhật hồ sơ.'),
      ),
    );
  }
}
