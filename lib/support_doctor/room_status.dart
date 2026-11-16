/// Bảng dữ liệu dùng chung cho trạng thái phòng khám.
///
/// Document `PhongKham/{roomId}` có thể lưu trạng thái bằng 4 field:
/// `trang_thai_id` / `trangThaiId` (số) và `trang_thai` /
/// `trangThai` (mã chuỗi). App đọc cả 4 để đối chiếu, **ưu tiên field số**
/// khi dữ liệu lệch; khi bấm nút chỉ ghi 2 field snake_case
/// `trang_thai_id` + `trang_thai` lên Firestore.

/// 12 – bác sĩ tạm dừng khám, chưa gọi số mới.
const int kRoomStatusPausedId = 12;

/// 13 – phòng đang khám, gọi số bình thường.
const int kRoomStatusOpenId = 13;

/// 14 – đã đóng phòng khám, khoá mọi thao tác gọi số.
const int kRoomStatusClosedId = 14;

/// Mã dùng khi mở lại phòng hoặc khi document chưa có trạng thái.
const int kRoomStatusDefaultId = kRoomStatusOpenId;

/// Field số snake_case được ghi khi đổi trạng thái.
const String kRoomStatusField = 'trang_thai_id';

/// Field chuỗi snake_case được ghi khi đổi trạng thái.
const String kRoomStatusCodeField = 'trang_thai';

/// Các field số được đọc để đối chiếu (field snake_case đứng đầu).
const List<String> kRoomStatusNumericFieldVariants = <String>[
  kRoomStatusField,
  'trangThaiId',
  'statusId',
  'id_trang_thai',
  'ma_trang_thai',
];

/// Các field chuỗi được đọc để đối chiếu.
const List<String> kRoomStatusStringFieldVariants = <String>[
  kRoomStatusCodeField,
  'trangThai',
];

/// Tất cả tên field trạng thái từng được hỗ trợ (giữ để tương thích cũ).
const List<String> kRoomStatusFieldVariants = <String>[
  kRoomStatusField,
  'trangThaiId',
  'statusId',
  'id_trang_thai',
  'ma_trang_thai',
  kRoomStatusCodeField,
  'trangThai',
];

/// Mã chuỗi CHUẨN ghi vào `trang_thai`:
/// `12 → tam_dung`, `13 → dang_kham`, `14 → dong`.
/// `dang_kham` là mã chuẩn cho id 13, không còn là alias; mã ngắn `kham`
/// không được đọc dưới dạng mã chuỗi nữa.
const Map<int, String> kRoomStatusCodes = <int, String>{
  kRoomStatusPausedId: 'tam_dung',
  kRoomStatusOpenId: 'dang_kham',
  kRoomStatusClosedId: 'dong',
};

/// Ánh xạ ngược mã chuỗi → id.
///
/// 3 mã chuẩn đứng đầu; các mã dài/ngắn cũ còn lại vẫn được giữ để ĐỌC dữ
/// liệu Firestore hiện có. Mã `kham` đã bị gỡ hoàn toàn theo yêu cầu; khi
/// GHI luôn dùng [kRoomStatusCodes].
const Map<String, int> kRoomStatusIdsByCode = <String, int>{
  'tam_dung': kRoomStatusPausedId,
  'dang_kham': kRoomStatusOpenId,
  'dong': kRoomStatusClosedId,
  // Alias dữ liệu cũ.
  'tam_dung_kham': kRoomStatusPausedId,
  'dong_phong_kham': kRoomStatusClosedId,
  'dong_phong': kRoomStatusClosedId,
  'da_dong': kRoomStatusClosedId,
};

/// Nhãn đầy đủ hiện trong bảng trạng thái và các chip lọc.
const Map<int, String> kRoomStatusLabels = <int, String>{
  kRoomStatusPausedId: 'Tạm dừng khám',
  kRoomStatusOpenId: 'Đang khám',
  kRoomStatusClosedId: 'Đóng phòng khám',
};

/// Mã chuỗi chuẩn để ghi lên Firestore; `null` nếu id ngoài 12/13/14.
String? roomStatusCodeForId(int statusId) => kRoomStatusCodes[statusId];

/// Ảnh chụp 4 field trạng thái trong một document phòng.
///
/// [resolvedId] là kết quả sau khi đối chiếu: field số thắng field chuỗi.
/// [hasConflict] chỉ để mô tả dữ liệu lệch, không chặn thao tác và không
/// hiện lên UI (đúng yêu cầu “chỉ dùng để thay đổi trên Firebase”).
typedef ClinicRoomStatusRead = ({
  int? snakeId,
  int? camelId,
  String? snakeCode,
  String? camelCode,
  int? resolvedId,
  bool hasConflict,
});

int? _parseRoomStatusId(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? _readRoomStatusCode(Object? value) {
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  return null;
}

/// Đọc **toàn bộ 4 field** `trang_thai_id`, `trangThaiId`, `trang_thai`,
/// `trangThai`, cộng các tên legacy, rồi trả id đã đối chiếu.
ClinicRoomStatusRead readClinicRoomStatus(Map<String, Object?> data) {
  final snakeId = _parseRoomStatusId(data[kRoomStatusField]);
  final camelId = _parseRoomStatusId(data['trangThaiId']);
  final snakeCode = _readRoomStatusCode(data[kRoomStatusCodeField]);
  final camelCode = _readRoomStatusCode(data['trangThai']);

  int? numericId;
  for (final key in kRoomStatusNumericFieldVariants) {
    numericId = _parseRoomStatusId(data[key]);
    if (numericId != null) break;
  }

  int? codeId;
  for (final key in kRoomStatusStringFieldVariants) {
    final code = _readRoomStatusCode(data[key]);
    if (code == null) continue;
    codeId = kRoomStatusIdsByCode[code.toLowerCase()] ?? int.tryParse(code);
    if (codeId != null) break;
  }

  return (
    snakeId: snakeId,
    camelId: camelId,
    snakeCode: snakeCode,
    camelCode: camelCode,
    resolvedId: numericId ?? codeId,
    hasConflict: numericId != null && codeId != null && numericId != codeId,
  );
}
