import 'package:cloud_firestore/cloud_firestore.dart';

import 'support_doctor/room_status.dart';

class DatabaseSeeder {
  static Future<void> seedAllData() async {
    // Seeder placeholder: chỉ gọi [seedRoomStatusId] khi cần bổ sung
    // cặp `trang_thai_id` + `trang_thai` cho document phòng đã có sẵn.
    // Không tự ghi dữ liệu thật khi app khởi động.
  }

  /// Bổ sung/cập nhật trạng thái cho `PhongKham/{roomId}`.
  ///
  /// Ghi đúng 2 field snake_case như luồng bấm nút:
  /// `trang_thai_id` = 12/13/14 và `trang_thai` = `tam_dung` / `kham` /
  /// `dong` tương ứng. Không ghi `trangThaiId` / `trangThai`.
  /// `set(merge: true)` giữ nguyên các field như `hospitalId`, `khoaId`,
  /// `ten_phong`.
  static Future<void> seedRoomStatusId({
    required String roomId,
    int statusId = kRoomStatusDefaultId,
  }) async {
    final statusCode = roomStatusCodeForId(statusId);
    if (statusCode == null) {
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
          kRoomStatusCodeField: statusCode,
          'ngay_cap_nhat_trang_thai': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
