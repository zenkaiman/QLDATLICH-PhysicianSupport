import 'package:flutter/material.dart';

import '../../widgets/custom_button.dart';

class BookAppointmentScreen extends StatelessWidget {
  const BookAppointmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch khám')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Chọn chuyên khoa và thời gian khám'),
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Chuyên khoa',
                hintText: 'Nội khoa',
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Ngày khám',
                hintText: 'dd/MM/yyyy',
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Xác nhận đặt lịch',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
