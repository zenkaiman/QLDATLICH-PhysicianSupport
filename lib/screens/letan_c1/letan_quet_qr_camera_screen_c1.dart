import 'package:flutter/material.dart';

class LetanQuetQrCameraScreenC1 extends StatelessWidget {
  final void Function(String)? onQrScanned;

  const LetanQuetQrCameraScreenC1({super.key, this.onQrScanned});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét Mã QR')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại bàn làm việc'),
        ),
      ),
    );
  }
}
