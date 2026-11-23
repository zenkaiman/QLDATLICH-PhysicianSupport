import 'package:shared_preferences/shared_preferences.dart';

class StaffSession {
  static const _key = 'staff_code';

  /// save: lưu mã nhân viên đã đăng nhập để lần sau mở app tự vào lại.
  static Future<void> save(String staffCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, staffCode);
  }

  /// read: đọc mã nhân viên đã lưu (null nếu chưa có).
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// clear: xóa mã nhân viên đã lưu khi đăng xuất.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}