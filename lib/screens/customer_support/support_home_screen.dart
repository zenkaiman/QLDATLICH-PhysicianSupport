import 'package:flutter/material.dart';

class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CSKH')),
      body: const Center(
        child: Text('Quản lý hỗ trợ và phản hồi khách hàng.'),
      ),
    );
  }
}
