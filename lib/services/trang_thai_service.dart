import 'package:cloud_firestore/cloud_firestore.dart';

class TrangThaiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy tất cả trạng thái từ Firebase
  Future<List<Map<String, dynamic>>> getAllTrangThai() async {
    try {
      final snapshot = await _firestore.collection('TrangThai').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = int.parse(doc.id); // Convert document ID to int
        return data;
      }).toList();
    } catch (e) {
      print('❌ Lỗi khi lấy danh sách trạng thái: $e');
      return [];
    }
  }

  // Lấy trạng thái theo ID
  Future<Map<String, dynamic>?> getTrangThaiById(int id) async {
    try {
      final doc = await _firestore.collection('TrangThai').doc(id.toString()).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = id;
        return data;
      }
      return null;
    } catch (e) {
      print('❌ Lỗi khi lấy trạng thái: $e');
      return null;
    }
  }

  // Thêm trạng thái mới
  Future<void> addTrangThai({
    required int id,
    required String tenTrangThai,
    String? moTa,
  }) async {
    try {
      await _firestore.collection('TrangThai').doc(id.toString()).set({
        'id': id,
        'ten_trang_thai': tenTrangThai,
        'mo_ta': moTa,
      });
      print('✅ Đã thêm trạng thái: $tenTrangThai');
    } catch (e) {
      print('❌ Lỗi khi thêm trạng thái: $e');
      rethrow;
    }
  }

  // Cập nhật trạng thái
  Future<void> updateTrangThai({
    required int id,
    required String tenTrangThai,
    String? moTa,
  }) async {
    try {
      await _firestore.collection('TrangThai').doc(id.toString()).update({
        'ten_trang_thai': tenTrangThai,
        'mo_ta': moTa,
      });
      print('✅ Đã cập nhật trạng thái: $tenTrangThai');
    } catch (e) {
      print('❌ Lỗi khi cập nhật trạng thái: $e');
      rethrow;
    }
  }

  // Xóa trạng thái
  Future<void> deleteTrangThai(int id) async {
    try {
      await _firestore.collection('TrangThai').doc(id.toString()).delete();
      print('✅ Đã xóa trạng thái ID: $id');
    } catch (e) {
      print('❌ Lỗi khi xóa trạng thái: $e');
      rethrow;
    }
  }
}