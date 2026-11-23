import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import '../config/firebase_admin_credentials.dart';

class FirebaseAdminAuthService {
  static final FirebaseAdminAuthService instance = FirebaseAdminAuthService._();
  FirebaseAdminAuthService._();

  static const _scopes = [
    'https://www.googleapis.com/auth/identitytoolkit',
    'https://www.googleapis.com/auth/firebase',
  ];

  AccessCredentials? _credentials;

  /// Lấy Google OAuth2 Access Token từ Service Account Key
  Future<String?> _getAccessToken() async {
    try {
      if (_credentials != null &&
          _credentials!.accessToken.data.isNotEmpty &&
          _credentials!.accessToken.expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) {
        return _credentials!.accessToken.data;
      }

      final accountCredentials = ServiceAccountCredentials.fromJson({
        'type': 'service_account',
        'project_id': FirebaseAdminConfig.projectId,
        'client_email': FirebaseAdminConfig.clientEmail,
        'client_id': FirebaseAdminConfig.clientId,
        'private_key': FirebaseAdminConfig.privateKey,
      });

      final client = http.Client();
      try {
        _credentials = await obtainAccessCredentialsViaServiceAccount(
          accountCredentials,
          _scopes,
          client,
        );
        return _credentials?.accessToken.data;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ Lỗi lấy Access Token từ Service Account: $e');
      return null;
    }
  }

  /// Tìm Firebase Auth UID dựa vào Email
  Future<String?> getUidByEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return null;

    final token = await _getAccessToken();
    if (token == null) return null;

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/projects/${FirebaseAdminConfig.projectId}/accounts:lookup',
    );

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': [cleanEmail],
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final users = data['users'] as List?;
        if (users != null && users.isNotEmpty) {
          final uid = users[0]['localId']?.toString();
          debugPrint('🔍 Tra cứu thành công Firebase Auth UID: $uid cho email: $cleanEmail');
          return uid;
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi tra cứu UID bằng email trên Firebase Auth: $e');
    }
    return null;
  }

  /// Vô hiệu hóa tài khoản và thu hồi toàn bộ phiên đăng nhập (Đá văng ngay lập tức)
  Future<bool> disableAndRevokeUser({required String uid, String? email}) async {
    final token = await _getAccessToken();
    if (token == null) return false;

    // Nếu UID truyền vào không phải là Auth UID gốc (ví dụ UID ngẫu nhiên từ Firestore), thử tra bằng email
    String targetUid = uid.trim();
    if (email != null && email.trim().isNotEmpty) {
      final lookupUid = await getUidByEmail(email.trim());
      if (lookupUid != null && lookupUid.isNotEmpty) {
        targetUid = lookupUid;
      }
    }

    if (targetUid.isEmpty) return false;

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/projects/${FirebaseAdminConfig.projectId}/accounts:update',
    );

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'localId': targetUid,
          'disableUser': true,
          // Gắn validSince = thời điểm hiện tại để thu hồi toàn bộ Refresh Token của các thiết bị đang đăng nhập
          'validSince': (DateTime.now().millisecondsSinceEpoch / 1000).floor().toString(),
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('✅ Đã khóa tài khoản gốc và thu hồi token thành công cho Auth UID: $targetUid');
        return true;
      } else {
        debugPrint('⚠️ Firebase Auth trả về mã lỗi ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('❌ Lỗi gọi disableUser trên Firebase Auth: $e');
    }
    return false;
  }

  /// Kích hoạt lại tài khoản trên Firebase Auth (Mở khóa)
  Future<bool> enableUser({required String uid, String? email}) async {
    final token = await _getAccessToken();
    if (token == null) return false;

    String targetUid = uid.trim();
    if (email != null && email.trim().isNotEmpty) {
      final lookupUid = await getUidByEmail(email.trim());
      if (lookupUid != null && lookupUid.isNotEmpty) {
        targetUid = lookupUid;
      }
    }

    if (targetUid.isEmpty) return false;

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/projects/${FirebaseAdminConfig.projectId}/accounts:update',
    );

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'localId': targetUid,
          'disableUser': false,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('✅ Đã mở khóa tài khoản gốc thành công cho Auth UID: $targetUid');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Lỗi mở khóa tài khoản trên Firebase Auth: $e');
    }
    return false;
  }

  /// Xóa vĩnh viễn tài khoản khỏi Firebase Authentication (Bảng Users trên Firebase Console)
  Future<bool> deleteUser({required String uid, String? email}) async {
    final token = await _getAccessToken();
    if (token == null) return false;

    String targetUid = uid.trim();
    if (email != null && email.trim().isNotEmpty) {
      final lookupUid = await getUidByEmail(email.trim());
      if (lookupUid != null && lookupUid.isNotEmpty) {
        targetUid = lookupUid;
      }
    }

    if (targetUid.isEmpty) {
      debugPrint('⚠️ Không xác định được UID để xóa khỏi Firebase Auth');
      return false;
    }

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/projects/${FirebaseAdminConfig.projectId}/accounts:delete',
    );

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'localId': targetUid,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('✅ Đã XÓA HOÀN TOÀN tài khoản khỏi Firebase Authentication (Console Users): $targetUid (email: $email)');

        // Nếu UID ban đầu khác với targetUid (lookup bằng email) và UID ban đầu có vẻ là một Auth UID (độ dài >= 20)
        // thì cố gắng xóa luôn UID ban đầu để dọn dẹp triệt để
        if (uid.trim().isNotEmpty && uid.trim() != targetUid && uid.trim().length >= 20) {
          try {
            await http.post(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'localId': uid.trim(),
              }),
            );
          } catch (_) {}
        }

        return true;
      } else {
        debugPrint('⚠️ Firebase Auth accounts:delete trả về mã ${res.statusCode}: ${res.body}');
        // Nếu xóa bằng targetUid thất bại (ví dụ UID không khớp), thử tra lại bằng email nếu chưa tra
        if (email != null && email.trim().isNotEmpty && targetUid == uid.trim()) {
          final lookedUp = await getUidByEmail(email.trim());
          if (lookedUp != null && lookedUp != targetUid) {
            final retryRes = await http.post(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'localId': lookedUp,
              }),
            );
            if (retryRes.statusCode == 200) {
              debugPrint('✅ Đã xóa thành công Firebase Auth user sau khi tra cứu email: $lookedUp ($email)');
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi xóa tài khoản trên Firebase Auth: $e');
    }
    return false;
  }
}
