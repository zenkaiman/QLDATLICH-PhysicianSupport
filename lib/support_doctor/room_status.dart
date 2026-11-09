/// Bảng dữ liệu dùng chung cho trạng thái phòng khám.
///
/// Document `PhongKham/{roomId}` lưu mã trạng thái trong trường
/// `trang_thai_id`. Cả màn hình chọn phòng (bảng trạng thái / chip lọc)
/// lẫn các nút trên QueueScreen đều đọc bảng này — sửa ở một chỗ là
/// đồng bộ toàn app.

/// 12 – bác sĩ tạm dừng khám, chưa gọi số mới.
const int kRoomStatusPausedId = 12;

/// 13 – phòng đang khám, gọi số bình thường.
const int kRoomStatusOpenId = 13;

/// 14 – đã đóng phòng khám, khoá mọi thao tác gọi số.
const int kRoomStatusClosedId = 14;

/// Mã dùng khi mở lại phòng hoặc khi document chưa có `trang_thai_id`.
const int kRoomStatusDefaultId = kRoomStatusOpenId;

/// Trường chính lưu mã trạng thái trên Firestore.
const String kRoomStatusField = 'trang_thai_id';

/// Các tên trường khác vẫn được đọc để hỗ trợ dữ liệu cũ/đặt tên khác.
const List<String> kRoomStatusFieldVariants = <String>[
  kRoomStatusField,
  'trangThaiId',
  'statusId',
  'id_trang_thai',
  'ma_trang_thai',
  'trang_thai',
  'trangThai',
];

/// Nhãn đầy đủ hiện trong bảng trạng thái và các chip lọc.
const Map<int, String> kRoomStatusLabels = <int, String>{
  kRoomStatusPausedId: 'Tạm dừng khám',
  kRoomStatusOpenId: 'Đang khám',
  kRoomStatusClosedId: 'Đóng phòng khám',
};
