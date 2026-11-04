import 'package:flutter/material.dart';

class UpdateRecordScreen extends StatelessWidget {
  const UpdateRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cập nhật hồ sơ')),
      body: const Center(
        child: Text('Nội dung cập nhật hồ sơ.'),
      ),
    );
  }
}
