import 'package:flutter/material.dart';

import 'hardcoded_duty_notice_flow.dart';

/// Điểm chạy RIÊNG cho luồng giao diện hardcode, nằm hoàn toàn trong
/// `lib/support_doctor`.
///
/// Chạy bằng lệnh:
/// `flutter run -t lib/support_doctor/hardcoded_duty_notice_preview.dart`
///
/// Không gọi `Firebase.initializeApp`, không đọc Firestore, không dùng
/// `AppRoutes` và không sửa `LoginScreen`. Có thể mở ngay cả khi chưa có dữ
/// liệu Firebase. Bản xem trước HTML, nếu cần, cũng nằm cùng thư mục:
/// `hardcoded_duty_notice_preview.html`.
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
