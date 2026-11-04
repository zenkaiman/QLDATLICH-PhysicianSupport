import 'dart:async';

import 'package:flutter/material.dart';

import 'room_session_store.dart';

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
    this.onAppointmentOutcome,
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

  /// Báo kết quả khám xong/vắng mặt về nơi lưu lịch hẹn.
  ///
  /// Callback nhận mã lịch hẹn đã được ánh xạ từ số thứ tự trong các
  /// đợt cập nhật của [appointmentQueueStream]. Lỗi của callback chỉ
  /// hiện thông báo, không chặn thao tác gọi số trên màn hình.
  final Future<void> Function(String appointmentId, AppointmentOutcome outcome)?
  onAppointmentOutcome;

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

  /// Tập số lịch hẹn đủ điều kiện trong lần đồng bộ gần nhất.
  List<int> _eligibleAppointmentNumbers = <int>[];

  /// Ánh xạ tích luỹ số thứ tự → mã lịch hẹn, dùng khi ghi ngược
  /// các trạng thái khám xong/vắng mặt/xin đợi/chèn lại.
  final Map<int, String> _appointmentIdByNumber = <int, String>{};

  /// Ánh xạ tích luỹ số thứ tự → tên bệnh nhân của lịch hẹn tương ứng.
  /// Chỉ nhận dữ liệu từ các lịch hẹn đã qua bộ lọc đúng phòng/bệnh
  /// viện, đúng ngày hôm nay trên máy và đúng trạng thái đủ điều kiện.
  final Map<int, String> _patientNameByNumber = <int, String>{};

  /// Các số đã xác nhận vắng mặt trên máy này; không nạp lại từ luồng
  /// lịch hẹn trong lúc Firebase chưa kịp đổi trạng thái.
  final Set<int> _absentAppointmentNumbers = <int>{};

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
  String? message;

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
      paused = snapshot.paused;
    } else {
      // Lần đầu mở phòng: KHÔNG tự sinh số thứ tự.
      // Chỉ hiện số khi lịch hẹn thật của phòng hôm nay có `so_thu_tu`
      // (stream lịch hẹn sẽ nạp số vào); trước đó màn hình để trống
      // ("Chưa có bệnh nhân nào…") thay vì mặc định số 1.
      final start = widget.initialCurrent > 0 ? widget.initialCurrent : 0;
      current = start;
      next = 0;
      waiting = <int>[];
      lastIssued = start;
      snapshot
        ..started = true
        ..paused = false;
    }
    final appointmentStream = widget.appointmentQueueStream;
    if (appointmentStream != null) {
      _appointmentSubscription = appointmentStream.listen(
        _applyAppointmentUpdate,
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) {
            notify(
              'Không tải được số thứ tự từ lịch hẹn. '
              'Kiểm tra kết nối Firebase.',
            );
          }
        },
      );
    }

    // Đẩy trạng thái ra kho chung sau khi frame đầu vẽ xong, để trang chính
    // (màn hình chọn khoa/phòng) nhận đúng thông tin khi quay lại.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncRoomState();
    });
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    super.dispose();
  }

  /// Ghi trạng thái hiện tại của phòng vào [RoomSessionStore] và báo cho
  /// màn hình chính vẽ lại (trạng thái Tạm dừng / Đang khám, số hiện tại,
  /// số đang đợi, số đã khám).
  void _syncRoomState() {
    final store = RoomSessionStore.instance;
    store.sessionOf(_storeKey)
      ..started = true
      ..current = current
      ..next = next
      ..waiting = List<int>.of(waiting)
      ..lastIssued = lastIssued
      ..absentNumbers = _absentAppointmentNumbers.toList()
      ..requeuedNumbers = _requeuedAppointmentNumbers.toList()
      ..appointmentIdByNumber = Map<int, String>.of(_appointmentIdByNumber)
      ..patientNameByNumber = Map<int, String>.of(_patientNameByNumber)
      ..paused = paused
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

  /// Áp một đợt cập nhật từ luồng lịch hẹn vào trạng thái hiện tại.
  void _applyAppointmentUpdate(AppointmentQueueUpdate update) {
    if (!mounted) return;
    final newlyRequeuedNumbers = <int>[];
    setState(() {
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
      final passedNumbers = passed.map((entry) => entry.number).toSet();
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
      current = result.current;
      next = result.next;
      waiting = result.waiting;
      _scheduledFutureInserts
        ..clear()
        ..addAll(result.scheduledInserts);
      lastIssued = result.lastIssued;
      if (selected != null && !waiting.contains(selected)) selected = null;
      if (wasEmpty && current > 0) {
        message = next > 0
            ? 'Đã nạp số thứ tự từ lịch hẹn đã xác nhận.\n'
                  'Bệnh nhân số $current đang khám; số $next là số tiếp theo.'
            : 'Đã nạp số thứ tự từ lịch hẹn đã xác nhận.\n'
                  'Bệnh nhân số $current đang khám.';
      }
      _syncRoomState();
    });
    for (final number in newlyRequeuedNumbers) {
      _reportAppointmentOutcome(number, AppointmentOutcome.requeued);
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
    if (paused) {
      return 'Bác sĩ đã nhấn nút “Tạm dừng khám”.\n'
          'Việc gọi số tiếp theo tạm thời bị dừng.\n'
          'Vui lòng chờ đến khi bác sĩ tiếp tục khám.';
    }
    if (current <= 0) {
      return 'Chưa có bệnh nhân nào trong danh sách lịch hẹn đã xác nhận '
          'của phòng hôm nay.\n'
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
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi gọi số.');
      return;
    }
    if (current <= 0) {
      notify('Chưa có lịch hẹn đã xác nhận nào để gọi.');
      return;
    }
    final finished = current;
    var shouldReportExamined = false;
    setState(() {
      // Số từng xin đợi nay đã khám xong: bỏ khỏi "SỐ ĐÃ CHO QUA" để không
      // xuất hiện ở cả 2 danh sách cùng lúc.
      passed.removeWhere((e) => e.number == finished && e.deferred);
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
          'nhận hôm nay?\n\n'
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
      current = result.current;
      next = result.next;
      waiting = result.waiting;
      lastIssued = result.lastIssued;
      message = current > 0
          ? 'Đã đặt lại hàng chờ theo lịch hẹn đã xác nhận: số hiện '
                'tại = $current${next > 0 ? ', số tiếp theo = $next' : ''}.'
          : 'Đã đặt lại hàng chờ. Hiện chưa có lịch hẹn đã xác nhận '
                'nào cho phòng hôm nay.';
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
      // Số đã xin đợi nay xác nhận vắng mặt: bỏ khỏi "SỐ ĐÃ CHO QUA" và,
      // nếu số đó đang có lượt trong hàng chờ, bỏ luôn khỏi hàng chờ.
      passed.removeWhere(
        (entry) => entry.deferred && entry.number == absentNumber,
      );
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
          '\nSố $absentNumber đã được bỏ khỏi danh sách “SỐ ĐÃ CHO QUA”'
          '$queueNote.';
      _syncRoomState();
    });
    _reportAppointmentOutcome(absentNumber, AppointmentOutcome.absent);
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
    notify('Số $number đã được chuyển vào “SỐ ĐÃ CHO QUA”.');
  }

  /// Gọi lại một bệnh nhân đã khám xong: đưa số đó vào "SỐ HIỆN TẠI" ngay,
  /// số đang khám cũ lùi về "SỐ TIẾP THEO"; số kế tiếp cũ (chưa được gọi) quay
  /// trở lại đầu hàng chờ để không bị mất lượt.
  void recallNumber(int picked) {
    if (paused) {
      notify('Vui lòng tiếp tục khám trước khi gọi lại số.');
      return;
    }
    if (picked <= 0) return;
    final previousCurrent = current;
    final previousNext = next;
    setState(() {
      // Bệnh nhân vào phòng khám ngay: bỏ khỏi danh sách đã khám, sẽ được
      // đưa lại danh sách khi bác sĩ nhấn "Tiếp theo".
      // Số được gọi lại đang khám -> không còn thuộc "ĐÃ KHÁM" hay
      // "SỐ ĐÃ CHO QUA" nữa.
      passed.removeWhere((entry) => entry.number == picked);
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
    final immediateNumbersToReport = <int>{};
    setState(() {
      // Tách yêu cầu chèn ngay khỏi yêu cầu chờ số mốc tương lai, dựa trên
      // [lastIssued] tại thời điểm đóng màn hình chèn.
      final immediateResults = results
          .where((r) => !_isFutureScheduledInsert(r, lastIssued))
          .toList();
      final futureResults = results
          .where((r) => _isFutureScheduledInsert(r, lastIssued))
          .toList();
      final before = List<int>.of(waiting);
      // Chèn ngay: dựng lại hàng chờ trong một lượt theo các số mốc gốc.
      waiting = _waitingAfterInserts(
        before,
        immediateResults,
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
      // Cả số chèn ngay lẫn số đã lên lịch đều rời danh sách xin đợi.
      final insertedNumbers = results.map((r) => r.number).toSet();
      passed.removeWhere(
        (entry) => entry.deferred && insertedNumbers.contains(entry.number),
      );
      // Số chèn ngay được giữ tạm trong hàng chờ và sẽ báo về trạng
      // thái `2` ngay sau setState. Số chờ mốc tương lai vẫn giữ `7`
      // cho tới khi thực sự được đặt vào hàng chờ ở một đợt đồng bộ sau.
      _requeuedAppointmentNumbers.addAll(immediateResults.map((r) => r.number));
      immediateNumbersToReport.addAll(immediateResults.map((r) => r.number));
      selected = immediateResults.isEmpty
          ? null
          : immediateResults.first.number;
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
    for (final number in immediateNumbersToReport) {
      _reportAppointmentOutcome(number, AppointmentOutcome.requeued);
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
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _NumberCard(
                                label: 'SỐ HIỆN TẠI',
                                value: current > 0 ? '$current' : '—',
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
                                label: 'Tiếp theo',
                                icon: Icons.arrow_forward_rounded,
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
                                onPressed: () => setState(() {
                                  paused = !paused;
                                  message = paused
                                      ? 'Bác sĩ đã nhấn nút “Tạm dừng khám”.\nViệc gọi số tiếp theo tạm thời bị dừng.\n'
                                            'Vui lòng chờ đến khi bác sĩ tiếp tục khám.'
                                      : null;
                                  // Cập nhật ngay trạng thái phòng cho trang chính:
                                  // chỉ khi bấm nút này phòng mới hiện "Tạm dừng".
                                  _syncRoomState();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatusBanner(
                          paused: paused,
                          message: message ?? _defaultStatusMessage,
                          footer:
                              '${widget.roomName} · ${widget.departmentName} · 08:42',
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
  const _DeferredChip({required this.number, required this.onTap});

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Số $number đã bị cho qua, bấm để chèn lại',
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

/// Thẻ thông báo từ bác sĩ: xanh khi đang khám, kem + icon cam khi tạm dừng.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.paused,
    required this.message,
    required this.footer,
  });

  final bool paused;
  final String message;
  final String footer;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: paused ? const Color(0xFFFFF8E8) : const Color(0xFFEAF9F0),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: paused ? const Color(0xFFFFE6BC) : const Color(0xFFCFF0DC),
      ),
      boxShadow: [
        BoxShadow(
          color: paused ? const Color(0x1FF5A623) : const Color(0x1F2AC653),
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
          decoration: BoxDecoration(
            color: paused ? const Color(0x2EF5A623) : const Color(0x2E2AC653),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: paused ? const Color(0xFFF5A623) : const Color(0xFF2AC653),
              shape: BoxShape.circle,
            ),
            child: Icon(
              paused ? Icons.pause_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paused ? 'Thông báo tạm dừng khám' : 'Thông báo từ Bác sĩ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: paused
                      ? const Color(0xFF6B4A00)
                      : const Color(0xFF14532C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontSize: 12.2,
                  height: 1.55,
                  color: paused
                      ? const Color(0xFF8A6A2F)
                      : const Color(0xFF38624A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: paused
                          ? const Color(0xFFC9A96A)
                          : const Color(0xFF7FAE92),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    footer,
                    style: TextStyle(
                      fontSize: 10.3,
                      fontWeight: FontWeight.w500,
                      color: paused
                          ? const Color(0xFFB08F4E)
                          : const Color(0xFF8AA79A),
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
