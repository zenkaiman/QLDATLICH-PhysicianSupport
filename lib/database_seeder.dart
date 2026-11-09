import 'package:cloud_firestore/cloud_firestore.dart';

import 'support_doctor/room_status.dart';

class DatabaseSeeder {
  static Future<void> seedAllData() async {
    // Seeder placeholder: chỉ gọi [seedRoomStatusId] khi cần bổ sung
    // `trang_thai_id` cho một document phòng đã có sẵn. Không tự ghi
    // dữ liệu thật khi app khởi động.
  }

  /// Bổ sung/cập nhật mã trạng thái cho `PhongKham/{roomId}`.
  ///
  /// Ví dụ phòng trong Firebase Console:
  /// `await DatabaseSeeder.seedRoomStatusId(roomId: 'BV502_K001_HH001');`
  /// (mặc định 13 = Đang khám). Dùng `set(merge: true)` nên các field
  /// như `hospitalId`, `khoaId`, `ten_phong` vẫn giữ nguyên.
  static Future<void> seedRoomStatusId({
    required String roomId,
    int statusId = kRoomStatusDefaultId,
  }) async {
    if (!kRoomStatusLabels.containsKey(statusId)) {
      throw ArgumentError.value(
        statusId,
        'statusId',
        'Chỉ nhận 12 (tạm dừng), 13 (đang khám) hoặc 14 (đóng phòng).',
      );
    }
    await FirebaseFirestore.instance
        .collection('PhongKham')
        .doc(roomId)
        .set(<String, dynamic>{
          kRoomStatusField: statusId,
          'ngay_cap_nhat_trang_thai': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
