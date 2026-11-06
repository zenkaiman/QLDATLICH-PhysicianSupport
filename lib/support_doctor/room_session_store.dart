import 'package:flutter/foundation.dart';

/// Trạng thái phòng hiển thị ở màn hình chọn khoa/phòng (trang chính).
enum RoomRuntimeStatus { open, paused, closed }

/// Ảnh chụp phiên hàng chờ của MỘT phòng, lưu trong bộ nhớ.
///
/// Không dùng cơ sở dữ liệu/Firebase: dữ liệu chỉ sống trong lúc app đang chạy.
class RoomSessionSnapshot {
  /// Phòng đã được mở màn hình hàng chờ lần nào chưa.
  /// Khi chưa mở, trang chính hiển thị đúng dữ liệu phòng ban đầu.
  bool started = false;

  /// Số hiện tại và số kế tiếp đang hiển thị ở màn hình hàng chờ.
  int current = 0;
  int next = 0;

  /// Các số đang đợi (đúng thứ tự sẽ gọi).
  List<int> waiting = <int>[];

  /// Các số đã xác nhận vắng mặt trong chế độ lấy số từ lịch hẹn.
  /// Danh sách này ngăn số vừa ghi vắng mặt bị nạp lại vào hàng chờ
  /// trong lúc trạng thái lịch hẹn trên Firebase chưa kịp đổi, hoặc
  /// khi lần ghi trạng thái đó chưa thành công.
  List<int> absentNumbers = <int>[];

  /// Các số đã xin đợi vừa được chèn lại trong phiên và đang chờ
  /// Firebase xác nhận lịch hẹn đã trở về trạng thái `2`. Danh sách
  /// này giữ tạm số trong hàng chờ khi rời phòng rồi mở lại trong lúc
  /// luồng lịch hẹn vẫn còn thấy trạng thái `7`, hoặc khi lần ghi về
  /// `2` chưa thành công.
  List<int> requeuedNumbers = <int>[];

  /// Ánh xạ số thứ tự → mã document lịch hẹn trong phiên. Cần giữ lại
  /// để khi rời phòng rồi mở lại vẫn ghi được trạng thái cho số đã xin
  /// đợi (`7`), vì lúc đó luồng lịch hẹn trạng thái `2` không còn phát
  /// document của số đó nữa.
  Map<int, String> appointmentIdByNumber = <int, String>{};

  /// Tên bệnh nhân gắn với từng số thứ tự lấy từ lịch hẹn trong phiên.
  /// Dùng để màn hình hàng chờ hiện đúng tên dưới STT đang khám/số tiếp
  /// theo, kể cả khi rời phòng rồi mở lại trong cùng phiên.
  Map<int, String> patientNameByNumber = <int, String>{};

  /// Tên bệnh nhân của các số đang nằm trong “SỐ ĐÃ CHO QUA”, giữ theo
  /// số lúc bấm “Đợi” (số này không đổi khi các số phía sau được đánh lại).
  Map<int, String> deferredNameByNumber = <int, String>{};

  /// STT lớn nhất đã biết từ danh sách lịch hẹn/phiên; không dùng để
  /// tự sinh thêm số bệnh nhân.
  int lastIssued = 0;

  /// Các số đã bấm "Đợi" (đang chờ chèn lại).
  List<int> deferredNumbers = <int>[];

  /// LỊCH SỬ tất cả số đã từng bấm "Đợi". Khác với [deferredNumbers], danh
  /// sách này KHÔNG bị xoá khi số được gọi lại, chèn lại hay xác nhận vắng
  /// mặt — chỉ xoá khi bấm "Đặt lại số".
  ///
  /// Dùng cho các việc khác (báo cáo, thống kê, màn hình khác…). Đọc qua:
  /// `RoomSessionStore.instance.sessionOf(roomId).deferredHistory`.
  List<int> deferredHistory = <int>[];

  /// Các lượt chèn đang chờ một số mốc TƯƠNG LAI xuất hiện trong hàng chờ.
  ///
  /// Mỗi phần tử là một số đã cho qua (`number`) cần nằm ngay sau số mốc
  /// (`afterNumber`) khi số mốc xuất hiện trong danh sách lịch hẹn. Khi số mốc xuất
  /// hiện, màn hình hàng chờ chuyển số này vào [waiting] và xoá lịch.
  List<({int number, int afterNumber})> scheduledFutureInserts =
      <({int number, int afterNumber})>[];

  /// Các số đã khám xong (dùng cho "Gọi lại").
  List<int> examinedNumbers = <int>[];

  /// Bác sĩ đang tạm dừng khám.
  bool paused = false;

  /// Trạng thái phòng: chỉ "Tạm dừng" khi bác sĩ đã nhấn nút "Tạm dừng khám".
  RoomRuntimeStatus get status =>
      paused ? RoomRuntimeStatus.paused : RoomRuntimeStatus.open;

  /// Số bệnh nhân đang đợi (bằng độ dài hàng chờ).
  int get waitingCount => waiting.length;

  /// Số bệnh nhân đã khám xong.
  int get examinedCount => examinedNumbers.length;

  /// Số hiện tại đang khám (0 nếu chưa có bệnh nhân nào được nạp).
  int get currentNumber => current;
}

/// Kho trạng thái dùng chung giữa màn hình chọn khoa/phòng và màn hình hàng chờ.
///
/// Nhờ lớp này, khi bác sĩ nhấn "Tạm dừng khám" / "Tiếp tục khám" ở màn hình
/// hàng chờ thì trang chính hiển thị đúng trạng thái mới ngay khi quay lại,
/// kèm số hiện tại – số đang đợi – số đã khám của phòng đó.
class RoomSessionStore extends ChangeNotifier {
  RoomSessionStore._();

  /// Singleton dùng chung cho toàn app (dữ liệu trong bộ nhớ).
  static final RoomSessionStore instance = RoomSessionStore._();

  final Map<String, RoomSessionSnapshot> _sessions =
      <String, RoomSessionSnapshot>{};

  /// Lấy (hoặc tạo) trạng thái của một phòng theo [roomId].
  RoomSessionSnapshot sessionOf(String roomId) =>
      _sessions.putIfAbsent(roomId, RoomSessionSnapshot.new);

  /// Lịch sử các số đã từng bấm "Đợi" của một phòng – bản chỉ đọc, dùng cho
  /// các việc khác (báo cáo, thống kê, màn hình khác…).
  List<int> deferredHistoryOf(String roomId) =>
      List<int>.unmodifiable(sessionOf(roomId).deferredHistory);

  /// Báo cho các màn hình đang lắng nghe vẽ lại.
  void refresh() => notifyListeners();
}
