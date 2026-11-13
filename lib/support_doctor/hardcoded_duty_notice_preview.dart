import 'package:flutter/material.dart';

import 'hardcoded_duty_notice_flow.dart';

/// Điểm chạy RIÊNG cho luồng giao diện hardcode.
///
/// Chạy bằng lệnh:
/// `flutter run -t lib/support_doctor/hardcoded_duty_notice_preview.dart`
///
/// File này không gọi `Firebase.initializeApp`, không đọc Firestore và không
/// dùng `AppRoutes`, nên có thể mở ngay cả khi chưa có dữ liệu Firebase.
void main() => runApp(const HardcodedDutyNoticePreviewApp());

class HardcodedDutyNoticePreviewApp extends StatelessWidget {
  const HardcodedDutyNoticePreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Thông báo trực khoa · hardcode',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1E78E0),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    ),
    home: const HardcodedDutyNoticeFlow(),
  );
}
