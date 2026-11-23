import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';

/// DỊCH VỤ PUSH NOTIFICATION THÔNG BÁO TỨC THÌ QUA FIREBASE CLOUD MESSAGING (MỤC 9)
class LetanNotificationServiceC1 {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _daKhoiTao = false;

  /// Khởi tạo và xin quyền thông báo
  static Future<void> khoiTao() async {
    if (_daKhoiTao) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✓ Đã cấp quyền Push Notification cho Lễ tân/CSKH');
        }

        // Lấy FCM Token để gửi thông báo đích danh
        await _messaging.getToken();

        // Đăng ký nhận thông báo theo chuyên khoa và toàn viện
        await dangKyTopicThongBao();

        // Lắng nghe thông báo khi ứng dụng đang mở (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('Nhận thông báo: ${message.notification?.title} - ${message.notification?.body}');
          }
        });

        _daKhoiTao = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi khởi tạo Push Notification: $e');
      }
    }
  }

  /// Đăng ký theo dõi Topic theo Mã bệnh viện & Vai trò
  static Future<void> dangKyTopicThongBao() async {
    try {
      final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId.isNotEmpty
          ? DuLieuProfileMauC1.thongTinHienTai.benhVienId
          : 'BV502';

      // Topic chung toàn bệnh viện
      await _messaging.subscribeToTopic('bv_$bvid');

      // Topic cho nhân viên CSKH
      await _messaging.subscribeToTopic('cskh_$bvid');

      // Topic cho Lễ tân
      await _messaging.subscribeToTopic('letan_$bvid');
    } catch (_) {}
  }
}
