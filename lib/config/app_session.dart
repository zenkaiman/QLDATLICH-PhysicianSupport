import 'package:firebase_auth/firebase_auth.dart';

/// Quản lý phiên làm việc và ID bệnh viện đang đăng nhập
class AppSession {
  static String _benhVienId = '';

  static String get benhVienId {
    if (_benhVienId.isNotEmpty && _benhVienId != 'dFmZHBjFNUT1eRzJjXp5') {
      return _benhVienId;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return uid;
    }
    return _benhVienId;
  }

  static set benhVienId(String value) {
    if (value != 'dFmZHBjFNUT1eRzJjXp5') {
      _benhVienId = value;
    }
  }

  static String? benhVienPath;

  static void clear() {
    _benhVienId = '';
    benhVienPath = null;
  }
}
