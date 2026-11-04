import 'package:flutter/material.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket hỗ trợ')),
      body: const Center(
        child: Text('Danh sách ticket đang chờ xử lý.'),
      ),
    );
  }
}
