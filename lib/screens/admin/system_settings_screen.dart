import 'package:flutter/material.dart';

class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt hệ thống')),
      body: const Center(
        child: Text('Thiết lập hệ thống và bảo mật.'),
      ),
    );
  }
}
