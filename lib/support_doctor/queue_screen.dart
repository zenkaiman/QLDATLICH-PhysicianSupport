import 'dart:async';

import 'package:flutter/material.dart';

import 'room_session_store.dart';
import 'room_status.dart';

/// Một lượt đã qua: số thứ tự + có phải bệnh nhân xin đợi hay không.
typedef PassedEntry = ({int number, bool deferred});

/// Một yêu cầu chèn từ màn hình chèn: số cần chèn + một số mốc BẤT KỲ mà
/// số đó sẽ nằm NGAY SAU. Số mốc không nhất thiết đang có trong hàng chờ:
/// nếu chưa xuất hiện trong danh sách lịch hẹn đã xác nhận, yêu cầu được
/// giữ lịch đến khi số mốc xuất hiện trong một đợt cập nhật sau.
/// `afterNumber == null` là trường hợp đặc biệt đưa số lên đầu hàng chờ
/// (người dùng nhập 0). Màn hình chèn trả về cả một `List<InsertResult>`
/// để chèn nhiều số cùng một lần.
typedef InsertResult = ({int number, int? afterNumber});

/// Lựa chọn trong bảng "Đợi / Gọi lại": số được chọn + hành động áp dụng.
/// hold = true  -> cho số đó qua lượt (đợi), hold = false -> gọi lại số đã khám.
typedef QueueAction = ({int number, bool hold});

/// Kết quả cần báo về cho lịch hẹn gắn với một số thứ tự.
enum AppointmentOutcome { examined, absent, deferred, requeued }

/// Một đợt cập nhật số thứ tự lấy từ danh sách lịch hẹn đủ điều kiện.
///
/// [numbers] là các số thứ tự duy nhất đã sắp tăng dần;
/// [appointmentIdByNumber] ánh xạ mỗi số sang mã lịch hẹn tương ứng để
/// nơi cung cấp dữ liệu ghi ngược trạng thái khi khám xong/vắng mặt,
/// xin đợi hoặc chèn lại vào hàng chờ.
/// [patientNameByNumber] ánh xạ mỗi số sang tên bệnh nhân của đúng lịch
/// hẹn đó để hiện tên ngay dưới STT tương ứng.
typedef AppointmentQueueUpdate = ({
  List<int> numbers,
  Map<int, String> appointmentIdByNumber,
  Map<int, String> patientNameByNumber,
});

/// Trạng thái hàng chờ sau một lần đồng bộ với danh sách lịch hẹn.
typedef AppointmentSyncResult = ({
  int current,
  int next,
  List<int> waiting,
  List<InsertResult> scheduledInserts,
  int lastIssued,
});

/// Trạng thái của nguồn dữ liệu thời gian thực (luồng lịch hẹn) để thẻ
/// "Thông báo từ Bác sĩ" cho biết thẻ đang chạy realtime hay chỉ chạy
/// bằng dữ liệu/giờ của chính máy.
enum QueueFeedState {
  /// Không có luồng lịch hẹn (chế độ demo/offline): vẫn hiện giờ máy.
  local,

  /// Đã đăng ký nghe luồng nhưng chưa nhận được đợt cập nhật đầu tiên.
  connecting,

  /// Đang nhận cập nhật STT từ Firebase theo thời gian thực.
  live,

  /// Luồng báo lỗi (mất kết nối / không đọc được dữ liệu).
  error,
}

/// `true` nếu số mốc của [insert] lớn hơn STT lớn nhất đã biết từ
/// danh sách lịch hẹn ([highestKnownNumber]). Những yêu cầu này chưa
/// vào hàng chờ ngay mà được giữ lịch; khi số mốc xuất hiện trong một
/// đợt cập nhật lịch hẹn sau, số được chèn sẽ nằm ngay phía sau số mốc.
bool _isFutureScheduledInsert(InsertResult insert, int highestKnownNumber) =>
    insert.afterNumber != null && insert.afterNumber! > highestKnownNumber;

/// Gộp nhiều số đã cho qua vào [waiting], mỗi số nằm NGAY SAU số mốc của
/// nó (hoặc ở đầu hàng khi `afterNumber` là `null`).
///
/// Hàm chỉ áp dụng các yêu cầu có thể xếp NGAY vào hàng chờ hiện tại;
/// các số mốc tương lai (xem [_isFutureScheduledInsert]) phải được bên
/// gọi tách ra giữ lịch trước. Cách xác định khe chèn trên hàng chờ GỐC:
///  - số mốc đang nằm trong hàng chờ    -> ngay sau chính số mốc;
///  - số mốc là [nextNumber]            -> đầu hàng chờ (ngay sau số
///    tiếp theo trong thứ tự gọi);
///  - số mốc đã có trong danh sách nhưng không  -> khe theo thứ tự số: ngay
///    còn trong hàng chờ                 trước số đang đợi đầu tiên
///                                         lớn hơn số mốc (cuối hàng
///                                         nếu không có số nào lớn hơn).
///
/// Mọi số mốc đều được đối chiếu với hàng chờ GỐC (trước khi chèn), nên
/// hàm dựng danh sách mới trong một lượt thay vì chèn lần lượt. Nhiều số
/// cùng một số mốc sẽ xếp liên tiếp ngay sau số mốc đó theo đúng thứ tự
/// xuất hiện trong [inserts]. Số nào vốn đã có mặt trong [waiting] (vd.
/// trạng thái khôi phục từ phiên cũ) sẽ được rút ra trước rồi đặt lại
/// theo số mốc mới, không bị trùng số.
List<int> _waitingAfterInserts(
  List<int> waiting,
  List<InsertResult> inserts, {
  int? nextNumber,
}) {
  if (inserts.isEmpty) return List<int>.of(waiting);
  // Mỗi số chỉ chèn một lần (giữ yêu cầu đầu tiên nếu bị trùng).
  final seen = <int>{};
  final uniqueInserts = <InsertResult>[
    for (final insert in inserts)
      if (seen.add(insert.number)) insert,
  ];
  final inserting = uniqueInserts.map((insert) => insert.number).toSet();
  // Hàng chờ nền: bỏ các số sắp (di)chuyển để không xuất hiện 2 lần.
  final base = waiting.where((n) => !inserting.contains(n)).toList();
  // Nhóm các số chèn theo khe nằm SAU số mốc, đã quy đổi khe đó sang chỉ
  // số của [base] bằng cách trừ số phần tử bị rút ra ở phía trước khe.
  final byIndex = <int, List<int>>{};
  for (final insert in uniqueInserts) {
    final afterNumber = insert.afterNumber;
    final int originalTarget;
    if (afterNumber == null) {
      // Nhập 0: đưa lên đầu hàng chờ.
      originalTarget = 0;
    } else {
      final afterIndex = waiting.indexOf(afterNumber);
      if (afterIndex != -1) {
        // Số mốc đang có trong hàng chờ: nằm ngay sau chính nó.
        originalTarget = afterIndex + 1;
      } else if (afterNumber == nextNumber) {
        // Ngay sau "số tiếp theo" trong thứ tự gọi là đầu hàng chờ.
        originalTarget = 0;
      } else {
        // Số mốc đã có trong danh sách nhưng không còn trong hàng chờ: xếp theo thứ
        // tự số, ngay trước số đang đợi đầu tiên lớn hơn số mốc.
        final firstGreaterIndex = waiting.indexWhere((n) => n > afterNumber);
        originalTarget = firstGreaterIndex == -1
            ? waiting.length
            : firstGreaterIndex;
      }
    }
    var removedBefore = 0;
    final scanEnd = originalTarget < waiting.length
        ? originalTarget
        : waiting.length;
    for (var i = 0; i < scanEnd; i++) {
      if (inserting.contains(waiting[i])) removedBefore++;
    }
    var index = originalTarget - removedBefore;
    if (index < 0) index = 0;
    if (index > base.length) index = base.length;
    byIndex.putIfAbsent(index, () => <int>[]).add(insert.number);
  }
  final merged = <int>[];
  for (var i = 0; i <= base.length; i++) {
    merged.addAll(byIndex[i] ?? const <int>[]);
    if (i < base.length) merged.add(base[i]);
  }
  return merged;
}

/// Đồng bộ hàng chờ (chế độ lấy số từ lịch hẹn) với tập số đủ điều kiện
/// mới nhất.
///
/// Quy tắc giữ nguyên thứ tự gọi đã hình thành trên màn hình:
///  - số đang khám luôn được giữ, kể cả khi lịch hẹn của nó vừa đổi
///    trạng thái ở nơi khác (bệnh nhân đang ở trong phòng);
///  - số tiếp theo và các số đang đợi tự rời hàng nếu không còn đủ
///    điều kiện;
///  - số đủ điều kiện mới xuất hiện được nối vào CUỐI hàng chờ theo thứ
///    tự số tăng dần, để bệnh nhân được xác nhận muộn không chen ngang
///    trước những người đã có lượt;
///  - các số đã qua lượt, đã xác nhận vắng mặt trên chính máy này và
///    các số đang giữ lịch chèn không bị nạp lại lần hai.
///
/// Giá trị 0 ở [current]/[next] nghĩa là vị trí đó chưa có số. Hàm là
/// hàm thuần để có thể kiểm thử độc lập với giao diện.
AppointmentSyncResult _reconcileAppointmentQueue({
  required List<int> eligibleNumbers,
  required int current,
  required int next,
  required List<int> waiting,
  required Set<int> passedNumbers,
  required Set<int> suppressedNumbers,
  required List<InsertResult> scheduledInserts,
  required int lastIssued,
}) {
  final eligibleSorted = eligibleNumbers.where((n) => n > 0).toSet().toList()
    ..sort();
  final eligible = eligibleSorted.toSet();
  var scheduled = List<InsertResult>.of(scheduledInserts);

  final retainedNext = next > 0 && eligible.contains(next) ? next : 0;
  final seenWaiting = <int>{};
  final newWaiting = <int>[
    for (final number in waiting)
      if (number > 0 && eligible.contains(number) && seenWaiting.add(number))
        number,
  ];

  final accounted = <int>{
    if (current > 0) current,
    if (retainedNext > 0) retainedNext,
    ...newWaiting,
    ...passedNumbers.where((n) => n > 0),
    ...suppressedNumbers.where((n) => n > 0),
    for (final insert in scheduled)
      if (insert.number > 0) insert.number,
  };
  for (final number in eligibleSorted) {
    if (accounted.add(number)) newWaiting.add(number);
  }

  // Đưa các số đã lên lịch vào ngay sau số mốc khi số mốc đã có mặt
  // trong lượt gọi. Vòng lặp cho phép cả chuỗi lịch chèn nối tiếp nhau.
  var progressed = true;
  while (progressed) {
    progressed = false;
    final insertedAfterCounts = <int, int>{};
    for (final insert in List<InsertResult>.of(scheduled)) {
      if (!eligible.contains(insert.number) ||
          suppressedNumbers.contains(insert.number)) {
        continue;
      }
      final afterNumber = insert.afterNumber;
      int? insertIndex;
      if (afterNumber == null ||
          (retainedNext > 0 && afterNumber == retainedNext)) {
        final countKey = afterNumber ?? 0;
        final insertedCount = insertedAfterCounts[countKey] ?? 0;
        insertIndex = insertedCount;
        insertedAfterCounts[countKey] = insertedCount + 1;
      } else {
        final afterIndex = newWaiting.indexOf(afterNumber);
        if (afterIndex != -1) {
          final insertedCount = insertedAfterCounts[afterNumber] ?? 0;
          insertIndex = afterIndex + 1 + insertedCount;
          insertedAfterCounts[afterNumber] = insertedCount + 1;
        }
      }
      if (insertIndex == null) continue;
      if (!newWaiting.contains(insert.number)) {
        newWaiting.insert(insertIndex, insert.number);
      }
      scheduled.remove(insert);
      progressed = true;
    }
  }

  var synchronizedCurrent = current;
  var synchronizedNext = retainedNext;
  if (synchronizedCurrent <= 0 && synchronizedNext > 0) {
    synchronizedCurrent = synchronizedNext;
    synchronizedNext = 0;
  }
  if (synchronizedCurrent <= 0 && newWaiting.isNotEmpty) {
    synchronizedCurrent = newWaiting.removeAt(0);
  }
  if (synchronizedCurrent > 0 &&
      synchronizedNext <= 0 &&
      newWaiting.isNotEmpty) {
    synchronizedNext = newWaiting.removeAt(0);
  }

  var synchronizedLastIssued = lastIssued;
  for (final number in <int>[
    ...eligibleSorted,
    synchronizedCurrent,
    synchronizedNext,
    ...newWaiting,
    ...passedNumbers,
    for (final insert in scheduled) insert.number,
  ]) {
    if (number > synchronizedLastIssued) {
      synchronizedLastIssued = number;
    }
  }

  return (
    current: synchronizedCurrent,
    next: synchronizedNext,
    waiting: newWaiting,
    scheduledInserts: scheduled,
    lastIssued: synchronizedLastIssued,
  );
}

/// Bộ màu & hiệu ứng dùng chung cho toàn giao diện.
abstract final class _Ui {
  static const Color bgTop = Color(0xFFF9FAFE);
  static const Color bgBottom = Color(0xFFEBEFF8);
  static const Color cardBorder = Color(0xFFEEF0F7);
  static const Color divider = Color(0xFFEFF1F7);
  static const Color textPrimary = Color(0xFF191C26);
  static const Color textSecondary = Color(0xFF8B90A0);
  static const Color textFaint = Color(0xFFAAB0BE);
  static const Color green = Color(0xFF35C95B);
  static const Color amber = Color(0xFFFFC400);
  static const Color red = Color(0xFFFF534B);
  static const Color chipIdleText = Color(0xFF7C8293);

  /// Bóng mềm cho các thẻ trắng.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x12101828), blurRadius: 26, offset: Offset(0, 14)),
  ];

  /// Bóng mềm cho nút phụ (nền trắng).
  static const List<BoxShadow> quietShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0F101828), blurRadius: 12, offset: Offset(0, 6)),
  ];

  /// Bóng màu cho nút chính / nút xanh.
  static const List<BoxShadow> blueShadow = <BoxShadow>[
    BoxShadow(color: Color(0x3D107FE8), blurRadius: 18, offset: Offset(0, 9)),
  ];
  static const List<BoxShadow> greenShadow = <BoxShadow>[
    BoxShadow(color: Color(0x3D22A94E), blurRadius: 18, offset: Offset(0, 9)),
  ];

  static const LinearGradient greenCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF41D366), Color(0xFF1FA24C)],
  );
  static const LinearGradient amberCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54A), Color(0xFFFF9000)],
  );
  static const LinearGradient redChip = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6A5E), Color(0xFFEF2E26)],
  );
  static const LinearGradient blueButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2196FF), Color(0xFF0067DE)],
  );
  static const LinearGradient greenButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF43D26A), Color(0xFF1E9C48)],
  );
}

class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
    this.sessionId = 'PK3-20260918-01',
    this.roomId = 'PK3',
    this.staffId = 'NV-VNT',
    this.roomName = 'Phòng khám 3',
    this.departmentName = 'Khoa Tim',
    this.hospitalName = 'Bệnh viện Bạch Mai',
    this.initialCurrent = 0,
    this.startingNumber = 0,
    this.appointmentQueueStream,
    this.appointmentQueueForDay,
    this.onAppointmentOutcome,
    this.onRenumberAppointment,
    this.roomStatusStream,
    this.onRoomStatusChanged,
  });

  /// Mã phiên khám – gom các lượt của cùng một buổi/ngày.
  final String sessionId;

  /// Mã phòng khám.
  final String? roomId;

  /// Mã nhân viên phụ trách phòng khám.
  final String? staffId;

  /// Thông tin phòng/khoa được chọn ở màn hình trước.
  final String roomName;
  final String departmentName;
  final String hospitalName;

  /// Giữ lại để tương thích với mã gọi cũ; KHÔNG còn dùng để tạo số.
  /// Hàng chờ chỉ hiện các STT có trong [appointmentQueueStream].
  final int initialCurrent;

  /// Giữ lại để tương thích với mã gọi cũ; KHÔNG còn dùng để đặt lại
  /// dãy số. Nút “Đặt lại số” nạp lại đúng danh sách lịch hẹn hiện có.
  final int startingNumber;

  /// Luồng số thứ tự lấy từ danh sách lịch hẹn đã xác nhận của phòng.
  ///
  /// Đây là nguồn STT DUY NHẤT của màn hình: QueueScreen không tự sinh
  /// thêm số ngoài những STT mà luồng này cung cấp. Nếu để `null`, màn
  /// hình không tự tạo số nào; hàng chờ bắt đầu trống và chỉ có thể khôi
  /// phục trạng thái phiên đã nạp từ một luồng lịch hẹn trước đó.
  final Stream<AppointmentQueueUpdate>? appointmentQueueStream;

  /// Hàm tạo luồng STT cho một ngày bất kỳ, dùng bởi bộ chọn lịch ngay
  /// trên màn hình gọi số. Khi người dùng đổi ngày, màn hình hủy luồng cũ,
  /// xoá trạng thái hàng chờ trên máy rồi nghe luồng của ngày mới.
  ///
  /// Nếu `null` (chế độ demo/offline), màn hình vẫn cho chọn ngày nhưng
  /// dùng [appointmentQueueStream] như cũ.
  final Stream<AppointmentQueueUpdate> Function(DateTime day)?
  appointmentQueueForDay;

  /// Báo kết quả khám xong/vắng mặt về nơi lưu lịch hẹn.
  ///
  /// Callback nhận mã lịch hẹn đã được ánh xạ từ số thứ tự trong các
  /// đợt cập nhật của [appointmentQueueStream]. Lỗi của callback chỉ
  /// hiện thông báo, không chặn thao tác gọi số trên màn hình.
  final Future<void> Function(String appointmentId, AppointmentOutcome outcome)?
  onAppointmentOutcome;

  /// Ghi số thứ tự mới của một lịch hẹn lên Firebase khi nhân viên chèn
  /// số: số vừa chèn nhận `số mốc + 1`, các số phía sau tăng thêm 1.
  ///
  /// Lỗi của callback chỉ hiện thông báo, không chặn thao tác hàng chờ.
  final Future<void> Function(String appointmentId, int soThuTu)?
  onRenumberAppointment;

  /// Luồng id trạng thái đã đối chiếu từ 4 field của `PhongKham/{roomId}`
  /// (12 tạm dừng / 13 đang khám / 14 đóng phòng), ưu tiên field số.
  /// `null` = không đọc được field hợp lệ, lúc đó màn hình giữ nguyên
  /// trạng thái phiên local.
  final Stream<int?>? roomStatusStream;

  /// Ghi `trang_thai_id` + `trang_thai` lên Firestore khi bác sĩ bấm nút
  /// Tạm dừng / Tiếp tục hoặc Đóng / Mở phòng khám.
  final Future<void> Function(int statusId)? onRoomStatusChanged;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  /// Số hiện tại khởi tạo theo phòng được chọn.
  late int current;
  late int next;

  /// Hàng đợi hữu hạn, chỉ chứa các STT đã nhận từ danh sách lịch hẹn.
  /// Khi danh sách bệnh nhân đã hết, hàng đợi để trống thay vì tự sinh
  /// thêm số mới. Số được chèn lại từ "SỐ ĐÃ CHO QUA" có thể nằm ở vị
  /// trí bất kỳ trong hàng, nên thứ tự có thể không tăng dần tuyệt đối.
  late List<int> waiting;

  /// STT lớn nhất đã biết từ danh sách lịch hẹn/phiên hiện tại. Giá trị
  /// này chỉ dùng để nhận biết số mốc chèn ở tương lai, không dùng để
  /// tự sinh thêm STT.
  late int lastIssued;

  /// Phòng đã bấm nút “Bắt đầu” chưa. Khi chưa bấm, số hiện tại giữ đúng
  /// số bắt đầu mặc định là 0 và mọi số nằm trong hàng chờ; nút chính hiện
  /// chữ “Bắt đầu”, bấm lần đầu mới đưa số nhỏ nhất lên “đang khám”, sau đó
  /// nút đổi thành “Tiếp theo”.
  bool _daBatDau = false;

  /// Các số đã qua lượt:
  ///  - deferred = false: đã khám xong (dùng cho "Gọi lại số").
  ///  - deferred = true : bệnh nhân xin đợi (dùng cho "+ Chèn" để chèn lại).
  final List<PassedEntry> passed = <PassedEntry>[];

  /// LỊCH SỬ các số đã từng bấm "Đợi" – lưu lại để dùng cho việc khác.
  /// Không bị xoá khi số được gọi lại / chèn lại / xác nhận vắng mặt.
  final List<int> _deferredHistory = <int>[];

  /// Các số đã được chèn theo một số mốc chưa xuất hiện trong danh sách
  /// lịch hẹn đã xác nhận. Khi số mốc xuất hiện trong đợt cập nhật sau,
  /// số tương ứng tự nằm ngay phía sau số mốc và lịch của nó được xoá.
  final List<InsertResult> _scheduledFutureInserts = <InsertResult>[];

  /// Đăng ký nghe luồng danh sách lịch hẹn của phòng.
  StreamSubscription<AppointmentQueueUpdate>? _appointmentSubscription;

  /// Đăng ký nghe trạng thái đã đối chiếu từ 4 field của chính phòng này.
  StreamSubscription<int?>? _roomStatusSubscription;

  /// Mã trạng thái nhận gần nhất từ Firestore (`null` = chưa có field hợp lệ).
  int? _roomStatusId;

  /// Ngày đang nạp lịch hẹn vào hàng chờ. Mặc định hôm nay; người đổi qua
  /// bộ chọn lịch trên chính màn hình gọi số. Luôn chỉ còn phần ngày.
  DateTime _selectedQueueDay = _queueDayOnly(DateTime.now());

  /// Số hiệu lượt đăng ký luồng lịch hẹn. Tăng mỗi lần đổi ngày để bỏ qua
  /// các đợt emit muộn của luồng cũ.
  int _appointmentStreamGeneration = 0;

  /// Tập số lịch hẹn đủ điều kiện trong lần đồng bộ gần nhất.
  List<int> _eligibleAppointmentNumbers = <int>[];

  /// Ánh xạ tích luỹ số thứ tự → mã lịch hẹn, dùng khi ghi ngược
  /// các trạng thái khám xong/vắng mặt/xin đợi/chèn lại.
  final Map<int, String> _appointmentIdByNumber = <int, String>{};

  /// Ánh xạ tích luỹ số thứ tự → tên bệnh nhân của lịch hẹn tương ứng.
  /// Chỉ nhận dữ liệu từ các lịch hẹn đã qua bộ lọc đúng phòng/bệnh
  /// viện, đúng ngày đang chọn trên bộ chọn lịch và đúng trạng thái đủ
  /// điều kiện.
  final Map<int, String> _patientNameByNumber = <int, String>{};

  /// Các số đã xác nhận vắng mặt trên máy này; không nạp lại từ luồng
  /// lịch hẹn trong lúc Firebase chưa kịp đổi trạng thái.
  final Set<int> _absentAppointmentNumbers = <int>{};

  /// Tên bệnh nhân của các số đang nằm trong “SỐ ĐÃ CHO QUA”, giữ theo
  /// đúng số lúc bấm “Đợi” để dải chip vẫn hiện đúng tên kể cả khi các số
  /// phía sau đã được đánh lại (−1) và trùng số.
  final Map<int, String> _patientNameDaChoQua = <int, String>{};

  /// Mã lịch hẹn của từng số đang nằm trong “SỐ ĐÃ CHO QUA”, chốt ngay
  /// lúc bấm “Đợi” — số hiển thị có thể trùng với số của người khác đang
  /// chạy, nên khi chèn lại phải dùng đúng mã lịch hẹn này.
  final Map<int, String> _maLichHenDaChoQua = <int, String>{};

  /// Ánh xạ tạm mã lịch hẹn → số thứ tự MỚI vừa ghi sau khi chèn số.
  /// Luồng Firebase còn trả số cũ trong vài giây; ánh xạ này giữ nguyên
  /// số mới trên màn hình cho tới khi document trả về đúng số đó.
  final Map<String, int> _pendingRenumberByAppointmentId = <String, int>{};

  /// Các số đã xin đợi vừa được chèn lại trên máy này và đang chờ
  /// Firebase đưa lịch hẹn về trạng thái đã xác nhận (`2`). Chúng được
  /// giữ tạm trong hàng chờ để không bị đợt đồng bộ còn thấy trạng
  /// thái `7` loại ra trước khi lần ghi về `2` được phản ánh.
  final Set<int> _requeuedAppointmentNumbers = <int>{};

  /// Chiều cao CỐ ĐỊNH của bảng trạng thái hàng chờ (thẻ chứa "SỐ ĐANG
  /// ĐỢI" / "SỐ ĐÃ CHO QUA" / "SỐ CHỜ TỚI SỐ MỐC"). Bảng không đổi kích
  /// thước khi các danh sách trống/có dữ liệu hay khi lịch chèn xuất
  /// hiện/biến mất, nên hàng nút bên dưới không bao giờ bị dịch chuyển
  /// trong lúc người dùng đang bấm (tránh bấm nhầm nút).
  /// Hai mức dưới đây đã cộng đủ padding của thẻ, viền 1px của thẻ và
  /// mọi ô/dòng có chiều cao cố định bên trong bảng.
  static const double _queuePanelHeightCompact = 420;
  static const double _queuePanelHeightRegular = 434;

  /// Chiều cao cố định của từng dòng tiêu đề mục và dòng chữ chú thích
  /// trong bảng trạng thái (chú thích tối đa 2 dòng).
  static const double _queuePanelHeaderHeight = 22;
  static const double _queuePanelHintHeight = 34;

  /// Chiều cao cố định của dải chip lịch chèn theo số mốc tương lai.
  static const double _scheduledChipStripHeight = 38;

  int? selected;
  bool paused = false;

  /// Phòng đã đóng (nút dưới cùng). Khi đóng, mọi thao tác gọi số bị khoá
  /// và thẻ thông báo chuyển sang trạng thái "đóng phòng khám".
  bool closed = false;
  String? message;

  /// Trạng thái luồng dữ liệu realtime. Thẻ thông báo dùng giá trị này để
  /// hiện nhãn "Đang kết nối…" / "Realtime" / "Mất kết nối" / "Giờ máy".
  QueueFeedState _feedState = QueueFeedState.local;

  /// Thời điểm (giờ máy) của lần bấm "Tạm dừng khám" / "Tiếp tục khám"
  /// gần nhất. Không có đồng hồ chạy liên tục: giá trị chỉ được chụp tại
  /// đúng thời điểm bấm nút rồi giữ nguyên cho đến lần bấm sau.
  DateTime? _lastStatusChangeAt;
  String _lastStatusChangeLabel = '';

  /// Khóa lưu trạng thái phòng trong [RoomSessionStore] (ưu tiên mã phòng).
  String get _storeKey => widget.roomId ?? widget.sessionId;

  @override
  void initState() {
    super.initState();
    final snapshot = RoomSessionStore.instance.sessionOf(_storeKey);
    if (snapshot.started) {
      // Mở lại phòng: khôi phục đúng trạng thái đã có trong bộ nhớ
      // (số hiện tại, hàng chờ, các số đã đợi/đã khám, tạm dừng…).
      current = snapshot.current;
      next = snapshot.next;
      waiting = List<int>.of(snapshot.waiting);
      lastIssued = snapshot.lastIssued;
      passed
        ..clear()
        ..addAll(
          snapshot.examinedNumbers.map(
            (number) => (number: number, deferred: false),
          ),
        )
        ..addAll(
          snapshot.deferredNumbers.map(
            (number) => (number: number, deferred: true),
          ),
        );
      _deferredHistory
        ..clear()
        ..addAll(snapshot.deferredHistory);
      _scheduledFutureInserts
        ..clear()
        ..addAll(
          snapshot.scheduledFutureInserts.map(
            (insert) =>
                (number: insert.number, afterNumber: insert.afterNumber),
          ),
        );
      _absentAppointmentNumbers
        ..clear()
        ..addAll(snapshot.absentNumbers);
      _requeuedAppointmentNumbers
        ..clear()
        ..addAll(snapshot.requeuedNumbers);
      _appointmentIdByNumber
        ..clear()
        ..addAll(snapshot.appointmentIdByNumber);
      _patientNameByNumber
        ..clear()
        ..addAll(snapshot.patientNameByNumber);
      _patientNameDaChoQua
        ..clear()
        ..addAll(snapshot.deferredNameByNumber);
      _maLichHenDaChoQua
        ..clear()
        ..addAll(snapshot.deferredAppointmentIdByNumber);
      _daBatDau = snapshot.daBatDau || snapshot.current > 0;
      paused = snapshot.paused;
      closed = snapshot.closed;
      // Mốc giờ của lần bấm Tạm dừng / Tiếp tục vẫn đứng yên khi rời
      // phòng rồi mở lại trong cùng phiên chạy app.
      _lastStatusChangeAt = snapshot.statusChangedAt;
      _lastStatusChangeLabel = snapshot.statusChangeLabel;
    } else {
      // Lần đầu mở phòng: KHÔNG tự sinh số thứ tự.
      // Chỉ hiện số khi lịch hẹn thật của phòng trong ngày đang chọn có
      // `so_thu_tu`
      // (stream lịch hẹn sẽ nạp số vào); trước đó màn hình để trống
      // ("Chưa có bệnh nhân nào…") thay vì mặc định số 1.
      final start = widget.initialCurrent > 0 ? widget.initialCurrent : 0;
      current = start;
      next = 0;
      waiting = <int>[];
      lastIssued = start;
      // Số bắt đầu mặc định là 0; chỉ khi nơi gọi truyền sẵn [initialCurrent]
      // mới coi như phòng đã bắt đầu gọi số.
      _daBatDau = start > 0;
      snapshot
        ..started = true
        ..paused = false;
    }
    final roomStatusStream = widget.roomStatusStream;
    if (roomStatusStream != null) {
      _roomStatusSubscription = roomStatusStream.listen(
        _applyRoomStatusId,
        onError: (_) {
          // Lỗi đọc trạng thái không chặn hàng chờ; giữ trạng thái local.
          notify('Không đọc được trạng thái phòng khám. Kiểm tra kết nối.');
        },
      );
    }

    // Đăng ký luồng lịch hẹn cho ngày đang chọn (mặc định hôm nay).
    // Khi đổi lịch, hàm này sẽ hủy luồng cũ và nghe luồng của ngày mới.
    _subscribeToAppointmentQueue(_selectedQueueDay);

    // Đẩy trạng thái ra kho chung sau khi frame đầu vẽ xong, để trang chính
    // (màn hình chọn khoa/phòng) nhận đúng thông tin khi quay lại.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRoomState();
    });
  }

  @override
  void dispose() {
    _appointmentStreamGeneration++;
    _roomStatusSubscription?.cancel();
    _appointmentSubscription?.cancel();
    super.dispose();
  }

  /// Áp id trạng thái đã đối chiếu từ 4 field `PhongKham/{roomId}` vào
  /// banner và các nút: 12 → Tạm dừng khám, 13 → Đang khám,
  /// 14 → Đóng phòng khám. `null` trả quyền về trạng thái phiên local.
  void _applyRoomStatusId(int? id) {
    if (!mounted || id == _roomStatusId) return;
    _roomStatusId = id;
    if (id == null) return;
    final nextPaused = id == kRoomStatusPausedId;
    final nextClosed = id == kRoomStatusClosedId;
    if (paused == nextPaused && closed == nextClosed) return;
    setState(() {
      paused = nextPaused;
      closed = nextClosed;
      // Trạng thái đến từ Firestore/thiết bị khác: dùng lại thông báo
      // mặc định theo trạng thái mới, KHÔNG chụp lại mốc giờ máy.
      message = null;
    });
    _syncRoomState();
  }

  /// Đăng ký nghe luồng lịch hẹn của [day].
  ///
  /// Hủy đăng ký cũ trước, rồi dùng [QueueScreen.appointmentQueueForDay]
  /// nếu có; nếu không có (demo/offline) dùng luồng cố định
  /// [QueueScreen.appointmentQueueStream]. [generation] chặn các emit muộn
  /// của luồng ngày cũ lọt sang ngày mới.
  void _subscribeToAppointmentQueue(DateTime day) {
    final generation = ++_appointmentStreamGeneration;
    final previous = _appointmentSubscription;
    _appointmentSubscription = null;
    if (previous != null) unawaited(previous.cancel());
    if (!mounted) return;

    final stream =
        widget.appointmentQueueForDay?.call(day) ??
        widget.appointmentQueueStream;
    if (stream == null) {
      setState(() => _feedState = QueueFeedState.local);
      return;
    }

    setState(() => _feedState = QueueFeedState.connecting);
    _appointmentSubscription = stream.listen(
      (update) {
        if (generation == _appointmentStreamGeneration) {
          _applyAppointmentUpdate(update);
        }
      },
      onError: (Object _, StackTrace _) {
        if (!mounted || generation != _appointmentStreamGeneration) return;
        setState(() => _feedState = QueueFeedState.error);
        notify(
          'Không tải được số thứ tự từ lịch hẹn. '
          'Kiểm tra kết nối Firebase.',
        );
      },
    );
  }

  /// Xoá sạch trạng thái hàng chờ của ngày cũ trước khi nạp ngày mới.
  /// Giữ nguyên trạng thái phòng (tạm dừng / đóng) và mốc giờ đã chụp.
  void _resetQueueForSelectedDay() {
    _daBatDau = false;
    current = 0;
    next = 0;
    waiting = <int>[];
    lastIssued = 0;
    passed.clear();
    _deferredHistory.clear();
    _scheduledFutureInserts.clear();
    _eligibleAppointmentNumbers = <int>[];
    _appointmentIdByNumber.clear();
    _patientNameByNumber.clear();
    _absentAppointmentNumbers.clear();
    _patientNameDaChoQua.clear();
    _maLichHenDaChoQua.clear();
    _pendingRenumberByAppointmentId.clear();
    _requeuedAppointmentNumbers.clear();
    selected = null;
    message = null;
    _feedState = QueueFeedState.connecting;
  }

  /// Mở lịch chọn ngày ngay trên màn hình gọi số.
  ///
  /// Cho chọn mọi ngày/tháng/năm trong khoảng rộng 1900–2100 để test; chỉ
  /// chọn theo NGÀY (không chọn ca/khung giờ). Không đổi schema Firestore.
  Future<void> _pickQueueDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedQueueDay,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Chọn lịch test hàng chờ',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
    );
    if (!mounted || picked == null) return;
    final day = _queueDayOnly(picked);
    if (day == _selectedQueueDay) return;

    setState(() {
      _selectedQueueDay = day;
      _resetQueueForSelectedDay();
    });
    _syncRoomState();
    _subscribeToAppointmentQueue(day);

    final coLocTheoNgay = widget.appointmentQueueForDay != null;
    notify(
      coLocTheoNgay
          ? 'Đã chọn lịch ${_formatQueueDay(day)}. '
                'Đang nạp lịch hẹn của ngày này.'
          : 'Đã chọn lịch ${_formatQueueDay(day)}. '
                'Luồng demo hiện không lọc theo ngày.',
    );
  }

  /// Ghi 2 field snake_case `trang_thai_id` + `trang_thai` lên Firestore
  /// (nếu màn hình có kết nối Firestore). Lỗi chỉ hiện thông báo, không
  /// đảo ngược giao diện vì luồng realtime sẽ tự sửa nếu ghi thất bại.
  Future<void> _publishRoomStatusId(int id) async {
    final callback = widget.onRoomStatusChanged;
    if (callback == null) return;
    try {
      await callback(id);
    } catch (_) {
      notify('Không cập nhật được trạng thái phòng khám. Kiểm tra kết nối.');
    }
  }

  /// Ghi trạng thái hiện tại của phòng vào [RoomSessionStore] và báo cho
  /// màn hình chính vẽ lại (trạng thái Tạm dừng / Đang khám, số hiện tại,
  /// số đang đợi, số đã khám).
  void _syncRoomState() {
    // Bỏ tên của những số không còn nằm trong “SỐ ĐÃ CHO QUA”.
    final soDaChoQua = <int>{
      for (final entry in passed)
        if (entry.deferred) entry.number,
    };
    _patientNameDaChoQua.removeWhere((so, _) => !soDaChoQua.contains(so));
    _maLichHenDaChoQua.removeWhere((so, _) => !soDaChoQua.contains(so));

    final store = RoomSessionStore.instance;
    store.sessionOf(_storeKey)
      ..started = true
      ..current = current
      ..next = next
      ..waiting = List<int>.of(waiting)
      ..lastIssued = lastIssued
      ..daBatDau = _daBatDau
      ..absentNumbers = _absentAppointmentNumbers.toList()
      ..requeuedNumbers = _requeuedAppointmentNumbers.toList()
      ..appointmentIdByNumber = Map<int, String>.of(_appointmentIdByNumber)
      ..patientNameByNumber = Map<int, String>.of(_patientNameByNumber)
      ..deferredNameByNumber = Map<int, String>.of(_patientNameDaChoQua)
      ..deferredAppointmentIdByNumber = Map<int, String>.of(
        _maLichHenDaChoQua,
      )
      ..paused = paused
      ..closed = closed
      ..statusChangedAt = _lastStatusChangeAt
      ..statusChangeLabel = _lastStatusChangeLabel
      ..examinedNumbers = <int>[
        for (final entry in passed)
          if (!entry.deferred) entry.number,
      ]
      ..deferredNumbers = <int>[
        for (final entry in passed)
          if (entry.deferred) entry.number,
      ]
      ..deferredHistory = List<int>.of(_deferredHistory)
      ..scheduledFutureInserts = <({int number, int afterNumber})>[
        for (final insert in _scheduledFutureInserts)
          if (insert.afterNumber != null)
            (number: insert.number, afterNumber: insert.afterNumber!),
      ];
    store.refresh();
  }

  /// Áp các số thứ tự MỚI vừa ghi sau khi chèn lên một đợt cập nhật từ
  /// Firebase, để màn hình không quay về số cũ trong vài giây đầu.
  AppointmentQueueUpdate _applyPendingRenumber(
    AppointmentQueueUpdate update,
  ) {
    if (_pendingRenumberByAppointmentId.isEmpty) return update;
    final numbers = <int>[];
    final appointmentIdByNumber = <int, String>{};
    final patientNameByNumber = <int, String>{};
    final daDung = <int>{};
    final dangCho = <String>{};
    for (final number in update.numbers) {
      final appointmentId = update.appointmentIdByNumber[number];
      var soHienThi = number;
      if (appointmentId != null) {
        final soMoi = _pendingRenumberByAppointmentId[appointmentId];
        if (soMoi != null) {
          dangCho.add(appointmentId);
          if (soMoi == number) {
            // Firebase đã ghi xong số mới: không cần giữ ánh xạ nữa.
            _pendingRenumberByAppointmentId.remove(appointmentId);
          } else {
            soHienThi = soMoi;
          }
        }
      }
      if (!daDung.add(soHienThi)) continue;
      numbers.add(soHienThi);
      if (appointmentId != null) {
        appointmentIdByNumber[soHienThi] = appointmentId;
      }
      final ten = update.patientNameByNumber[number];
      if (ten != null && ten.trim().isNotEmpty) {
        patientNameByNumber[soHienThi] = ten;
      }
    }
    // Lịch hẹn đã rời danh sách đủ điều kiện (khám xong / vắng / xin đợi)
    // thì không cần giữ số mới nữa.
    _pendingRenumberByAppointmentId.removeWhere(
      (appointmentId, _) =>
          !dangCho.contains(appointmentId) &&
          !update.appointmentIdByNumber.containsValue(appointmentId),
    );
    numbers.sort();
    return (
      numbers: numbers,
      appointmentIdByNumber: appointmentIdByNumber,
      patientNameByNumber: patientNameByNumber,
    );
  }

  /// Áp một đợt cập nhật từ luồng lịch hẹn vào trạng thái hiện tại.
  void _applyAppointmentUpdate(AppointmentQueueUpdate update) {
    if (!mounted) return;
    // Giữ đúng số mới vừa ghi sau khi chèn, kể cả khi Firebase chưa kịp
    // cập nhật `so_thu_tu` trong vài giây đầu.
    update = _applyPendingRenumber(update);
    final newlyRequeuedNumbers = <int>[];
    setState(() {
      // Đã có đợt dữ liệu thật từ luồng: thẻ thông báo chuyển sang
      // trạng thái "Realtime". Mỗi đợt emit sau đó đều vẽ lại thẻ với
      // nội dung/STT/giờ mới nhất.
      _feedState = QueueFeedState.live;
      final wasEmpty = current <= 0;
      _appointmentIdByNumber.addAll(update.appointmentIdByNumber);
      for (final number in update.numbers) {
        final patientName = update.patientNameByNumber[number]
            ?.trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        if (patientName == null || patientName.isEmpty) {
          _patientNameByNumber.remove(number);
        } else {
          _patientNameByNumber[number] = patientName;
        }
      }
      _eligibleAppointmentNumbers = List<int>.of(update.numbers);
      final confirmedNumbers = update.numbers.toSet();
      // Chỉ những số ĐÃ KHÁM mới bị loại khỏi hàng chờ khi đồng bộ. Số nằm
      // trong sổ “SỐ ĐÃ CHO QUA” thì không loại theo số, vì số đó có thể đã
      // được cấp lại cho một bệnh nhân khác đang chờ (bệnh nhân đã đợi được
      // Firebase giữ ở trạng thái 7 nên vốn không nằm trong danh sách đủ
      // điều kiện).
      final passedNumbers = <int>{
        for (final entry in passed)
          if (!entry.deferred) entry.number,
      };
      _requeuedAppointmentNumbers.removeWhere(
        (number) =>
            confirmedNumbers.contains(number) ||
            passedNumbers.contains(number) ||
            _absentAppointmentNumbers.contains(number),
      );
      final scheduledBefore = List<InsertResult>.of(_scheduledFutureInserts);
      // Số đang chờ Firebase chuyển về `2` và số đã lên lịch chèn được
      // coi là đủ điều kiện cục bộ trong lần đồng bộ này. Nhờ vậy số
      // đang ở trạng thái `7` vẫn được đặt ngay sau số mốc khi số mốc
      // xuất hiện, nhưng không tự nối vào cuối hàng chờ trước thời điểm đó.
      final effectiveEligibleNumbers = <int>{
        ...update.numbers,
        ..._requeuedAppointmentNumbers,
        for (final insert in scheduledBefore) insert.number,
      }.toList()..sort();
      final result = _reconcileAppointmentQueue(
        eligibleNumbers: effectiveEligibleNumbers,
        current: current,
        next: next,
        waiting: waiting,
        passedNumbers: passedNumbers,
        suppressedNumbers: _absentAppointmentNumbers,
        scheduledInserts: _scheduledFutureInserts,
        lastIssued: lastIssued,
      );
      final remainingScheduledNumbers = result.scheduledInserts
          .map((insert) => insert.number)
          .toSet();
      for (final insert in scheduledBefore) {
        final number = insert.number;
        final wasInserted =
            !remainingScheduledNumbers.contains(number) &&
            (result.current == number ||
                result.next == number ||
                result.waiting.contains(number));
        if (wasInserted &&
            !confirmedNumbers.contains(number) &&
            _requeuedAppointmentNumbers.add(number)) {
          newlyRequeuedNumbers.add(number);
        }
      }
      if (_daBatDau) {
        current = result.current;
        next = result.next;
        waiting = result.waiting;
      } else {
        // Chưa bấm “Bắt đầu”: giữ số hiện tại = 0, dồn hết số về hàng chờ.
        final cho = <int>[
          if (result.current > 0) result.current,
          if (result.next > 0) result.next,
          ...result.waiting,
        ];
        current = 0;
        next = 0;
        waiting = cho;
      }
      _scheduledFutureInserts
        ..clear()
        ..addAll(result.scheduledInserts);
      lastIssued = result.lastIssued;
      if (selected != null && !waiting.contains(selected)) selected = null;
      // Phòng đã đóng: giữ nguyên thông báo "đóng phòng", không ghi đè
      // bằng các lời nhắn nạp số từ luồng realtime.
      if (!closed && wasEmpty && current > 0) {
        message = next > 0
            ? 'Đã nạp số thứ tự từ lịch hẹn đã xác nhận.\n'
                  'Bệnh nhân số $current đang khám; số $next là số tiếp theo.'
            : 'Đã nạp số thứ tự từ lịch hẹn đã xác nhận.\n'
                  'Bệnh nhân số $current đang khám.';
      } else if (!closed && wasEmpty && !_daBatDau && waiting.isNotEmpty) {
        message =
            'Đã nạp ${waiting.length} số từ lịch hẹn đã xác nhận.\n'
            'Số bắt đầu là 0 – nhấn “Bắt đầu” để gọi số ${waiting.first}.';
      }
      _syncRoomState();
    });
    for (final number in newlyRequeuedNumbers) {
      _reportAppointmentOutcome(number, AppointmentOutcome.requeued);
    }
    // Đồng bộ xong thì chạy lại danh sách số: nếu dữ liệu trên Firebase bị
    // lỗ số / trùng số, màn hình tự sửa về dãy 1, 2, 3, … n.
    // Chỉ làm khi không còn đợt đánh số nào đang chờ ghi để tránh ghi đè nhau.
    if (_pendingRenumberByAppointmentId.isEmpty) {
      _chayLaiDanhSachSo(imLang: true);
    }
  }

  /// Báo kết quả của một số về lịch hẹn tương ứng, nếu có ánh xạ.
  /// Việc ghi diễn ra nền; lỗi ghi chỉ hiện thông báo để không làm
  /// gián đoạn thao tác gọi số của nhân viên.
  void _reportAppointmentOutcome(int number, AppointmentOutcome outcome) {
    final report = widget.onAppointmentOutcome;
    if (report == null) return;
    final appointmentId = _appointmentIdByNumber[number];
    if (appointmentId == null) return;
    unawaited(
      report(appointmentId, outcome).catchError((Object error) {
        if (mounted) {
          notify(
            'Không cập nhật được trạng thái lịch hẹn của số $number '
            'lên Firebase.',
          );
        }
      }),
    );
  }

  /// Báo kết quả cho một lịch hẹn theo mã (dùng khi số thứ tự vừa đổi
  /// nên không thể tra ngược từ số nữa).
  void _reportAppointmentOutcomeById(
    String appointmentId,
    AppointmentOutcome outcome,
  ) {
    final report = widget.onAppointmentOutcome;
    if (report == null) return;
    unawaited(
      report(appointmentId, outcome).catchError((Object error) {
        if (mounted) {
          notify('Không cập nhật được trạng thái lịch hẹn lên Firebase.');
        }
      }),
    );
  }

  /// Tên bệnh nhân gắn với một STT. Chỉ trả về giá trị khi số đó khớp
  /// với `so_thu_tu` của lịch hẹn đủ điều kiện đã nạp.
  String? _patientNameFor(int number) {
    if (number <= 0) return null;
    final patientName = _patientNameByNumber[number]?.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return patientName == null || patientName.isEmpty ? null : patientName;
  }

  /// Dòng tên bệnh nhân hiện ngay dưới một STT. Chỉ trả về giá trị khi
  /// số đó khớp với `so_thu_tu` của lịch hẹn đủ điều kiện đã nạp.
  String? _patientNameSubtitle(int number) {
    final patientName = _patientNameFor(number);
    return patientName;
  }

  /// Điền số đang khám/số tiếp theo từ đầu hàng chờ khi một vị trí bị
  /// trống. Giá trị 0 được giữ nguyên nếu không còn số nào.
  void _promoteWaitingHeads() {
    if (current <= 0 && next > 0) {
      current = next;
      next = 0;
    }
    if (current <= 0 && waiting.isNotEmpty) {
      current = waiting.removeAt(0);
    }
    if (current > 0 && next <= 0 && waiting.isNotEmpty) {
      next = waiting.removeAt(0);
    }
  }

  String get _defaultStatusMessage {
    if (closed) {
      return 'Phòng khám đã đóng.\n'
          'Không gọi số mới cho đến khi bác sĩ mở lại phòng.\n'
          'Nhấn “Mở phòng khám” ở nút dưới cùng để tiếp tục.';
    }
    if (paused) {
      final mocGio = _lastStatusChangeAt == null
          ? ''
          : ' lúc ${formatMayGio(_lastStatusChangeAt!)}';
      return 'Bác sĩ đã nhấn nút “Tạm dừng khám”$mocGio.\n'
          'Việc gọi số tiếp theo tạm thời bị dừng.\n'
          'Vui lòng chờ đến khi bác sĩ tiếp tục khám.';
    }
    if (current <= 0) {
      if (waiting.isNotEmpty) {
        return 'Số bắt đầu là 0 – chưa gọi số nào.\n'
            'Đang có ${waiting.length} số trong hàng chờ; nhấn “Bắt đầu” '
            'để gọi số ${waiting.first}.';
      }
      return 'Chưa có bệnh nhân nào trong danh sách lịch hẹn đã xác nhận '
          'của phòng ngày ${_formatQueueDay(_selectedQueueDay)}.\n'
          'STT chỉ xuất hiện khi lịch hẹn được cập nhật vào danh sách.';
    }
    if (next <= 0) {
      return 'Bệnh nhân số $current đang khám.\n'
          'Hiện chưa có số tiếp theo trong hàng chờ.';
    }
    return 'Bệnh nhân số $current đang khám.\n'
        'Nhấn “Tiếp theo” để xác nhận khám xong và gọi số $next.';
  }

  void notify(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _Ui.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        ),
      );
  }

  bool get _currentConfirmed =>
      passed.any((entry) => entry.number == current && !entry.deferred);

  /// Số của những bệnh nhân đã bấm "Đợi" – danh sách hiện trong màn hình Chèn.
  List<int> get deferredNumbers => passed
      .where((entry) => entry.deferred)
      .map((entry) => entry.number)
      .toList();

  /// Cùng danh sách trên nhưng số MỚI NHẤT đứng đầu, để số vừa bấm "Đợi"
  /// hiện ngay trong dải "SỐ ĐÃ CHO QUA" thay vì nằm cuối danh sách cuộn.
  List<int> get newestDeferredNumbers => deferredNumbers.reversed.toList();

  /// Số của những bệnh nhân đã khám xong – dùng cho mục "Gọi lại số".
  List<int> get examinedNumbers => passed
      .where((entry) => !entry.deferred)
      .map((entry) => entry.number)
      .toList();

  /// Nút "Tiếp theo" (đã gộp với "Xác nhận khám"): xác nhận số hiện tại đã
  /// khám xong rồi gọi số kế tiếp trong một lần bấm.
  void callNext() {
    if (closed) {
      notify('Phòng khám đã đóng. Nhấn “Mở phòng khám” để tiếp tục.');
      return;
    }
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi gọi số.');
      return;
    }
    if (current <= 0) {
      // Số bắt đầu mặc định là 0: nút chính lúc này là “Bắt đầu”.
      // Bấm lần đầu mới đưa số nhỏ nhất đang chờ lên thành số đang khám.
      if (waiting.isEmpty) {
        notify('Chưa có lịch hẹn đã xác nhận nào để bắt đầu gọi số.');
        return;
      }
      setState(() {
        _daBatDau = true;
        current = 0;
        next = 0;
        _promoteWaitingHeads();
        message =
            'Đã bắt đầu gọi số.\n'
            'Bệnh nhân số $current đang khám'
            '${next > 0 ? '; số $next là số tiếp theo' : ''}.';
        _syncRoomState();
      });
      _chayLaiDanhSachSo(imLang: true);
      return;
    }
    final finished = current;
    var shouldReportExamined = false;
    setState(() {
      // “SỐ ĐÃ CHO QUA” là sổ ghi cố định của phòng: nút Tiếp theo KHÔNG
      // xoá số nào khỏi đó. Chỉ nút “Đặt lại số” mới xoá toàn bộ.
      if (!_currentConfirmed) {
        // Xác nhận khám: ghi số hiện tại vào danh sách đã khám.
        passed.add((number: finished, deferred: false));
        _requeuedAppointmentNumbers.remove(finished);
        shouldReportExamined = true;
      }
      current = next;
      next = 0;
      _promoteWaitingHeads();
      if (selected != null && !waiting.contains(selected)) selected = null;
      message = current > 0
          ? 'Đã xác nhận bệnh nhân số $finished khám xong.\n'
                'Đã gọi bệnh nhân số $current – vui lòng chờ bệnh nhân '
                'vào phòng khám.'
          : 'Đã xác nhận bệnh nhân số $finished khám xong.\n'
                'Hiện không còn số nào trong hàng chờ — số sẽ tự xuất '
                'hiện khi có lịch hẹn mới được xác nhận.';
      _syncRoomState();
    });
    if (shouldReportExamined) {
      _reportAppointmentOutcome(finished, AppointmentOutcome.examined);
    }
    // Chạy lại danh sách số sau khi chuyển sang số kế tiếp.
    _chayLaiDanhSachSo(imLang: true);
  }

  /// “Đặt lại số” trong chế độ lịch hẹn: xoá trạng thái phiên trên máy
  /// rồi nạp lại đúng các lịch hẹn đang đủ điều kiện gần nhất. Lịch đã
  /// được ghi Hoàn thành/Vắng mặt trên Firebase sẽ không quay lại vì
  /// không còn thuộc tập đủ điều kiện.
  Future<void> _resetNumbersFromAppointments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt lại số'),
        content: Text(
          'Đưa ${widget.roomName} về đúng danh sách lịch hẹn đã xác '
          'nhận ngày ${_formatQueueDay(_selectedQueueDay)}?\n\n'
          '• Xoá toàn bộ số đã đợi, số đã khám ghi trên máy này và '
          'lịch chèn theo số mốc tương lai\n'
          '• Nạp lại số thứ tự từ các lịch hẹn đang ở trạng thái '
          'Đã xác nhận trên Firebase\n'
          '• Lịch đã Hoàn thành, Vắng mặt hoặc Xin đợi (7) sẽ không quay lại\n'
          '• Phòng trở về “Đang khám”\n\n'
          'Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _daBatDau = false;
      passed.clear();
      _deferredHistory.clear();
      _scheduledFutureInserts.clear();
      _absentAppointmentNumbers.clear();
      _requeuedAppointmentNumbers.clear();
      selected = null;
      paused = false;
      final result = _reconcileAppointmentQueue(
        eligibleNumbers: _eligibleAppointmentNumbers,
        current: 0,
        next: 0,
        waiting: const <int>[],
        passedNumbers: const <int>{},
        suppressedNumbers: const <int>{},
        scheduledInserts: const <InsertResult>[],
        lastIssued: 0,
      );
      // Đặt lại số cũng đưa phòng về số bắt đầu 0 (chưa gọi số nào) và giữ
      // nguyên số thứ tự thật của lịch hẹn, không tự đánh lại từ 1.
      current = 0;
      next = 0;
      waiting = <int>[
        if (result.current > 0) result.current,
        if (result.next > 0) result.next,
        ...result.waiting,
      ];
      lastIssued = result.lastIssued;
      message = waiting.isNotEmpty
          ? 'Đã đặt lại hàng chờ theo lịch hẹn đã xác nhận: số bắt đầu = 0, '
                '${waiting.length} số đang chờ. Nhấn “Bắt đầu” để gọi số '
                '${waiting.first}.'
          : 'Đã đặt lại hàng chờ. Hiện chưa có lịch hẹn đã xác nhận nào cho '
                'phòng ngày ${_formatQueueDay(_selectedQueueDay)}.';
      _syncRoomState();
    });
    notify('Đã đặt lại hàng chờ của ${widget.roomName} theo lịch hẹn.');
  }

  /// Nút “Đặt lại số”: xoá trạng thái phiên trên máy rồi nạp lại đúng
  /// các STT còn trong danh sách lịch hẹn đã xác nhận gần nhất.
  Future<void> resetNumbers() => _resetNumbersFromAppointments();

  /// Nút "Xác nhận vắng mặt":
  ///  1. Mở bảng chọn số – CHỈ gồm những số đã bấm "Đợi" (danh sách
  ///     "SỐ ĐÃ CHO QUA" trên màn hình chính).
  ///  2. Hỏi xác nhận rồi ghi nhận số được chọn là vắng mặt và bỏ số đó khỏi
  ///     danh sách chờ chèn lại.
  ///
  /// Nếu số đó vẫn còn có lượt trong hàng chờ, số đó cũng bị bỏ khỏi hàng chờ.
  Future<void> markCurrentAbsent() async {
    if (closed) {
      notify('Phòng khám đã đóng. Nhấn “Mở phòng khám” để tiếp tục.');
      return;
    }
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi cập nhật lượt.');
      return;
    }

    final absentNumbers = deferredNumbers;
    if (absentNumbers.isEmpty) {
      notify('Chưa có bệnh nhân nào bấm “Đợi” để xác nhận vắng mặt.');
      return;
    }

    final absentNumber = await _pickAbsentNumber(absentNumbers);
    if (!mounted || absentNumber == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận vắng mặt'),
        content: Text(
          'Bệnh nhân số $absentNumber đã bấm “Đợi” nhưng không quay lại. '
          'Ghi nhận trạng thái “Vắng mặt” và bỏ số này khỏi danh sách chờ '
          'chèn lại?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      // “SỐ ĐÃ CHO QUA” là sổ ghi cố định: xác nhận vắng mặt chỉ bỏ số khỏi
      // hàng chờ, không xoá số khỏi sổ. Chỉ “Đặt lại số” mới xoá toàn bộ.
      _absentAppointmentNumbers.add(absentNumber);
      _requeuedAppointmentNumbers.remove(absentNumber);
      _scheduledFutureInserts.removeWhere(
        (insert) => insert.number == absentNumber,
      );
      final wasInQueue = waiting.remove(absentNumber);
      if (wasInQueue) {
        if (selected == absentNumber) selected = null;
      }
      final queueNote = wasInQueue ? ' và khỏi hàng chờ' : '';
      message =
          'Đã ghi nhận bệnh nhân số $absentNumber vắng mặt.'
          '\nSố $absentNumber vẫn được giữ trong “SỐ ĐÃ CHO QUA”'
          '$queueNote.';
      _syncRoomState();
    });
    _reportAppointmentOutcome(absentNumber, AppointmentOutcome.absent);
    // Chạy lại danh sách số sau khi bỏ một số khỏi hàng chờ.
    _chayLaiDanhSachSo(imLang: true);
  }

  /// Bảng chọn số cần ghi nhận vắng mặt – chỉ gồm các số đã bấm "Đợi".
  Future<int?> _pickAbsentNumber(
    List<int> absentNumbers,
  ) => showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.66,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E6EF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Xác nhận vắng mặt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _Ui.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chọn số trong danh sách đã bấm “Đợi” để xác nhận vắng mặt.',
                  style: TextStyle(fontSize: 12.5, color: _Ui.textSecondary),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'ĐÃ BẤM ĐỢI · CHỌN SỐ VẮNG MẶT',
                  count: absentNumbers.length,
                  accent: _Ui.amber,
                  accentSoft: const Color(0x24FFB300),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bấm một số để ghi nhận bệnh nhân đó vắng mặt. Số mới bấm “Đợi” hiện trước.',
                  style: TextStyle(fontSize: 11.5, color: _Ui.textFaint),
                ),
                const SizedBox(height: 12),
                if (absentNumbers.isEmpty)
                  const _EmptyHint(
                    icon: Icons.pause_circle_outline_rounded,
                    text: 'Chưa có số nào bấm “Đợi”.',
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Số mới bấm "Đợi" hiện trước.
                      for (final n in absentNumbers.reversed)
                        _AbsentChip(
                          number: n,
                          onTap: () => Navigator.of(sheetContext).pop<int>(n),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Cho một số xin đợi (qua lượt).
  ///
  /// Cả SỐ ĐANG KHÁM, SỐ TIẾP THEO lẫn các số đang chờ đều được xử lý như
  /// nhau: số bị cho qua được ghi vào "SỐ ĐÃ CHO QUA" rồi rời khỏi lượt
  /// gọi, KHÔNG tự xếp lại vào hàng chờ. Vị trí của số đó được nhường lại
  /// ngay cho số kế tiếp trong lượt gọi:
  ///  - số đang khám -> số tiếp theo lên khám, số đầu hàng chờ thành số
  ///    tiếp theo;
  ///  - số tiếp theo -> số đầu hàng chờ thế chân;
  ///  - số đang chờ  -> bị rút khỏi hàng chờ.
  ///
  /// Lịch hẹn tương ứng được báo sang trạng thái xin đợi (`7`). Khi
  /// bệnh nhân quay lại, bấm vào số đó trong dải "SỐ ĐÃ CHO QUA" hoặc
  /// nút "+ Chèn" để đưa số đó trở lại hàng chờ tại vị trí mong muốn;
  /// lúc số thực sự vào lại hàng chờ, lịch hẹn được báo về `2`.
  void deferNumber(int number) {
    if (closed) {
      notify('Phòng khám đã đóng. Nhấn “Mở phòng khám” để tiếp tục.');
      return;
    }
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi đổi lượt.');
      return;
    }
    if (number <= 0) return;
    final isCurrent = number == current;
    final isNext = number == next;
    if (!isCurrent && !isNext && !waiting.contains(number)) {
      notify('Số $number không còn trong hàng chờ.');
      return;
    }
    setState(() {
      _donSoTrung();
      // LƯU LỊCH SỬ: mọi số vừa bấm "Đợi" đều được ghi lại để dùng cho
      // việc khác, dù sau đó số đó có được gọi lại hay xác nhận vắng mặt.
      if (!_deferredHistory.contains(number)) {
        _deferredHistory.add(number);
      }
      // Nhường vị trí của số bị cho qua cho số kế tiếp trong lượt gọi.
      if (isCurrent) {
        // Bệnh nhân đang khám xin đợi: gọi số kế tiếp lên phòng khám.
        current = next;
        next = 0;
      } else if (isNext) {
        // Số tiếp theo xin đợi: vị trí này tạm trống, sẽ được điền lại
        // từ đầu hàng chờ ngay bên dưới nếu vẫn còn số.
        next = 0;
      } else {
        // Số đang chờ xin đợi: rút khỏi hàng chờ.
        waiting.remove(number);
      }
      // Ghi vào "SỐ ĐÃ CHO QUA" – điểm đến DUY NHẤT của mọi số bị cho qua,
      // kể cả số vừa là số hiện tại / số tiếp theo. Xoá entry cũ cùng số
      // (nếu còn sót) trước khi thêm để danh sách không bị trùng số.
      _requeuedAppointmentNumbers.remove(number);
      // Giữ tên bệnh nhân theo đúng số lúc cho qua để dải “SỐ ĐÃ CHO QUA”
      // vẫn hiện đúng tên sau khi các số phía sau được đánh lại.
      final tenDaChoQua = _patientNameFor(number);
      if (tenDaChoQua != null) _patientNameDaChoQua[number] = tenDaChoQua;
      final maLichHenDaChoQua = _appointmentIdByNumber[number];
      if (maLichHenDaChoQua != null) {
        _maLichHenDaChoQua[number] = maLichHenDaChoQua;
      }
      passed.removeWhere((e) => e.number == number && e.deferred);
      passed.add((number: number, deferred: true));
      _promoteWaitingHeads();
      if (selected == number ||
          (selected != null && !waiting.contains(selected))) {
        selected = null;
      }
      final queueUpdate = isCurrent
          ? (current > 0
                ? 'Bệnh nhân số $current đang khám'
                      '${next > 0 ? '; số $next là số tiếp theo' : ''}.\n'
                : 'Hiện chưa có số tiếp theo trong hàng chờ.\n')
          : isNext
          ? (next > 0
                ? 'Số $next trở thành số tiếp theo.\n'
                : 'Hiện chưa có số tiếp theo trong hàng chờ.\n')
          : '';
      message =
          'Bệnh nhân số $number xin đợi.\n'
          'Số $number đã được chuyển vào “SỐ ĐÃ CHO QUA” để lưu lại.\n'
          '$queueUpdate'
          'Khi bệnh nhân quay lại, bấm vào số đó hoặc “+ Chèn” để đưa số '
          '$number trở lại hàng chờ.';
      _syncRoomState();
    });
    _reportAppointmentOutcome(number, AppointmentOutcome.deferred);
    // Các số phía sau số bị cho qua giảm 1 để hàng chờ không bị lỗ trống
    // (hàm tự hiện thông báo khi có số phải đổi).
    if (!_chayLaiDanhSachSo(
      moDau: 'Số $number đã vào “SỐ ĐÃ CHO QUA” và đã đánh lại số',
      donTheoSoDaKham: true,
    )) {
      notify('Số $number đã được chuyển vào “SỐ ĐÃ CHO QUA”.');
    }
  }

  /// Gọi lại một bệnh nhân đã khám xong: đưa số đó vào "SỐ HIỆN TẠI" ngay,
  /// số đang khám cũ lùi về "SỐ TIẾP THEO"; số kế tiếp cũ (chưa được gọi) quay
  /// trở lại đầu hàng chờ để không bị mất lượt.
  void recallNumber(int picked) {
    if (closed) {
      notify('Phòng khám đã đóng. Nhấn “Mở phòng khám” để tiếp tục.');
      return;
    }
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi gọi lại số.');
      return;
    }
    if (picked <= 0) return;
    final previousCurrent = current;
    final previousNext = next;
    setState(() {
      // Bệnh nhân vào phòng khám ngay: bỏ khỏi danh sách "ĐÃ KHÁM" (sẽ được
      // ghi lại khi bác sĩ nhấn "Tiếp theo"). Riêng "SỐ ĐÃ CHO QUA" vẫn giữ
      // nguyên – chỉ nút "Đặt lại số" mới xoá sổ này.
      passed.removeWhere(
        (entry) => entry.number == picked && !entry.deferred,
      );
      // Số được gọi lại coi như đang chờ khám trở lại: không còn là số
      // vắng mặt hay số đang chờ Firebase xác nhận chèn lại.
      _absentAppointmentNumbers.remove(picked);
      _requeuedAppointmentNumbers.add(picked);
      current = picked;
      if (previousCurrent > 0) {
        next = previousCurrent;
        if (previousNext > 0) {
          waiting.insert(
            0,
            previousNext,
          ); // số kế tiếp cũ chưa gọi -> về đầu hàng chờ
        }
        message =
            'Đã gọi lại bệnh nhân số $picked – số $picked đang khám.\n'
            'Số $previousCurrent trở thành số tiếp theo'
            '${previousNext > 0 ? '; số $previousNext quay lại đầu hàng chờ.' : '.'}';
      } else {
        next = previousNext;
        _promoteWaitingHeads();
        message =
            'Đã gọi lại bệnh nhân số $picked – số $picked đang khám.\n'
            '${next > 0 ? 'Số $next là số tiếp theo.' : 'Hiện chưa có số tiếp theo trong hàng chờ.'}';
      }
      if (selected != null && !waiting.contains(selected)) selected = null;
      _syncRoomState();
    });
    // Gọi lại = bệnh nhân quay lại hàng chờ: ghi trạng thái `2`
    // (Đã xác nhận) lên LichHen để Firebase và app bệnh nhân thấy đúng.
    _reportAppointmentOutcome(picked, AppointmentOutcome.requeued);
    notify('Mời bệnh nhân số $picked đến ${widget.roomName.toLowerCase()}.');
  }

  /// Nút "Đợi / Gọi lại" (đã gộp 2 chức năng): mở bảng chọn số mong muốn.
  ///  - Mục "Đang khám / chờ": bấm số đang khám, số tiếp theo hoặc một số
  ///    đang chờ để cho qua lượt. Mọi số bị cho qua đều chỉ vào
  ///    "SỐ ĐÃ CHO QUA" và rời khỏi lượt gọi cho đến khi được chèn lại.
  ///  - Mục "Đã khám": bấm một số để gọi lại bệnh nhân đã khám xong.
  Future<void> openHoldOrRecallSheet() async {
    final recallable = examinedNumbers;
    // MỚI: thêm cả số đang khám. Dùng Set (LinkedHashSet) để vừa loại trùng
    // vừa giữ đúng thứ tự: đang khám -> kế tiếp -> các số đang chờ.
    final holdable = <int>{
      current,
      next,
      ...waiting,
    }.where((number) => number > 0).toList();
    final picked = await showModalBottomSheet<QueueAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.66,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3E6EF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Đợi / Gọi lại số',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _Ui.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chọn số cần xử lý – thao tác áp dụng ngay cho số được chọn.',
                    style: TextStyle(fontSize: 12.5, color: _Ui.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'ĐANG KHÁM / CHỜ · CHỌN ĐỂ CHO QUA LƯỢT',
                    count: holdable.length,
                    accent: _Ui.red,
                    accentSoft: const Color(0x1FFF534B),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bấm một số để đưa vào “SỐ ĐÃ CHO QUA”. Viền xanh = số đang '
                    'khám, viền vàng = số tiếp theo. Số bị cho qua rời khỏi '
                    'lượt gọi và chỉ quay lại hàng chờ khi bấm “+ Chèn”.',
                    style: TextStyle(fontSize: 11.5, color: _Ui.textFaint),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final n in holdable)
                        _SheetWaitChip(
                          number: n,
                          patientName: _patientNameFor(n),
                          isCurrent: n == current,
                          isNext: n == next,
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop<QueueAction>((number: n, hold: true)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'ĐÃ KHÁM · CHỌN ĐỂ GỌI LẠI',
                    count: recallable.length,
                    accent: _Ui.green,
                    accentSoft: const Color(0x1F2AC653),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bấm một số để gọi lại: số đó vào “số hiện tại”, số đang khám lùi về “số tiếp theo”.',
                    style: TextStyle(fontSize: 11.5, color: _Ui.textFaint),
                  ),
                  const SizedBox(height: 12),
                  if (recallable.isEmpty)
                    const _EmptyHint(
                      icon: Icons.inbox_rounded,
                      text: 'Chưa có bệnh nhân nào đã khám',
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // Số mới khám xong hiện trước.
                        for (final n in recallable.reversed)
                          _RecallChip(
                            number: n,
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop<QueueAction>((number: n, hold: false)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked.hold) {
      deferNumber(picked.number);
    } else {
      recallNumber(picked.number);
    }
  }

  /// Nhấn "+ Chèn" (hoặc bấm một số trong hàng "SỐ ĐÃ CHO QUA"): mở màn hình
  /// chèn. Danh sách trong màn hình là những số đã bấm "Đợi"; người dùng
  /// nhập cho mỗi số một số mốc BẤT KỲ. Số mốc đã biết từ danh sách lịch
  /// hẹn thì số được chèn vào ngay; số mốc lớn hơn STT lớn nhất đã biết
  /// được giữ lịch và tự áp dụng khi xuất hiện trong danh sách lịch hẹn.
  Future<void> openInsertScreen({int? initialNumber}) async {
    if (deferredNumbers.isEmpty) {
      notify('Chưa có bệnh nhân nào bấm “Đợi” để chèn lại.');
      return;
    }
    final results = await Navigator.of(context).push<List<InsertResult>>(
      MaterialPageRoute(
        builder: (_) => InsertPositionScreen(
          deferredNumbers: newestDeferredNumbers,
          waiting: List<int>.of(waiting),
          nextNumber: next,
          lastIssued: lastIssued,
          initialNumber: initialNumber,
        ),
      ),
    );
    if (!mounted || results == null || results.isEmpty) return;

    // Số mốc phải còn trong lượt gọi (đang khám / số tiếp theo / hàng chờ).
    // Nếu không, báo để chọn lại thay vì tự đoán chỗ chèn — đây chính là
    // nguyên nhân bệnh nhân bị đẩy lên trước hàng chờ.
    final soMocHopLe = <int>{
      0,
      if (current > 0) current,
      if (next > 0) next,
      ...waiting,
    };
    for (final insert in results) {
      final after = insert.afterNumber;
      if (after == null || after == 0) continue;
      if (_isFutureScheduledInsert(insert, lastIssued)) continue;
      if (!soMocHopLe.contains(after)) {
        notify(
          'Số mốc $after không còn trong hàng chờ. '
          'Chọn số khác hoặc nhập 0 để chèn lên đầu.',
        );
        return;
      }
    }

    final immediateNumbersToReport = <int>{};
    // Bộ đếm "số tạm" âm: số trong hàng chờ luôn dương, nên số tạm không
    // bao giờ trùng với bất kỳ ai đang chạy (kể cả khi số hiển thị của
    // người đã đợi trùng số với người khác). Sau bước đánh số lại, số tạm
    // được thay bằng số thật đúng vị trí chèn.
    var soTamKeTiep = -1;
    setState(() {
      // Dọn số trùng trước khi tính vị trí để phép đánh số không bị lệch.
      _donSoTrung();
      // Tách yêu cầu chèn ngay khỏi yêu cầu chờ số mốc tương lai, dựa trên
      // [lastIssued] tại thời điểm đóng màn hình chèn.
      final immediateResults = results
          .where((r) => !_isFutureScheduledInsert(r, lastIssued))
          .toList();
      final futureResults = results
          .where((r) => _isFutureScheduledInsert(r, lastIssued))
          .toList();
      final before = List<int>.of(waiting);
      // Đổi số hiển thị của người được chèn sang "số tạm" âm, đồng thời
      // gắn đúng mã lịch hẹn + tên đã chốt lúc bấm “Đợi”.
      final immediateForQueue = <InsertResult>[];
      for (final insert in immediateResults) {
        // LUÔN dùng số tạm âm cho người vừa chèn: số hiển thị cũ của họ có
        // thể trùng với số của một người khác đang chạy, nếu đưa thẳng số
        // đó vào hàng chờ thì phép đánh số sẽ đổi nhầm người.
        final soTam = soTamKeTiep;
        soTamKeTiep -= 1;
        final maLichHen = _maLichHenDaChoQua[insert.number];
        if (maLichHen != null) {
          _appointmentIdByNumber[soTam] = maLichHen;
        }
        final ten =
            _patientNameDaChoQua[insert.number] ??
            _patientNameByNumber[insert.number];
        if (ten != null && ten.trim().isNotEmpty) {
          _patientNameByNumber[soTam] = ten.trim();
        }
        immediateForQueue.add((number: soTam, afterNumber: insert.afterNumber));
      }
      // Chèn ngay: dựng lại hàng chờ trong một lượt theo các số mốc gốc.
      waiting = _waitingAfterInserts(
        before,
        immediateForQueue,
        nextNumber: next,
      );
      // Chờ mốc tương lai: giữ lịch; đợt cập nhật lịch hẹn sau sẽ tự đặt
      // từng số ngay sau số mốc khi số mốc xuất hiện trong danh sách.
      for (final insert in futureResults) {
        _scheduledFutureInserts.removeWhere(
          (scheduled) => scheduled.number == insert.number,
        );
        _scheduledFutureInserts.add(insert);
      }
      // Cả số chèn ngay lẫn số đã lên lịch vẫn được GIỮ trong “SỐ ĐÃ CHO
      // QUA” (kèm số cũ + tên + mã lịch hẹn) để lễ tân còn đối chiếu; chỉ
      // nút “Đặt lại số” mới xoá sổ này. Người được chèn lại vào hàng chờ
      // nhận số mới nên không trùng số trong danh sách đang gọi.
      final insertedNumbers = results.map((r) => r.number).toSet();
      // Số chèn ngay được giữ tạm trong hàng chờ và sẽ báo về trạng
      // thái `2` ngay sau setState. Số chờ mốc tương lai vẫn giữ `7`
      // cho tới khi thực sự được đặt vào hàng chờ ở một đợt đồng bộ sau.
      _requeuedAppointmentNumbers
        ..removeAll(insertedNumbers)
        ..addAll(immediateForQueue.map((r) => r.number));
      immediateNumbersToReport.addAll(immediateForQueue.map((r) => r.number));
      selected = immediateForQueue.isEmpty
          ? null
          : immediateForQueue.first.number;
      final immediateDetails = <String>[
        for (final r in immediateResults)
          r.afterNumber == null
              ? 'số ${r.number} lên đầu hàng chờ'
              : 'số ${r.number} ngay sau số ${r.afterNumber}',
      ].join(', ');
      final futureDetails = <String>[
        for (final r in futureResults)
          'số ${r.number} ngay sau số ${r.afterNumber} khi tới số đó',
      ].join(', ');
      final sentences = <String>[
        if (immediateResults.isNotEmpty)
          results.length == 1 && before.contains(results.first.number)
              ? 'Đã dời $immediateDetails.'
              : 'Đã chèn $immediateDetails.',
        if (futureResults.isNotEmpty) 'Đã lên lịch $futureDetails.',
      ];
      message = sentences.join('\n');
      _syncRoomState();
    });
    // Chốt mã lịch hẹn của người vừa chèn TRƯỚC khi đánh số lại (sau đó
    // khoá ánh xạ đã đổi sang số mới).
    final canBaoTrangThai = <String>[
      for (final number in immediateNumbersToReport)
        if (_appointmentIdByNumber[number] case final appointmentId?)
          appointmentId,
    ];
    // Chạy lại danh sách số sau khi chèn: số vừa chèn nhận số mốc + 1,
    // các số phía sau tăng thêm 1 và được ghi lên Firebase.
    _chayLaiDanhSachSo(moDau: 'Đã đánh số lại hàng chờ');
    for (final appointmentId in canBaoTrangThai) {
      _reportAppointmentOutcomeById(appointmentId, AppointmentOutcome.requeued);
    }
  }

  /// Chạy lại TOÀN BỘ danh sách số sau mỗi thao tác (Tiếp theo, Đợi, Chèn,
  /// Vắng mặt, đồng bộ Firebase):
  ///  1. dọn số trùng / số không hợp lệ trong (đang khám, tiếp theo, hàng chờ);
  ///  2. lấy số nền là số lớn nhất đã khám xong (các số này không đổi);
  ///  3. đánh lại liên tiếp theo đúng thứ tự gọi;
  ///  4. ghi `so_thu_tu` mới lên Firebase cho ai bị đổi.
  ///
  /// Nhờ vậy mọi thao tác đều "tự lành": dù trước đó dữ liệu có lỗi, lỗ số
  /// hay trùng số thì sau khi bấm là dãy về đúng 1, 2, 3, … n.
  bool _chayLaiDanhSachSo({
    String? moDau,
    bool imLang = false,
    bool donTheoSoDaKham = false,
  }) {
    if (!mounted) return false;

    // 1) Dọn trùng: mỗi số chỉ được nằm ở một vị trí.
    final daDung = <int>{};
    if (current > 0) daDung.add(current);
    if (next > 0 && !daDung.add(next)) next = 0;
    final waitingMoi = <int>[];
    for (final so in waiting) {
      if (so <= 0) continue;
      if (!daDung.add(so)) continue;
      waitingMoi.add(so);
    }
    var canVeLai = waitingMoi.length != waiting.length;
    if (!canVeLai) {
      for (var i = 0; i < waitingMoi.length; i++) {
        if (waitingMoi[i] != waiting[i]) {
          canVeLai = true;
          break;
        }
      }
    }
    waiting = waitingMoi;

    // 3) Đánh lại theo đúng thứ tự gọi.
    final order = <int>[
      if (current > 0) current,
      if (next > 0) next,
      ...waiting,
    ];

    // 2) Số nền:
    //  - [donTheoSoDaKham] = true (chỉ dùng sau khi bấm “Đợi”): nền là số lớn
    //    nhất đã khám xong, nên các số phía sau số bị cho qua giảm 1.
    //  - còn lại: NEO số đầu tiên, chỉ dồn các lỗ trống phía sau. Nhờ vậy
    //    màn hình tự sửa lỗi lỗ số/trùng số mà KHÔNG kéo cả hàng chờ về số 1
    //    khi phiên làm việc bắt đầu từ số khác (vd 5, 6…).
    var soMoi = 0;
    if (donTheoSoDaKham) {
      for (final entry in passed) {
        if (!entry.deferred && entry.number > soMoi) soMoi = entry.number;
      }
    } else if (order.isNotEmpty) {
      soMoi = order.first - 1;
    }
    // Chỉ dồn xuống khi số đầu hàng chờ đang nối tiếp số đã khám (hoặc bắt
    // đầu từ 1, 2). Trường hợp “Gọi lại” một số cũ thì giữ nguyên.
    final dungSoNen = order.isNotEmpty &&
        (!donTheoSoDaKham ||
            (order.first > soMoi && order.first <= soMoi + 2));
    final renumber = <int, int>{};
    if (dungSoNen) {
      for (final so in order) {
        soMoi += 1;
        if (soMoi != so) renumber[so] = soMoi;
      }
    }

    if (renumber.isEmpty) {
      if (canVeLai) setState(() {});
      _syncRoomState();
      return false;
    }
    _apDungDanhSoLai(
      renumber,
      moDau ?? 'Đã đánh lại số thứ tự',
      imLang: imLang,
    );
    return true;
  }

  /// Dọn số trùng trong trạng thái hiện tại (mỗi số chỉ xuất hiện một lần
  /// ở “đang khám” / “số tiếp theo” / hàng chờ). Chạy đầu mỗi thao tác để
  /// dữ liệu cũ bị lỗi không làm lệch phép đánh số.
  void _donSoTrung() {
    final daDung = <int>{};
    if (current > 0) daDung.add(current);
    if (next > 0 && !daDung.add(next)) next = 0;
    final waitingMoi = <int>[];
    for (final so in waiting) {
      if (so <= 0) continue;
      if (!daDung.add(so)) continue;
      waitingMoi.add(so);
    }
    waiting = waitingMoi;
  }

  /// Áp một bảng đổi số (số cũ → số mới) cho toàn bộ trạng thái hàng chờ,
  /// cập nhật phiên phòng và ghi `so_thu_tu` mới lên Firebase.
  void _apDungDanhSoLai(
    Map<int, int> renumber,
    String moDau, {
    bool imLang = false,
  }) {
    if (renumber.isEmpty) return;

    // Chụp mã lịch hẹn TRƯỚC khi đổi khoá các ánh xạ theo số.
    final canGhi = <(String, int)>[
      for (final entry in renumber.entries)
        if (_appointmentIdByNumber[entry.key] case final appointmentId?)
          (appointmentId, entry.value),
    ];

    int doi(int so) => renumber[so] ?? so;

    // Chặn trước khi áp dụng: nếu bảng đổi số làm hai vị trí khác nhau ra
    // cùng một số thì huỷ thao tác, giữ nguyên hàng chờ hiện tại thay vì
    // để màn hình rơi vào trạng thái trùng số (nguồn gốc lỗi “số nhảy”).
    final truocKhiDoi = <int>{
      if (current > 0) current,
      if (next > 0) next,
      ...waiting.where((so) => so != 0),
    };
    final sauKhiDoi = <int>{for (final so in truocKhiDoi) doi(so)};
    if (sauKhiDoi.length != truocKhiDoi.length) {
      notify(
        'Chưa đánh số lại được vì sẽ tạo số trùng. '
        'Bấm “Đặt lại số” để nạp lại hàng chờ rồi thao tác lại.',
      );
      return;
    }

    setState(() {
      // Số đang khám cũng phải đổi theo: khi bệnh nhân đang khám xin đợi,
      // người kế tiếp lên khám và nhận đúng số mới (vd 2 → 1).
      current = doi(current);
      next = doi(next);
      waiting = <int>[for (final so in waiting) doi(so)];
      // Chỉ số của những người ĐÃ KHÁM đi theo bảng đổi số. Sổ “SỐ ĐÃ CHO
      // QUA” (chip + lịch sử xin đợi) giữ nguyên số cũ, tên cũ và mã lịch
      // hẹn cũ — không thao tác nào ngoài “Đặt lại số” được sửa sổ này.
      for (var i = 0; i < passed.length; i++) {
        final entry = passed[i];
        if (entry.deferred) continue;
        final moi = renumber[entry.number];
        if (moi != null) {
          passed[i] = (number: moi, deferred: false);
        }
      }
      for (var i = 0; i < _eligibleAppointmentNumbers.length; i++) {
        _eligibleAppointmentNumbers[i] = doi(_eligibleAppointmentNumbers[i]);
      }
      for (var i = 0; i < _scheduledFutureInserts.length; i++) {
        final insert = _scheduledFutureInserts[i];
        _scheduledFutureInserts[i] = (
          number: doi(insert.number),
          afterNumber:
              insert.afterNumber == null ? null : doi(insert.afterNumber!),
        );
      }
      final soTheoId = <int, String>{
        for (final entry in _appointmentIdByNumber.entries)
          doi(entry.key): entry.value,
      };
      _appointmentIdByNumber
        ..clear()
        ..addAll(soTheoId);
      final tenTheoSo = <int, String>{
        for (final entry in _patientNameByNumber.entries)
          doi(entry.key): entry.value,
      };
      _patientNameByNumber
        ..clear()
        ..addAll(tenTheoSo);
      // Tên trong “SỐ ĐÃ CHO QUA” khoá theo đúng số cũ của chip nên không
      // đổi khi đánh số lại hàng chờ.
      final vangMat = <int>{for (final so in _absentAppointmentNumbers) doi(so)};
      _absentAppointmentNumbers
        ..clear()
        ..addAll(vangMat);
      final chenLai = <int>{
        for (final so in _requeuedAppointmentNumbers) doi(so),
      };
      _requeuedAppointmentNumbers
        ..clear()
        ..addAll(chenLai);
      if (selected != null) selected = doi(selected!);
      for (final so in renumber.values) {
        if (so > lastIssued) lastIssued = so;
      }
      _syncRoomState();
    });

    final thayDoi = renumber.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final moTa = <String>[
      for (final entry in thayDoi) 'số ${entry.key} → ${entry.value}',
    ].join(', ');

    final ghi = widget.onRenumberAppointment;
    if (ghi == null) {
      if (!imLang) notify('$moDau: $moTa.');
      return;
    }

    for (final (appointmentId, soTheoLich) in canGhi) {
      _pendingRenumberByAppointmentId[appointmentId] = soTheoLich;
    }
    if (!imLang) notify('$moDau và cập nhật Firebase: $moTa.');

    var loi = 0;
    for (final (appointmentId, soTheoLich) in canGhi) {
      unawaited(
        ghi(appointmentId, soTheoLich).catchError((Object _) {
          loi += 1;
          _pendingRenumberByAppointmentId.remove(appointmentId);
          if (mounted && loi == 1) {
            notify(
              'Chưa cập nhật được số thứ tự mới lên Firebase. '
              'Kiểm tra kết nối rồi thử lại.',
            );
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tablet (chiều rộng màn hình từ 600dp): bỏ trần 620dp để giao diện
    // dàn full màn hình thay vì bó thành một cột hẹp ở giữa.
    final useFullWidth = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Ui.bgTop, _Ui.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: useFullWidth ? double.infinity : 620,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final tablet = constraints.maxWidth >= 768;
                  final gap = compact ? 10.0 : (tablet ? 18.0 : 14.0);
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : (tablet ? 28 : 22),
                      tablet ? 24 : 20,
                      compact ? 16 : (tablet ? 28 : 22),
                      tablet ? 36 : 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.chevron_left_rounded,
                              tooltip: 'Quay lại',
                              onPressed: () async {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  notify('Bạn đang ở màn hình chính.');
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.departmentName} - ${widget.hospitalName}',
                                    style: TextStyle(
                                      fontSize: compact
                                          ? 16.5
                                          : (tablet ? 22 : 19),
                                      fontWeight: FontWeight.w800,
                                      color: _Ui.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const _PulseDot(),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          widget.roomName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: _Ui.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _QueueDaySelector(
                          day: _selectedQueueDay,
                          onTap: () => unawaited(_pickQueueDay()),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _NumberCard(
                                label: 'SỐ HIỆN TẠI',
                                // Số bắt đầu mặc định là 0 cho tới khi bấm
                                // nút “Bắt đầu”.
                                value: '$current',
                                subtitle: _patientNameSubtitle(current),
                                gradient: _Ui.greenCard,
                                foreground: Colors.white,
                                glow: const Color(0x4D1FA24C),
                                icon: Icons.person_rounded,
                                compact: compact,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              child: _NumberCard(
                                label: 'SỐ TIẾP THEO',
                                value: next > 0 ? '$next' : '—',
                                subtitle: _patientNameSubtitle(next),
                                gradient: _Ui.amberCard,
                                foreground: const Color(0xFF3A2A00),
                                glow: const Color(0x4DFF9A00),
                                icon: Icons.hourglass_bottom_rounded,
                                compact: compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Bảng trạng thái hàng chờ: SizedBox khóa chiều cao
                        // toàn bảng, còn từng mục bên trong dùng ô chiều
                        // cao cố định (trống hay có dữ liệu đều như nhau,
                        // danh sách dài cuộn ngang). Nhờ vậy các nút bấm
                        // phía dưới không bao giờ dịch chuyển khi bấm.
                        SizedBox(
                          height: compact
                              ? _queuePanelHeightCompact
                              : _queuePanelHeightRegular,
                          child: _SoftCard(
                            padding: EdgeInsets.all(compact ? 16 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: _queuePanelHeaderHeight,
                                  child: _SectionHeader(
                                    title: 'SỐ ĐANG ĐỢI',
                                    count: waiting.length,
                                    accent: _Ui.red,
                                    accentSoft: const Color(0x1FFF534B),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: compact ? 52 : 58,
                                  child: waiting.isEmpty
                                      ? const Align(
                                          alignment: Alignment.centerLeft,
                                          child: _EmptyHint(
                                            icon: Icons.people_outline_rounded,
                                            text: 'Chưa có bệnh nhân đang đợi',
                                          ),
                                        )
                                      : ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.zero,
                                          itemCount: waiting.length,
                                          separatorBuilder: (_, _) =>
                                              SizedBox(width: compact ? 9 : 13),
                                          itemBuilder: (context, index) {
                                            final number = waiting[index];
                                            return _WaitingChip(
                                              number: number,
                                              patientName: _patientNameFor(
                                                number,
                                              ),
                                              selected: selected == number,
                                              compact: compact,
                                              onTap: () => setState(
                                                () => selected = number,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 18),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: _Ui.divider,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: _queuePanelHeaderHeight,
                                  child: _SectionHeader(
                                    title: 'SỐ ĐÃ CHO QUA',
                                    count: deferredNumbers.length,
                                    accent: _Ui.amber,
                                    accentSoft: const Color(0x24FFB300),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const SizedBox(
                                  height: _queuePanelHintHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      'Số mới bấm “Đợi” hiện đầu dải. Bấm vào '
                                      'số để chèn số đó trở lại hàng chờ.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _Ui.textFaint,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 42,
                                  child: deferredNumbers.isEmpty
                                      ? const Align(
                                          alignment: Alignment.centerLeft,
                                          child: _EmptyHint(
                                            icon: Icons
                                                .pause_circle_outline_rounded,
                                            text: 'Chưa có số nào bị cho qua',
                                          ),
                                        )
                                      : ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.zero,
                                          itemCount:
                                              newestDeferredNumbers.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 9),
                                          itemBuilder: (context, index) {
                                            final number =
                                                newestDeferredNumbers[index];
                                            return _DeferredChip(
                                              number: number,
                                              patientName:
                                                  _patientNameDaChoQua[number] ??
                                                  _patientNameFor(number),
                                              onTap: () => openInsertScreen(
                                                initialNumber: number,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 18),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: _Ui.divider,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: _queuePanelHeaderHeight,
                                  child: _SectionHeader(
                                    title: 'SỐ CHỜ TỚI SỐ MỐC',
                                    count: _scheduledFutureInserts.length,
                                    accent: const Color(0xFF2D6BFF),
                                    accentSoft: const Color(0x1F2D6BFF),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const SizedBox(
                                  height: _queuePanelHintHeight,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      'Chưa vào hàng chờ ngay; sẽ tự xuất '
                                      'hiện sau số mốc khi số mốc có trong danh sách.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _Ui.textFaint,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: _scheduledChipStripHeight,
                                  child: _scheduledFutureInserts.isEmpty
                                      ? const Align(
                                          alignment: Alignment.centerLeft,
                                          child: _EmptyHint(
                                            icon: Icons.schedule_rounded,
                                            text:
                                                'Chưa có lịch chèn theo số mốc',
                                          ),
                                        )
                                      : ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.zero,
                                          itemCount:
                                              _scheduledFutureInserts.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(width: 9),
                                          itemBuilder: (context, index) {
                                            final insert =
                                                _scheduledFutureInserts[index];
                                            return _ScheduledInsertChip(
                                              number: insert.number,
                                              afterNumber: insert.afterNumber!,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Các nút chính: "+ Chèn", "Đợi / Gọi lại" (mở bảng chọn
                        // số) và "Tiếp theo" (gộp với "Xác nhận khám").
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _ActionButton(
                                label: '+ Chèn',
                                icon: Icons.add_rounded,
                                iconLeading: true,
                                onPressed: openInsertScreen,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: 4,
                              child: _ActionButton(
                                label: 'Đợi / Gọi lại',
                                icon: Icons.swap_horiz_rounded,
                                onPressed: openHoldOrRecallSheet,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: 4,
                              child: _ActionButton(
                                label: current > 0 ? 'Tiếp theo' : 'Bắt đầu',
                                icon: current > 0
                                    ? Icons.arrow_forward_rounded
                                    : Icons.play_arrow_rounded,
                                primary: true,
                                onPressed: callNext,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _ActionButton(
                                label: 'Xác nhận vắng mặt',
                                icon: Icons.person_off_rounded,
                                iconLeading: true,
                                onPressed: markCurrentAbsent,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: 2,
                              child: _ActionButton(
                                label: 'Đặt lại số',
                                icon: Icons.restart_alt_rounded,
                                iconLeading: true,
                                danger: true,
                                onPressed: resetNumbers,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: paused
                                    ? 'Tiếp tục khám'
                                    : 'Tạm dừng khám',
                                icon: paused
                                    ? Icons.play_circle_fill_rounded
                                    : Icons.pause_circle_filled_rounded,
                                iconLeading: true,
                                color: paused ? _Ui.green : Colors.white,
                                onPressed: () {
                                  if (closed) {
                                    notify(
                                      'Phòng khám đã đóng. Mở phòng trước khi '
                                      'tạm dừng khám.',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    paused = !paused;
                                    // Chụp GIỜ MÁY đúng thời điểm bấm nút.
                                    // Không có timer chạy liên tục: mốc này
                                    // đứng yên cho đến lần bấm tiếp theo.
                                    final mocGio = DateTime.now();
                                    final gio = formatMayGio(mocGio);
                                    _lastStatusChangeAt = mocGio;
                                    _lastStatusChangeLabel = paused
                                        ? 'Tạm dừng lúc'
                                        : 'Tiếp tục lúc';
                                    message = paused
                                        ? 'Bác sĩ tạm dừng khám lúc $gio.\n'
                                              'Việc gọi số tiếp theo tạm thời bị dừng.\n'
                                              'Vui lòng chờ đến khi bác sĩ tiếp tục khám.'
                                        : 'Bác sĩ tiếp tục khám lúc $gio.\n'
                                              'Số thứ tự được gọi lại bình thường.';
                                    // Cập nhật ngay trạng thái phòng cho trang chính:
                                    // chỉ khi bấm nút này phòng mới hiện "Tạm dừng".
                                    _syncRoomState();
                                  });
                                  // Ghi cả `trang_thai_id` (12/13) và
                                  // `trang_thai` (mã chuỗi) lên
                                  // PhongKham/{roomId}. Các thiết bị khác
                                  // nghe realtime sẽ đổi theo.
                                  unawaited(
                                    _publishRoomStatusId(
                                      paused
                                          ? kRoomStatusPausedId
                                          : kRoomStatusOpenId,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatusBanner(
                          paused: paused,
                          closed: closed,
                          message: message ?? _defaultStatusMessage,
                          // Footer CHỈ hiện mốc giờ chụp lúc bấm
                          // Tạm dừng / Tiếp tục khám, không chạy liên tục.
                          footer: _LiveStatusFooter(
                            prefix:
                                '${widget.roomName} · ${widget.departmentName} · '
                                '${_formatQueueDay(_selectedQueueDay)}',
                            paused: paused,
                            closed: closed,
                            feedState: _feedState,
                            statusChangedAt: _lastStatusChangeAt,
                            statusChangeLabel: _lastStatusChangeLabel,
                          ),
                        ),
                        // NÚT DƯỚI CÙNG: đóng / mở phòng khám, nằm ngay
                        // dưới thẻ "Thông báo từ Bác sĩ".
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: closed ? 'Mở phòng khám' : 'Đóng phòng khám',
                          icon: closed
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          iconLeading: true,
                          color: closed ? _Ui.green : Colors.white,
                          danger: !closed,
                          onPressed: () {
                            final seDong = !closed;
                            setState(() {
                              closed = seDong;
                              // Đóng phòng là trạng thái cuối buổi, không
                              // chồng thêm trạng thái "Tạm dừng".
                              if (closed) paused = false;
                              // Bấm Đóng / Mở KHÔNG đổi mốc giờ của lần
                              // Tạm dừng / Tiếp tục khám trước đó.
                              message = null;
                              _syncRoomState();
                            });
                            // Đóng = 14, Mở lại = 13; ghi cả 2 field snake_case.
                            unawaited(
                              _publishRoomStatusId(
                                seDong
                                    ? kRoomStatusClosedId
                                    : kRoomStatusOpenId,
                              ),
                            );
                            notify(
                              seDong
                                  ? 'Đã đóng phòng khám. Các thao tác gọi số '
                                        'tạm bị khoá.'
                                  : 'Đã mở lại phòng khám.',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn hình "Khoa - Số hàng chờ": nhập một số mốc BẤT KỲ cho một hoặc
/// NHIỀU số đã bấm "Đợi". Mỗi số được chèn sẽ nằm NGAY SAU số mốc đã
/// nhập; số mốc không cần đang có trong hàng chờ — nếu chưa xuất hiện
/// trong danh sách lịch hẹn đã xác nhận, yêu cầu được giữ lịch đến khi
/// số mốc xuất hiện. Ô nào để trống thì số đó chưa được chèn lần này.
class InsertPositionScreen extends StatefulWidget {
  const InsertPositionScreen({
    super.key,
    required this.deferredNumbers,
    required this.waiting,
    required this.nextNumber,
    required this.lastIssued,
    this.initialNumber,
  });

  /// Số của những bệnh nhân đã bấm "Đợi" – danh sách để chọn chèn lại.
  final List<int> deferredNumbers;

  /// Ảnh chụp hàng chờ hiện tại (đúng thứ tự sẽ gọi) – dùng để đối chiếu số mốc.
  final List<int> waiting;

  /// Số tiếp theo hiện tại. Nhập đúng số này làm mốc nghĩa là chèn vào
  /// đầu hàng chờ, ngay sau số tiếp theo trong thứ tự gọi.
  final int nextNumber;

  /// STT lớn nhất đã biết từ danh sách lịch hẹn khi mở màn hình. Số mốc
  /// lớn hơn giá trị này được giữ lịch đến khi xuất hiện trong danh sách.
  final int lastIssued;

  /// Số được chọn sẵn khi mở màn hình (bấm từ hàng "SỐ ĐÃ CHO QUA").
  final int? initialNumber;

  @override
  State<InsertPositionScreen> createState() => _InsertPositionScreenState();
}

class _InsertPositionScreenState extends State<InsertPositionScreen> {
  int? selected;
  String? submitError;
  final Map<int, TextEditingController> controllers = {};
  final Map<int, FocusNode> focusNodes = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialNumber;
    if (initial != null && widget.deferredNumbers.contains(initial)) {
      selected = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodeFor(initial).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final focusNode in focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int number) =>
      controllers.putIfAbsent(number, () => TextEditingController());

  FocusNode _focusNodeFor(int number) =>
      focusNodes.putIfAbsent(number, () => FocusNode());

  /// Đánh dấu dòng đang nhập (chỉ để làm nổi bật dòng đó). Chuyển sang dòng
  /// khác KHÔNG xoá số mốc đã nhập ở các dòng còn lại, nên người dùng nhập
  /// được số mốc cho nhiều số trước khi bấm chèn một lần.
  void select(int number) {
    if (selected == number) {
      _focusNodeFor(number).requestFocus();
      return;
    }
    setState(() {
      selected = number;
      submitError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodeFor(number).requestFocus();
    });
  }

  /// Chuyển ô nhập xuống dòng kế tiếp (nút "Tiếp" trên bàn phím); ở dòng
  /// cuối thì đóng bàn phím để người dùng bấm nút chèn.
  void _focusNext(int number) {
    final index = widget.deferredNumbers.indexOf(number);
    if (index >= 0 && index + 1 < widget.deferredNumbers.length) {
      select(widget.deferredNumbers[index + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  /// Đọc & kiểm tra ô số mốc của MỘT số.
  ///
  /// Số mốc có thể là BẤT KỲ số nào, không bị giới hạn ở các số đang có
  /// trong hàng chờ:
  ///  - để trống            -> chưa chèn số này trong lần này;
  ///  - nhập 0              -> đưa lên đầu hàng chờ;
  ///  - nhập một số bất kỳ  -> số được chèn nằm NGAY SAU số mốc đó. Nếu
  ///    số mốc chưa xuất hiện trong danh sách lịch hẹn đã xác nhận, yêu
  ///    cầu được giữ lịch và tự áp dụng khi số mốc xuất hiện.
  ({bool isEmpty, String? error, int? afterNumber, String description})
  _parseRow(int number) {
    final raw = _controllerFor(number).text.trim();
    if (raw.isEmpty) {
      return (
        isEmpty: true,
        error: null,
        afterNumber: null,
        description: 'Để trống nếu chưa muốn chèn số này.',
      );
    }
    final value = int.tryParse(raw);
    if (value == null || value < 0) {
      return (
        isEmpty: false,
        error: 'Hãy nhập một số nguyên không âm làm số mốc.',
        afterNumber: null,
        description: '',
      );
    }
    if (value == 0) {
      return (
        isEmpty: false,
        error: null,
        afterNumber: null,
        description: 'Sẽ đưa lên đầu hàng chờ, trước mọi số đang đợi.',
      );
    }
    if (value == number) {
      return (
        isEmpty: false,
        error: 'Không thể chèn số $number sau chính số đó.',
        afterNumber: null,
        description: '',
      );
    }
    final String description;
    if (widget.waiting.contains(value)) {
      description = 'Sẽ chèn ngay sau số $value trong hàng chờ.';
    } else if (value == widget.nextNumber) {
      description =
          'Số $value là số tiếp theo; sẽ chèn vào đầu hàng chờ, '
          'ngay sau số $value.';
    } else if (value > widget.lastIssued) {
      description =
          'Số $value chưa có trong danh sách lịch hẹn hiện tại. Sẽ giữ '
          'lịch: khi số $value xuất hiện, số này sẽ nằm ngay sau số $value.';
    } else {
      final firstGreaterIndex = widget.waiting.indexWhere((n) => n > value);
      description = firstGreaterIndex == -1
          ? 'Số $value không có trong hàng chờ; sẽ xếp theo thứ tự số '
                'ở cuối hàng chờ.'
          : 'Số $value không có trong hàng chờ; sẽ xếp theo thứ tự số, '
                'ngay trước số ${widget.waiting[firstGreaterIndex]}.';
    }
    return (
      isEmpty: false,
      error: null,
      afterNumber: value,
      description: description,
    );
  }

  /// Gom mọi dòng đã nhập số mốc: danh sách yêu cầu chèn hợp lệ + các lỗi.
  ({List<InsertResult> results, List<String> errors}) _draftInserts() {
    final results = <InsertResult>[];
    final errors = <String>[];
    for (final number in widget.deferredNumbers) {
      final row = _parseRow(number);
      if (row.isEmpty) continue;
      final error = row.error;
      if (error != null) {
        errors.add('Số $number: $error');
      } else {
        // afterNumber có thể là null một cách hợp lệ (nhập 0 = đầu hàng).
        results.add((number: number, afterNumber: row.afterNumber));
      }
    }
    return (results: results, errors: errors);
  }

  void submit() {
    final draft = _draftInserts();
    if (draft.errors.isNotEmpty) {
      setState(() => submitError = draft.errors.join('\n'));
      return;
    }
    if (draft.results.isEmpty) {
      setState(() => submitError = 'Nhập số mốc cho ít nhất một số cần chèn.');
      return;
    }
    Navigator.of(context).pop<List<InsertResult>>(draft.results);
  }

  @override
  Widget build(BuildContext context) {
    // Tách các yêu cầu chèn ngay (xem trước được trong hàng chờ hiện tại)
    // khỏi các yêu cầu chờ số mốc tương lai xuất hiện.
    final draft = _draftInserts();
    final immediateResults = draft.results
        .where((r) => !_isFutureScheduledInsert(r, widget.lastIssued))
        .toList();
    final futureResults = draft.results
        .where((r) => _isFutureScheduledInsert(r, widget.lastIssued))
        .toList();
    final mergedWaiting = _waitingAfterInserts(
      widget.waiting,
      immediateResults,
      nextNumber: widget.nextNumber,
    );
    final insertedNumbers = immediateResults.map((r) => r.number).toSet();
    final futureDetails = <String>[
      for (final r in futureResults) 'số ${r.number} sau số ${r.afterNumber}',
    ].join(' · ');
    final summaryDetails = <String>[
      for (final r in draft.results)
        r.afterNumber == null
            ? 'số ${r.number} → đầu hàng chờ'
            : _isFutureScheduledInsert(r, widget.lastIssued)
            ? 'số ${r.number} → chờ ngay sau số ${r.afterNumber} khi tới số đó'
            : 'số ${r.number} → ngay sau số ${r.afterNumber}',
    ].join(' · ');
    final summary = draft.results.isEmpty
        ? 'Nhập một số bất kỳ làm mốc cho một hoặc nhiều số rồi bấm '
              '“Chèn”. Số mốc chưa tới sẽ được giữ lịch; nhập 0 để đưa '
              'một số lên đầu hàng chờ.'
        : 'Sẽ chèn ${draft.results.length} số: $summaryDetails.';
    final caption = submitError ?? summary;
    final isError = submitError != null;
    // Tablet (từ 600dp): bỏ trần 620dp, dàn full màn hình như màn chính.
    final useFullWidth = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Ui.bgTop, _Ui.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: useFullWidth ? double.infinity : 620,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final tablet = constraints.maxWidth >= 768;
                  final gap = compact ? 10.0 : (tablet ? 18.0 : 14.0);
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : (tablet ? 28 : 22),
                      tablet ? 24 : 20,
                      compact ? 16 : (tablet ? 28 : 22),
                      tablet ? 36 : 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _RoundIconButton(
                              icon: Icons.chevron_left_rounded,
                              tooltip: 'Quay lại',
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Khoa - Số hàng chờ',
                                style: TextStyle(
                                  fontSize: compact ? 16.5 : (tablet ? 22 : 19),
                                  fontWeight: FontWeight.w800,
                                  color: _Ui.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        const Text(
                          'Nhập số mốc bất kỳ cho từng số cần chèn — '
                          'số được chèn sẽ nằm ngay sau số mốc đó',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF6F7583),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Danh sách gồm những số đã bấm “Đợi”. Số mốc '
                          'không cần đang có trong hàng chờ; để trống '
                          'ô chưa chèn, nhập 0 để đưa lên đầu hàng.',
                          style: TextStyle(fontSize: 12, color: _Ui.textFaint),
                        ),
                        const SizedBox(height: 16),
                        _SoftCard(
                          padding: EdgeInsets.all(
                            compact ? 16 : (tablet ? 24 : 20),
                          ),
                          child: widget.deferredNumbers.isEmpty
                              ? const _EmptyHint(
                                  icon: Icons.pause_circle_outline_rounded,
                                  text: 'Chưa có bệnh nhân nào bấm “Đợi”.',
                                )
                              : Column(
                                  children: widget.deferredNumbers
                                      .map(
                                        (n) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _buildRow(n, compact),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        const SizedBox(height: 16),
                        // Xem trước thứ tự hàng chờ sau khi chèn tất cả các
                        // số đã nhập số mốc (số sắp chèn được tô nổi bật).
                        _SoftCard(
                          padding: EdgeInsets.all(
                            compact ? 16 : (tablet ? 24 : 20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                title: 'THỨ TỰ HÀNG CHỜ SAU KHI CHÈN',
                                count: mergedWaiting.length,
                                accent: _Ui.red,
                                accentSoft: const Color(0x1FFF534B),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ô tô màu là các số sắp được chèn. Nhiều số '
                                'cùng một số mốc sẽ xếp liên tiếp ngay sau '
                                'số mốc đó, theo thứ tự từ trên xuống.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _Ui.textFaint,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (mergedWaiting.isEmpty)
                                const _EmptyHint(
                                  icon: Icons.people_outline_rounded,
                                  text: 'Hàng chờ đang trống',
                                )
                              else
                                Wrap(
                                  spacing: 9,
                                  runSpacing: 9,
                                  children: [
                                    for (final n in mergedWaiting)
                                      _QueuePreviewChip(
                                        number: n,
                                        highlighted: insertedNumbers.contains(
                                          n,
                                        ),
                                      ),
                                  ],
                                ),
                              if (futureResults.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Chưa vào hàng chờ ngay: $futureDetails. '
                                  'Khi từng số mốc xuất hiện trong danh '
                                  'sách lịch hẹn đã xác nhận, các số này '
                                  'sẽ tự nằm ngay phía sau số mốc của nó.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D6BFF),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 22),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _ActionButton(
                                label: draft.results.isEmpty
                                    ? 'Chèn'
                                    : 'Chèn ${draft.results.length} số',
                                icon: Icons.playlist_add_check_rounded,
                                iconLeading: true,
                                primary: true,
                                onPressed: submit,
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              flex: 2,
                              child: _ActionButton(
                                label: 'Hủy',
                                icon: Icons.close_rounded,
                                iconLeading: true,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isError
                                ? const Color(0xFFFFF1F0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isError
                                  ? const Color(0xFFFFD6D2)
                                  : _Ui.cardBorder,
                            ),
                            boxShadow: _Ui.quietShadow,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isError
                                    ? Icons.error_outline_rounded
                                    : Icons.info_outline_rounded,
                                size: 16,
                                color: isError
                                    ? const Color(0xFFE5483F)
                                    : _Ui.textFaint,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  caption,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: isError
                                        ? const Color(0xFFD64545)
                                        : _Ui.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int number, bool compact) {
    final row = _parseRow(number);
    final hasInput = !row.isEmpty;
    // Tô nền khi dòng đang được nhập hoặc đã có số mốc (sẽ được chèn).
    final isSelected = selected == number || hasInput;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => select(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF3D778) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            // Badge số: viền vàng + bóng khi được chọn.
            AnimatedScale(
              scale: isSelected ? 1.05 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Container(
                width: 47,
                height: 47,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFCF00)
                        : Colors.transparent,
                    width: 3.5,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x33EE2F26),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _Ui.redChip,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controllerFor(number),
                    focusNode: _focusNodeFor(number),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onTap: () => select(number),
                    onSubmitted: (_) => _focusNext(number),
                    onChanged: (_) => setState(() => submitError = null),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                      color: _Ui.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Chèn sau số',
                      hintStyle: const TextStyle(
                        color: Color(0xFFB6BCC9),
                        fontWeight: FontWeight.w400,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: isSelected
                          ? Colors.white
                          : const Color(0xFFF6F8FC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE3E7F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE3E7F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A3242),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  // Dòng mô tả/lỗi riêng của số này ngay dưới ô nhập.
                  if (hasInput) ...[
                    const SizedBox(height: 6),
                    Text(
                      row.error ?? row.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: row.error != null
                            ? const Color(0xFFD64545)
                            : _Ui.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô số trong dải "THỨ TỰ HÀNG CHỜ SAU KHI CHÈN" ở màn hình chèn: số sắp
/// được chèn tô gradient nổi bật, số vốn có trong hàng chờ để nền nhạt.
class _QueuePreviewChip extends StatelessWidget {
  const _QueuePreviewChip({required this.number, required this.highlighted});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 44),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      gradient: highlighted ? _Ui.redChip : null,
      color: highlighted ? null : const Color(0xFFF4F6FB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: highlighted ? const Color(0xFFFFCF00) : const Color(0xFFE9ECF4),
        width: highlighted ? 2 : 1,
      ),
    ),
    child: Text(
      '$number',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: highlighted ? Colors.white : _Ui.textPrimary,
      ),
    ),
  );
}

/// Thẻ trắng bo tròn có bóng mềm – khối nội dung chính của các màn hình.
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _Ui.cardBorder),
      boxShadow: _Ui.cardShadow,
    ),
    child: child,
  );
}

/// Tiêu đề mục nhỏ: chấm màu + tiêu đề + nhãn số lượng.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    required this.accent,
    required this.accentSoft,
  });

  final String title;
  final int? count;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 14,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: _Ui.textSecondary,
          ),
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
      ],
    ],
  );
}

/// Chấm xanh nhấp nháy nhẹ báo phòng khám đang hoạt động.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 0.35,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: _Ui.green, shape: BoxShape.circle),
    ),
  );
}

/// Nút icon tròn (nút quay lại) có bóng mềm.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    height: 42,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Ui.cardBorder),
          ),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, color: _Ui.textPrimary, size: 28),
          ),
        ),
      ),
    ),
  );
}

/// Thẻ số lớn (SỐ HIỆN TẠI / SỐ TIẾP THEO): gradient, vòng trang trí và
/// hiệu ứng trượt khi số đổi.
class _NumberCard extends StatelessWidget {
  const _NumberCard({
    required this.label,
    required this.value,
    required this.gradient,
    required this.foreground,
    required this.glow,
    required this.icon,
    required this.compact,
    this.subtitle,
  });

  final String label;
  final String value;

  /// Thông tin phụ hiện ngay dưới STT (ví dụ tên bệnh nhân của lịch
  /// hẹn có `so_thu_tu` trùng với số trên thẻ). Vùng chữ luôn giữ
  /// chiều cao cố định nên thẻ không đổi kích thước khi chưa có tên.
  final String? subtitle;
  final LinearGradient gradient;
  final Color foreground;
  final Color glow;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelColor = foreground == Colors.white
        ? const Color(0xE6FFFFFF)
        : const Color(0xB31F1400);
    return Container(
      height: compact ? 146 : 162,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 26, offset: const Offset(0, 14)),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -30,
            top: -38,
            child: _DecoCircle(size: 118, color: Color(0x2EFFFFFF)),
          ),
          const Positioned(
            right: 44,
            bottom: -52,
            child: _DecoCircle(size: 94, color: Color(0x1FFFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 15, color: labelColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previousChildren, ?currentChild],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        value,
                        key: ValueKey<String>('number-$value'),
                        style: TextStyle(
                          fontSize: compact ? 58 : 72,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: compact ? 13 : 15,
                      child: subtitle == null
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: compact ? 9 : 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vòng tròn trang trí mờ trên thẻ gradient.
class _DecoCircle extends StatelessWidget {
  const _DecoCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Ô số đang chờ trong dải "SỐ ĐANG ĐỢI".
class _WaitingChip extends StatelessWidget {
  const _WaitingChip({
    required this.number,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.patientName,
  });

  final int number;

  /// Tên bệnh nhân của lịch hẹn có `so_thu_tu` trùng với [number].
  final String? patientName;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trimmedPatientName = patientName?.trim();
    final hasPatientName =
        trimmedPatientName != null && trimmedPatientName.isNotEmpty;
    return Semantics(
      selected: selected,
      button: true,
      label: hasPatientName
          ? 'Bệnh nhân số $number, tên bệnh nhân $trimmedPatientName'
          : 'Bệnh nhân số $number',
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: hasPatientName ? (compact ? 112 : 128) : (compact ? 54 : 76),
          height: compact ? 52 : 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? const Color(0xFFFFD400) : Colors.transparent,
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? const Color(0x59FFB300)
                    : const Color(0x33EE2F26),
                blurRadius: selected ? 20 : 13,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: _Ui.redChip,
                borderRadius: BorderRadius.circular(13),
              ),
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: hasPatientName ? 19 : 23,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasPatientName) ...[
                          const SizedBox(height: 3),
                          SizedBox(
                            width: compact ? 100 : 116,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                trimmedPatientName,
                                maxLines: 1,
                                style: TextStyle(
                                  color: const Color(0xE6FFFFFF),
                                  fontSize: compact ? 6.5 : 7,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô số trong bảng "Đợi / Gọi lại" (mục ĐANG KHÁM / CHỜ): bấm để cho số đó
/// xin đợi. Viền xanh dương = số đang khám, viền vàng = số tiếp theo.
class _SheetWaitChip extends StatelessWidget {
  const _SheetWaitChip({
    required this.number,
    required this.isCurrent,
    required this.isNext,
    required this.onTap,
    this.patientName,
  });

  final int number;

  /// Tên bệnh nhân của lịch hẹn có `so_thu_tu` trùng với [number].
  final String? patientName;
  final bool isCurrent;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = isCurrent || isNext;
    final borderColor = isCurrent
        ? const Color(0xFF2D6BFF)
        : isNext
        ? const Color(0xFFFFD400)
        : Colors.transparent;
    final shadowColor = isCurrent
        ? const Color(0x592D6BFF)
        : isNext
        ? const Color(0x59FFB300)
        : const Color(0x2EEE2F26);
    final trimmedPatientName = patientName?.trim();
    final hasPatientName =
        trimmedPatientName != null && trimmedPatientName.isNotEmpty;
    final baseLabel = isCurrent
        ? 'Cho số đang khám $number xin đợi'
        : isNext
        ? 'Cho số kế tiếp $number xin đợi'
        : 'Cho số $number xin đợi';
    return Semantics(
      button: true,
      label: hasPatientName
          ? '$baseLabel, tên bệnh nhân $trimmedPatientName'
          : baseLabel,
      child: Container(
        width: hasPatientName ? 118 : 74,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: highlighted ? 18 : 11,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: _Ui.redChip,
              borderRadius: BorderRadius.circular(13),
            ),
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        'ĐANG KHÁM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (isNext)
                      const Text(
                        'KẾ TIẾP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (hasPatientName)
                      SizedBox(
                        width: 104,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            trimmedPatientName,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xE6FFFFFF),
                              fontSize: 6.5,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô số trong bảng "Đợi / Gọi lại" (mục ĐÃ KHÁM): bấm để gọi lại bệnh nhân.
class _RecallChip extends StatelessWidget {
  const _RecallChip({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Gọi lại bệnh nhân số $number',
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0x1F2AC653),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Color(0xFF25A94C),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$number',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _Ui.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ô số trong hàng "SỐ ĐÃ CHO QUA": bấm để mở màn hình chèn lại số đó.
class _DeferredChip extends StatelessWidget {
  const _DeferredChip({
    required this.number,
    required this.onTap,
    this.patientName,
  });

  final int number;

  /// Tên bệnh nhân của số bị cho qua (hiện ngay cạnh số để nhân viên nhận
  /// ra ai đang đợi, kể cả khi số đã bị đánh lại).
  final String? patientName;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: (patientName ?? '').trim().isEmpty
        ? 'Số $number đã bị cho qua, bấm để chèn lại'
        : 'Số $number – ${patientName!.trim()} đã bị cho qua, '
              'bấm để chèn lại',
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0x24FFB300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  size: 13,
                  color: Color(0xFFD98E00),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$number',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _Ui.chipIdleText,
                ),
              ),
              if ((patientName ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    patientName!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _Ui.chipIdleText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ô hiển thị một lượt chèn đang chờ số mốc tương lai: "số → sau số mốc".
class _ScheduledInsertChip extends StatelessWidget {
  const _ScheduledInsertChip({required this.number, required this.afterNumber});

  final int number;
  final int afterNumber;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Số $number sẽ được chèn ngay sau số $afterNumber khi tới số đó',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBDCFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: Color(0xFF2D6BFF),
          ),
          const SizedBox(width: 7),
          Text(
            '$number → sau $afterNumber',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D4A7A),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Ô số trong bảng "Xác nhận vắng mặt" (chỉ gồm các số đã bấm "Đợi").
/// Bấm để chọn số cần ghi nhận vắng mặt.
class _AbsentChip extends StatelessWidget {
  const _AbsentChip({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Ghi nhận bệnh nhân số $number vắng mặt',
    child: Container(
      width: 86,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2EEE2F26),
            blurRadius: 11,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _Ui.redChip,
            borderRadius: BorderRadius.circular(13),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_rounded,
                      size: 11,
                      color: Color(0xD9FFFFFF),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Đã cho qua',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bảng màu + nội dung của thẻ thông báo theo 3 trạng thái phòng:
/// Đang khám (xanh) · Tạm dừng (kem/cam) · Đóng phòng (đỏ nhạt).
class _BannerStyle {
  const _BannerStyle({
    required this.heading,
    required this.icon,
    required this.background,
    required this.border,
    required this.shadow,
    required this.halo,
    required this.accent,
    required this.title,
    required this.body,
    required this.footer,
    required this.dot,
  });

  final String heading;
  final IconData icon;
  final Color background;
  final Color border;
  final Color shadow;
  final Color halo;
  final Color accent;
  final Color title;
  final Color body;
  final Color footer;
  final Color dot;

  factory _BannerStyle.of({required bool paused, required bool closed}) {
    if (closed) {
      return const _BannerStyle(
        heading: 'Thông báo đóng phòng khám',
        icon: Icons.close_rounded,
        background: Color(0xFFFFF1F0),
        border: Color(0xFFFFD9D6),
        shadow: Color(0x1FE5484D),
        halo: Color(0x2EE5484D),
        accent: Color(0xFFE5484D),
        title: Color(0xFF7A1D1D),
        body: Color(0xFF8A4B45),
        footer: Color(0xFFB5807A),
        dot: Color(0xFFD9A8A2),
      );
    }
    if (paused) {
      return const _BannerStyle(
        heading: 'Thông báo tạm dừng khám',
        icon: Icons.pause_rounded,
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE6BC),
        shadow: Color(0x1FF5A623),
        halo: Color(0x2EF5A623),
        accent: Color(0xFFF5A623),
        title: Color(0xFF6B4A00),
        body: Color(0xFF8A6A2F),
        footer: Color(0xFFB08F4E),
        dot: Color(0xFFC9A96A),
      );
    }
    return const _BannerStyle(
      heading: 'Thông báo từ Bác sĩ',
      icon: Icons.check_rounded,
      background: Color(0xFFEAF9F0),
      border: Color(0xFFCFF0DC),
      shadow: Color(0x1F2AC653),
      halo: Color(0x2E2AC653),
      accent: Color(0xFF2AC653),
      title: Color(0xFF14532C),
      body: Color(0xFF38624A),
      footer: Color(0xFF8AA79A),
      dot: Color(0xFF7FAE92),
    );
  }
}

/// Thẻ thông báo từ bác sĩ: xanh khi đang khám, kem + icon cam khi tạm
/// dừng, đỏ nhạt + icon đóng khi phòng khám đã đóng.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.paused,
    required this.closed,
    required this.message,
    required this.footer,
  });

  final bool paused;
  final bool closed;
  final String message;

  /// Dòng chân thẻ. Là [Widget] để footer tự quyết nội dung (mốc giờ
  /// chụp lúc bấm nút + trạng thái luồng dữ liệu) mà không cần rebuild
  /// cả màn hình hàng chờ.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final style = _BannerStyle.of(paused: paused, closed: closed);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: style.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(color: style.halo, shape: BoxShape.circle),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: style.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.heading,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: style.title,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.2,
                    height: 1.55,
                    color: style.body,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: style.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 10.3,
                          fontWeight: FontWeight.w500,
                          color: style.footer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: footer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bỏ phần giờ, chỉ giữ ngày/tháng/năm để so sánh và truyền cho Firestore.
DateTime _queueDayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Ngày hiển thị trên bộ chọn lịch: `dd/MM/yyyy`.
String _formatQueueDay(DateTime day) {
  String haiChuSo(int value) => value.toString().padLeft(2, '0');
  return '${haiChuSo(day.day)}/${haiChuSo(day.month)}/${day.year}';
}

/// Ô chọn lịch đặt ngay dưới tiêu đề màn hình gọi số.
///
/// Chỉ chọn theo NGÀY (không có ca/khung giờ). Bấm vào ô sẽ mở
/// `showDatePicker` với dải năm rộng để test dữ liệu lịch hẹn cũ/mới.
class _QueueDaySelector extends StatelessWidget {
  const _QueueDaySelector({required this.day, required this.onTap});

  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Ui.cardBorder),
          boxShadow: _Ui.quietShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: _Ui.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LỊCH TEST HÀNG CHỜ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _Ui.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ngày ${_formatQueueDay(day)} · bấm để đổi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: _Ui.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Chỉ chọn theo ngày · mọi ngày/tháng/năm',
                    style: TextStyle(fontSize: 10.5, color: _Ui.textFaint),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: _Ui.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Định dạng `HH:mm:ss` theo giờ địa phương của MÁY đang chạy app.
/// Dùng cho MỘT MỐC THỜI ĐIỂM đã chụp (lúc bấm Tạm dừng / Tiếp tục
/// khám), không phải cho đồng hồ chạy liên tục.
String formatMayGio(DateTime time) {
  String haiChuSo(int value) => value.toString().padLeft(2, '0');
  return '${haiChuSo(time.hour)}:${haiChuSo(time.minute)}'
      ':${haiChuSo(time.second)}';
}

/// Dòng chân thẻ thông báo: KHÔNG có đồng hồ chạy liên tục.
///
/// Giờ chỉ xuất hiện khi bác sĩ bấm "Tạm dừng khám" hoặc "Tiếp tục
/// khám": `_QueueScreenState` chụp `DateTime.now()` đúng thời điểm đó
/// rồi truyền vào đây. Mốc giờ đứng yên cho đến lần bấm tiếp theo, kể
/// cả khi luồng lịch hẹn realtime vẫn tiếp tục cập nhật nội dung thẻ.
/// Khi chưa bấm nút nào, footer chỉ hiện tên phòng/khoa và trạng thái
/// của luồng dữ liệu (`Giờ máy` / `Đang kết nối…` / `Realtime` /
/// `Mất kết nối`). Khi phòng đã đóng, footer thêm nhãn `Đã đóng phòng`.
class _LiveStatusFooter extends StatelessWidget {
  const _LiveStatusFooter({
    required this.prefix,
    required this.paused,
    required this.closed,
    required this.feedState,
    required this.statusChangedAt,
    required this.statusChangeLabel,
  });

  /// "Tên phòng · Tên khoa · Ngày đang chọn" lấy từ phòng bác sĩ đang mở.
  final String prefix;
  final bool paused;
  final bool closed;
  final QueueFeedState feedState;

  /// `null` khi phiên này chưa bấm Tạm dừng / Tiếp tục lần nào.
  final DateTime? statusChangedAt;
  final String statusChangeLabel;

  ({String label, Color color}) get _feedBadge {
    final neutral = closed
        ? const Color(0xFFB5807A)
        : paused
        ? const Color(0xFFB08F4E)
        : const Color(0xFF8AA79A);
    return switch (feedState) {
      QueueFeedState.local => (label: 'Giờ máy', color: neutral),
      QueueFeedState.connecting => (
        label: 'Đang kết nối…',
        color: const Color(0xFFC98A17),
      ),
      QueueFeedState.live => (
        label: 'Realtime',
        color: const Color(0xFF1E9C48),
      ),
      QueueFeedState.error => (
        label: 'Mất kết nối',
        color: const Color(0xFFD93F3F),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final badge = _feedBadge;
    final baseStyle = DefaultTextStyle.of(context).style;
    final mocGio = statusChangedAt;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          TextSpan(text: '$prefix · '),
          if (closed)
            TextSpan(
              text: 'Đã đóng phòng · ',
              style: baseStyle.copyWith(
                color: const Color(0xFFC23B3B),
                fontWeight: FontWeight.w700,
              ),
            ),
          if (mocGio != null)
            TextSpan(
              text: '${formatMayGio(mocGio)} · $statusChangeLabel · ',
              style: baseStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          TextSpan(
            text: badge.label,
            style: baseStyle.copyWith(
              color: badge.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Dòng gợi ý khi danh sách trống.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: _Ui.textFaint),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: _Ui.textFaint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

/// Nút hành động: biến thể chính (xanh dương), phụ (trắng) và nút xanh lá.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.iconLeading = false,
    this.color = Colors.white,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Nút chính màu xanh dương, chữ trắng.
  final bool primary;

  /// Đặt icon trước chữ (mặc định icon nằm sau chữ ở nút chính).
  final bool iconLeading;

  /// Màu nền nút: trắng (mặc định) hoặc xanh lá cho nút "Tiếp tục khám".
  final Color color;

  /// Nút phụ mang tính xoá/đặt lại: nền trắng, chữ và icon màu đỏ.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isGreen = !primary && color != Colors.white;
    final filled = primary || isGreen;
    final gradient = primary
        ? _Ui.blueButton
        : (isGreen ? _Ui.greenButton : null);
    final foreground = filled
        ? Colors.white
        : (danger ? const Color(0xFFD64545) : _Ui.textPrimary);
    final iconColor = filled
        ? Colors.white
        : (danger ? const Color(0xFFE5483F) : const Color(0xFF6B7285));
    final leading = icon != null && (!primary || iconLeading);
    final shadow = primary
        ? _Ui.blueShadow
        : (isGreen ? _Ui.greenShadow : _Ui.quietShadow);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? Colors.white : null,
            borderRadius: BorderRadius.circular(17),
            border: filled
                ? null
                : Border.all(
                    color: danger
                        ? const Color(0xFFF6D5D2)
                        : const Color(0xFFE7EAF3),
                    width: 1.4,
                  ),
          ),
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading) ...[
                        Icon(icon, size: 19, color: iconColor),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (icon != null && !leading) ...[
                        const SizedBox(width: 6),
                        Icon(icon, size: 19, color: iconColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
