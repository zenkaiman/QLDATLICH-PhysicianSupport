import 'package:flutter/material.dart';

class MedicalHistoryScreen extends StatelessWidget {
  const MedicalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ bệnh án')),
      body: const Center(
        child: Text('Hồ sơ bệnh án trống.'),
      ),
    );
  }
}
