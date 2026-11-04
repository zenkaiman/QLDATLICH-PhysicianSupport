import 'package:flutter/material.dart';

class PatientQueueScreen extends StatelessWidget {
  const PatientQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hàng chờ bệnh nhân')),
      body: const Center(
        child: Text('Danh sách chờ đang trống.'),
      ),
    );
  }
}
