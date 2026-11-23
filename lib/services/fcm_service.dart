import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Khởi tạo và xin quyền nhận thông báo
  Future<void> init() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Người dùng đã cấp quyền nhận thông báo');
    }

    /// _saveTokenToFirestore: lưu dữ liệu.
    await _saveTokenToFirestore();

    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token đã thay đổi: $newToken');
      _saveTokenToFirestore(token: newToken);
    });
  }

  /// Lưu FCM Token vào document của bệnh nhân
  Future<void> _saveTokenToFirestore({String? token}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final fcmToken = token ?? await _messaging.getToken();
    if (fcmToken == null) return;

    try {
      await _firestore.collection('BenhNhan').doc(userId).set({
        'fcm_token': fcmToken,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true để không ghi đè các field khác
      print('💾 Đã lưu FCM Token thành công cho user: $userId');
    } catch (e) {
      print('❌ Lỗi khi lưu FCM Token: $e');
    }
  }
}
