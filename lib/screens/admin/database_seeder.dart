import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
   static Future<void> seedAdminAccounts() async {
    // Danh sách admin mẫu - BẠN CÓ THỂ SỬA EMAIL/MẬT KHẨU TẠI ĐÂY
    final List<Map<String, dynamic>> adminAccounts = [
      {
        'email': 'admin@mediconnect.vn',
        'password': 'Admin@123',
        'hoTen': 'Quản trị viên hệ thống',
        'soDienThoai': '0901234567',
        'role': 'admin',
        'maAdmin': 'AD001',
      },
      {
        'email': 'superadmin@mediconnect.vn',
        'password': 'Super@123',
        'hoTen': 'Super Admin',
        'soDienThoai': '0909999999',
        'role': 'admin',
        'maAdmin': 'AD002',
      },
    ];

    print('⏳ Đang kiểm tra và tạo tài khoản admin...');

    for (var adminData in adminAccounts) {
      final email = adminData['email'] as String;
      final password = adminData['password'] as String;

      try {
        // 1. Kiểm tra xem email đã tồn tại trong Auth chưa
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        
        if (methods.isEmpty) {
          // 2. Tạo tài khoản trong Firebase Auth
          final credential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          final uid = credential.user!.uid;

          // 3. Lưu thông tin admin vào Firestore collection 'admins'
          await _firestore.collection('admins').doc(uid).set({
            'uid': uid,
            'email': email,
            'ho_ten': adminData['hoTen'],
            'so_dien_thoai': adminData['soDienThoai'],
            'role': 'admin',
            'ma_admin': adminData['maAdmin'],
            'ngay_tao': DateTime.now().toIso8601String(),
            'da_xac_thuc_email': true, // Admin không cần xác thực email
            'trang_thai_id': TrangThaiId.hoatDong,
          });

          print('✅ Đã tạo admin: $email (UID: $uid)');
        } else {
          print('⚠️ Admin $email đã tồn tại, bỏ qua.');
        }
      } catch (e) {
        print('❌ Lỗi khi tạo admin $email: $e');
      }
    }

    print('✅ Hoàn tất seeding tài khoản admin!');
  }

  /// Hàm chạy tất cả seeder
  static Future<void> seedAllData() async {
    try {
      await seedAdminAccounts();
      print('✅ Hoàn tất seeding tất cả dữ liệu mẫu!');
    } 
    // ✅ SỬA LỖI: Xóa đoạn Firebase Rules bị dính vào đây, viết lại catch chuẩn
    catch (error) {
      print('❌ Seeder Firestore thất bại: $error');
    }
  }
}