import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/patient_notification_service.dart';
import 'department_room_picker.dart';
import 'queue_screen.dart';

/// Đọc danh sách khoa/phòng từ Cloud Firestore theo thời gian thực.
///
/// Cấu trúc dữ liệu của project hiện tại:
///
/// ```
/// BenhVien/{hospitalId}                { ten_benh_vien: "Bệnh viện ..." }
/// Khoa/{hospitalId}/danh_sach/{deptId} { ten_khoa: "Khoa ..." }
/// PhongKham/{roomId}                   { hospitalId: "BV001",
///                                         khoaId: "K001",
///                                         tenPhong: "NGT001",
///                                         tenKhoaGoc: "Khoa ...",
///                                         nhanVienId: "NV001" }
/// BenhNhan/{patientId}                { ho_ten: "Nguyễn Văn A" }
/// LichHen/{appointmentId}             { benh_vien_id: "BV001",
///                                         benh_nhan_id: "BN001",
///                                         ten_benh_nhan: "Nguyễn Văn A",
///                                         phong_kham_id: "BV001_K001_NGT001",
///                                         trang_thai_id: "2",
///                                         so_thu_tu: "4",
///                                         ngay_dat: "2026-11-01T00:00:00" }
/// ```
///
/// Khoa nằm trong subcollection `danh_sach` dưới document bệnh viện,
/// còn phòng nằm ở collection gốc PhongKham dùng chung cho mọi bệnh
/// viện nên khi tải được lọc bằng điều kiện hospitalId == {hospitalId}.
/// Phòng thuộc khoa nào nhờ trường `khoaId` (khớp id document khoa).
/// Tên trường được đọc linh hoạt theo nhiều biến thể (kèm biến thể
/// snake_case dự phòng) — xem các hàm ánh xạ ở cuối file. Tên
/// collection và trường lọc khai báo tập trung ở đầu
/// [ClinicFirestoreService] để đổi nhanh nếu project đặt khác.
///
/// Trạng thái phiên khám (đang khám/tạm dừng, số đang chờ...) KHÔNG lưu ở
/// đây mà vẫn do RoomSessionStore trong bộ nhớ quản lý như trước đây; màn
/// hình chọn phòng chồng hai lớp dữ liệu đó lên nhau.
///
/// Cách nối app với project Firebase: xem FIREBASE_SETUP.md. Điểm vào:
/// main_firebase.dart.
class ClinicFirestoreService {
  ClinicFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Collection bệnh viện: BenhVien/{hospitalId} (ví dụ BenhVien/BV001).
  static const String hospitalsCollection = 'BenhVien';

  /// Collection gốc của khoa: Khoa/{hospitalId}/danh_sach/{mã khoa}.
  static const String departmentsCollection = 'Khoa';

  /// Collection gốc của phòng: PhongKham/{mã phòng}. Phòng của mọi
  /// bệnh viện nằm chung tại đây, lọc theo trường [roomHospitalField].
  static const String roomsCollection = 'PhongKham';

  /// Subcollection chứa danh sách khoa dưới mỗi bệnh viện.
  static const String listSubcollection = 'danh_sach';

  /// Trường trong document phòng chứa mã bệnh viện của phòng đó
  /// (PhongKham/{mã phòng}.hospitalId == mã bệnh viện đang tải).
  static const String roomHospitalField = 'hospitalId';

  /// Collection lịch hẹn: LichHen/{mã lịch hẹn}. Đây là nguồn số thứ
  /// tự (`so_thu_tu`) cho màn hình hàng chờ của từng phòng.
  static const String appointmentsCollection = 'LichHen';

  /// Collection hồ sơ bệnh nhân: BenhNhan/{benh_nhan_id}. Khi LichHen
  /// không chép sẵn tên bệnh nhân, service tra document này bằng
  /// `benh_nhan_id` để hiện `ho_ten` dưới STT tương ứng.
  static const String patientsCollection = 'BenhNhan';

  /// Mã trạng thái lịch hẹn được đưa vào hàng chờ: Đã xác nhận.
  static const String confirmedStatusId = '2';

  /// Mã trạng thái ghi ngược khi khám xong: Hoàn thành.
  static const String completedStatusId = '5';

  /// Mã trạng thái ghi ngược khi xác nhận vắng mặt: Vắng mặt.
  static const String absentStatusId = '6';

  /// Mã trạng thái ghi ngược khi nhân viên nhấn Đợi cho một số.
  static const String deferredStatusId = '7';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _departmentsOf(
    String hospitalId,
  ) => _firestore
      .collection(departmentsCollection)
      .doc(hospitalId)
      .collection(listSubcollection);

  /// Chuẩn hoá dữ liệu lịch hẹn trước khi đưa cho các hàm ánh xạ thuần:
  /// Timestamp ở tầng cao nhất được đổi thành chuỗi ISO để hàm thuần
  /// không phải phụ thuộc vào kiểu của cloud_firestore.
  Map<String, Object?> _appointmentData(Map<String, dynamic> data) =>
      <String, Object?>{
        for (final entry in data.entries)
          entry.key: entry.value is Timestamp
              ? (entry.value as Timestamp).toDate().toIso8601String()
              : entry.value,
      };


  Query<Map<String, dynamic>> _roomsOf(String hospitalId) => _firestore
      .collection(roomsCollection)
      .where(roomHospitalField, isEqualTo: hospitalId);

  /// Theo dõi toàn bộ phòng của một bệnh viện theo thời gian thực.
  ///
  /// Nghe đồng thời danh sách khoa và danh sách phòng, ghép phòng vào
  /// khoa theo trường `khoaId` trong document phòng. Chỉ phát dữ liệu
  /// khi cả hai danh sách đã về ít nhất một lần (để giao diện hiện trạng
  /// thái đang tải thay vì nhấp nháy danh sách rỗng), sau đó phát lại mỗi
  /// khi có khoa/phòng nào thay đổi. Danh sách đã sắp theo tên khoa rồi
  /// theo mã phòng (PK2 đứng trước PK10).
  Stream<List<ClinicRoomData>> watchRooms({required String hospitalId}) {
    var departmentNames = <String, String>{};
    var rawRooms = <(String, Map<String, Object?>)>[];
    var hasDepartments = false;
    var hasRooms = false;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        departmentSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomSubscription;

    late final StreamController<List<ClinicRoomData>> controller;

    void emit() {
      if (controller.isClosed || !hasDepartments || !hasRooms) return;
      controller.add(
        clinicRoomsFromFirestore(
          hospitalId: hospitalId,
          departmentNames: departmentNames,
          rooms: rawRooms,
        ),
      );
    }

    void forwardError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }

    controller = StreamController<List<ClinicRoomData>>(
      onListen: () {
        departmentSubscription = _departmentsOf(hospitalId).snapshots().listen(
          (snapshot) {
            departmentNames = {
              for (final doc in snapshot.docs)
                doc.id: clinicDepartmentName(doc.id, doc.data()),
            };
            hasDepartments = true;
            emit();
          },
          onError: forwardError,
        );
        roomSubscription = _roomsOf(hospitalId).snapshots().listen(
          (snapshot) {
            rawRooms = [
              for (final doc in snapshot.docs) (doc.id, doc.data()),
            ];
            hasRooms = true;
            emit();
          },
          onError: forwardError,
        );
      },
      onCancel: () async {
        await departmentSubscription?.cancel();
        await roomSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  /// Theo dõi tên bệnh viện từ trường `ten_benh_vien` của document
  /// BenhVien/{hospitalId}; chưa có document/trường thì dùng [fallback].
  Stream<String> watchHospitalName({
    required String hospitalId,
    String fallback = 'Bệnh viện',
  }) {
    return _firestore
        .collection(hospitalsCollection)
        .doc(hospitalId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return fallback;
          return clinicHospitalName(data, fallback: fallback);
        });
  }

  /// Theo dõi số thứ tự của một phòng từ các lịch hẹn đủ điều kiện
  /// trong ngày [day] (mặc định là hôm nay theo giờ của thiết bị).
  ///
  /// Truy vấn chỉ lọc ở server theo `phong_kham_id` để không cần index
  /// tổ hợp; bệnh viện, trạng thái và ngày được lọc ở máy khách bằng
  /// [_clinicAppointmentQueueDraftFromFirestore]. Mặc định chỉ lịch hẹn
  /// Đã xác nhận (`trang_thai_id == '2'`) mới vào hàng chờ.
  ///
  /// Tên bệnh nhân được lấy trực tiếp từ `ten_benh_nhan`/`ho_ten` trong
  /// LichHen nếu có; nếu không, service nghe tiếp document
  /// BenhNhan/{benh_nhan_id} và gắn `ho_ten` vào đúng STT theo thời
  /// gian thực.
  Stream<AppointmentQueueUpdate> watchAppointmentQueue({
    required String hospitalId,
    required String roomId,
    DateTime? day,
    Set<String> eligibleStatusIds = const <String>{confirmedStatusId},
  }) {
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        appointmentSubscription;
    final profileSubscriptions =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final profileNamesById = <String, String>{};
    _AppointmentQueueDraft? latestDraft;
    var isCancelled = false;

    late final StreamController<AppointmentQueueUpdate> controller;

    void emit() {
      final draft = latestDraft;
      if (isCancelled || controller.isClosed || draft == null) return;
      controller.add(
        _appointmentQueueUpdateFromDraft(
          draft,
          patientNamesById: profileNamesById,
        ),
      );
    }

    void forwardError(Object error, StackTrace stackTrace) {
      if (!isCancelled && !controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }

    void syncProfileSubscriptions(_AppointmentQueueDraft draft) {
      final wantedPatientIds = <String>{
        for (final entry in draft.patientIdByNumber.entries)
          if (!draft.directPatientNameByNumber.containsKey(entry.key))
            entry.value,
      };

      for (final patientId in profileSubscriptions.keys.toList()) {
        if (!wantedPatientIds.contains(patientId)) {
          unawaited(profileSubscriptions.remove(patientId)?.cancel());
          profileNamesById.remove(patientId);
        }
      }

      for (final patientId in wantedPatientIds) {
        if (profileSubscriptions.containsKey(patientId)) continue;
        profileSubscriptions[patientId] = _firestore
            .collection(patientsCollection)
            .doc(patientId)
            .snapshots()
            .listen(
              (snapshot) {
                if (isCancelled) return;
                final data = snapshot.data();
                final name = data == null
                    ? ''
                    : clinicPatientProfileName(data);
                if (profileNamesById[patientId] == name) return;
                if (name.isEmpty) {
                  profileNamesById.remove(patientId);
                } else {
                  profileNamesById[patientId] = name;
                }
                emit();
              },
              onError: (Object _, StackTrace _) {
                // Không đọc được hồ sơ thì STT vẫn hoạt động bình thường,
                // chỉ không hiện dòng tên cho bệnh nhân đó.
                final subscription = profileSubscriptions.remove(patientId);
                if (subscription != null) unawaited(subscription.cancel());
                if (profileNamesById.remove(patientId) != null) emit();
              },
            );
      }
    }

    controller = StreamController<AppointmentQueueUpdate>(
      onListen: () {
        appointmentSubscription = _firestore
            .collection(appointmentsCollection)
            .where('phong_kham_id', isEqualTo: roomId)
            .snapshots()
            .listen(
              (snapshot) {
                latestDraft = _clinicAppointmentQueueDraftFromFirestore(
                  appointments: <(String, Map<String, Object?>)>[
                    for (final doc in snapshot.docs)
                      (doc.id, _appointmentData(doc.data())),
                  ],
                  hospitalId: hospitalId,
                  roomId: roomId,
                  day: day ?? DateTime.now(),
                  eligibleStatusIds: eligibleStatusIds,
                );
                syncProfileSubscriptions(latestDraft!);
                emit();
              },
              onError: forwardError,
            );
      },
      onCancel: () async {
        isCancelled = true;
        await appointmentSubscription?.cancel();
        for (final subscription in profileSubscriptions.values) {
          await subscription.cancel();
        }
        profileSubscriptions.clear();
      },
    );
    return controller.stream;
  }

  /// Ghi trạng thái mới cho một lịch hẹn, đồng thời cập nhật
  /// `ngay_cap_nhat` bằng timestamp của máy chủ Firestore.
  ///
  /// Sau khi ghi xong, tự động đẩy một thông báo sang PHẦN BỆNH NHÂN qua
  /// `ThongBaoHeThong` (dùng chung với Lễ tân/CSKH) để bệnh nhân biết ngay:
  ///  - `5` Đã khám xong
  ///  - `6` Vắng mặt
  ///  - `7` Xin đợi (cho qua lượt)
  ///  - `2` Được chèn/gọi lại vào hàng chờ
  ///
  /// Phần Bệnh nhân không cần sửa code: màn hình thông báo của bệnh nhân
  /// đang lắng nghe realtime đúng collection này (xem
  /// `PatientNotificationService.streamThongBaoCuaToi`).
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String statusId,
  }) async {
    final docRef = _firestore
        .collection(appointmentsCollection)
        .doc(appointmentId);

    // Đọc dữ liệu lịch hẹn trước khi ghi để lấy định danh bệnh nhân
    // (uid / mã bệnh nhân / số điện thoại) + số thứ tự cho thông báo.
    Map<String, dynamic> duLieuLichHen = const <String, dynamic>{};
    try {
      final snap = await docRef.get();
      final data = snap.data();
      if (data != null) duLieuLichHen = data;
    } catch (_) {
      // Không đọc được thì vẫn ghi trạng thái như bình thường.
    }

    await docRef.update(<String, dynamic>{
      'trang_thai_id': statusId,
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    });

    // Thông báo cho bệnh nhân — lỗi mạng không được làm hỏng thao tác hàng chờ.
    try {
      await PatientNotificationService.guiThongBaoTrangThaiKham(
        lichHenId: appointmentId,
        trangThaiId: statusId,
        duLieuLichHen: duLieuLichHen,
      );
    } catch (_) {}
  }

}

/// Màn hình chọn khoa/phòng lấy danh sách phòng từ Cloud Firestore theo
/// thời gian thực, trên nền [ClinicRoomPickerScreen].
///
/// Tự hiển thị màn hình đang tải/lỗi; khi có dữ liệu thì chuyển cho
/// [ClinicRoomPickerScreen] như bình thường nên trạng thái phiên khám vẫn
/// được RoomSessionStore phủ lên. Nhớ gọi Firebase.initializeApp() trong
/// main() trước khi dùng (xem main_firebase.dart).
class FirestoreClinicRoomPickerScreen extends StatefulWidget {
  const FirestoreClinicRoomPickerScreen({
    super.key,
    required this.hospitalId,
    this.hospitalName,
    this.initialDepartment = 'Khoa Tim',
    this.service,
    this.onLogout,
  });

  /// Mã bệnh viện trên Firestore (ví dụ 'BV001' — document
  /// BenhVien/BV001, Khoa/BV001/danh_sach và các phòng trong
  /// PhongKham có hospitalId BV001).
  final String hospitalId;

  /// Tên bệnh viện hiển thị; để trống (null) thì tự lấy trường
  /// `ten_benh_vien` từ document BenhVien/{hospitalId} trên Firestore.
  final String? hospitalName;
  final String initialDepartment;

  /// Nguồn dữ liệu Firestore; để trống thì dùng [ClinicFirestoreService]
  /// mặc định (FirebaseFirestore.instance).
  final ClinicFirestoreService? service;

  /// Xử lý đăng xuất do app bao quanh cung cấp (app tự kết thúc phiên
  /// và tự chuyển màn hình). Để `null` thì nút đăng xuất tự về
  /// `LoginScreen` trong login_screen.dart. Cách nối với app
  /// MEDICONNECT (AuthProvider + AppRoutes): xem FIREBASE_SETUP.md.
  final Future<void> Function()? onLogout;

  @override
  State<FirestoreClinicRoomPickerScreen> createState() =>
      _FirestoreClinicRoomPickerScreenState();
}

class _FirestoreClinicRoomPickerScreenState
    extends State<FirestoreClinicRoomPickerScreen> {
  late final ClinicFirestoreService _service;
  late Stream<List<ClinicRoomData>> _roomsStream;
  Stream<String>? _hospitalNameStream;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ClinicFirestoreService();
    _roomsStream = _service.watchRooms(hospitalId: widget.hospitalId);
    if (widget.hospitalName == null) {
      _hospitalNameStream = _service.watchHospitalName(
        hospitalId: widget.hospitalId,
      );
    }
  }

  void _retry() {
    setState(() {
      _roomsStream = _service.watchRooms(hospitalId: widget.hospitalId);
    });
  }

  ClinicAppointmentFeed _appointmentFeedForRoom(ClinicRoomData room) => (
    updates: _service.watchAppointmentQueue(
      hospitalId: widget.hospitalId,
      roomId: room.id,
    ),
    reportOutcome: (appointmentId, outcome) =>
        _service.updateAppointmentStatus(
          appointmentId: appointmentId,
          statusId: switch (outcome) {
            AppointmentOutcome.examined =>
              ClinicFirestoreService.completedStatusId,
            AppointmentOutcome.absent =>
              ClinicFirestoreService.absentStatusId,
            AppointmentOutcome.deferred =>
              ClinicFirestoreService.deferredStatusId,
            AppointmentOutcome.requeued =>
              ClinicFirestoreService.confirmedStatusId,
          },
        ),
  );


  Widget _roomsPicker(String hospitalName) =>
      StreamBuilder<List<ClinicRoomData>>(
        stream: _roomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FirestoreLoadError(
              error: snapshot.error!,
              onRetry: _retry,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const _FirestoreLoading();
          }
          return ClinicRoomPickerScreen(
            rooms: snapshot.data!,
            initialDepartment: widget.initialDepartment,
            hospitalName: hospitalName,
            onLogout: widget.onLogout,
            appointmentFeedFor: _appointmentFeedForRoom,
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final providedName = widget.hospitalName;
    if (providedName != null) return _roomsPicker(providedName);
    return StreamBuilder<String>(
      stream: _hospitalNameStream,
      builder: (context, snapshot) =>
          _roomsPicker(snapshot.data ?? 'Bệnh viện'),
    );
  }
}

class _FirestoreLoading extends StatelessWidget {
  const _FirestoreLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang tải danh sách khoa/phòng…'),
        ],
      ),
    ),
  );
}

class _FirestoreLoadError extends StatelessWidget {
  const _FirestoreLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Không tải được dữ liệu từ Firebase.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ánh xạ document Firestore → ClinicRoomData. Đây là các hàm thuần (chỉ
// nhận id + Map dữ liệu) để dễ kiểm thử và tái dùng khi đổi nguồn dữ liệu.
//
// Tên trường được đọc theo danh sách ưu tiên: tên thật trên project
// (Khoa/BenhVien dùng snake_case: ten_khoa, ten_benh_vien...; PhongKham
// dùng camelCase: khoaId, tenPhong, nhanVienId...) đứng đầu, kèm các
// biến thể còn lại để dữ liệu lệch chuẩn vẫn đọc được.
// ---------------------------------------------------------------------------

/// Giá trị String đầu tiên không rỗng trong các [keys] (đã cắt khoảng
/// trắng), không có thì trả về null.
String? _firstStringField(Map<String, Object?> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Tên bệnh viện từ document BenhVien/{hospitalId} (trường `ten_benh_vien`).
String clinicHospitalName(
  Map<String, Object?> data, {
  String fallback = 'Bệnh viện',
}) =>
    _firstStringField(data, const [
      'ten_benh_vien',
      'tenBenhVien',
      'ten_benhvien',
      'name',
      'ten',
    ]) ??
    fallback;

/// Tên khoa từ document khoa (trường `ten_khoa`); thiếu thì dùng mã khoa.
String clinicDepartmentName(String departmentId, Map<String, Object?> data) =>
    _firstStringField(data, const ['ten_khoa', 'tenKhoa', 'name', 'ten']) ??
    departmentId;

/// Mã khoa mà một phòng thuộc về, lấy từ document phòng (trường
/// `khoaId`); thiếu thì trả về chuỗi rỗng.
String clinicRoomDepartmentId(Map<String, Object?> data) =>
    _firstStringField(data, const [
      'khoaId',
      'id_khoa',
      'ma_khoa',
      'khoa_id',
      'idKhoa',
      'maKhoa',
      'departmentId',
    ]) ??
    '';

/// Dựng [ClinicRoomData] cho một phòng từ dữ liệu document của nó.
///
/// [departmentName] là tên khoa đã tra từ danh sách khoa; để trống thì
/// lần lượt dùng trường `ten_khoa` ngay trong document phòng rồi tới mã
/// khoa. Phòng mới lấy từ Firestore luôn ở trạng thái đang khám và chưa
/// có số liệu chờ/đã khám — phần trạng thái thật do RoomSessionStore phủ
/// lên khi phòng đã được mở trong phiên app.
/// Số hiện tại của phòng không suy ra từ document phòng; STT chỉ lấy
/// từ danh sách LichHen và trạng thái phiên hàng chờ.
ClinicRoomData clinicRoomFromFirestore({
  required String hospitalId,
  required String roomId,
  required Map<String, Object?> data,
  String departmentName = '',
}) {
  final departmentId = clinicRoomDepartmentId(data);
  final resolvedDepartmentName = departmentName.trim().isNotEmpty
      ? departmentName
      : (_firstStringField(data, const ['tenKhoaGoc', 'ten_khoa', 'tenKhoa']) ??
            departmentId);
  return ClinicRoomData(
    hospitalId: hospitalId,
    departmentId: departmentId,
    id: roomId,
    name:
        _firstStringField(data, const [
          'ten_phong',
          'ten_phongkham',
          'ten_phong_kham',
          'tenPhong',
          'name',
          'ten',
        ]) ??
        roomId,
    department: resolvedDepartmentName,
    staffId:
        _firstStringField(data, const [
          'nhanVienId',
          'id_nhanvien',
          'ma_nhanvien',
          'nhan_vien_id',
          'staffId',
          'idNhanVien',
        ]) ??
        '',
    status: ClinicRoomStatus.open,
    currentNumber: null,
    waitingCount: 0,
    examinedCount: 0,
  );
}

/// Ghép danh sách phòng thô với tên khoa ([departmentNames]: mã khoa →
/// tên khoa) thành danh sách phẳng đã sắp xếp: theo tên khoa, rồi mã
/// phòng (PK2 trước PK10), rồi tên phòng.
List<ClinicRoomData> clinicRoomsFromFirestore({
  required String hospitalId,
  required Map<String, String> departmentNames,
  required List<(String, Map<String, Object?>)> rooms,
}) {
  final result = <ClinicRoomData>[
    for (final (roomId, data) in rooms)
      clinicRoomFromFirestore(
        hospitalId: hospitalId,
        roomId: roomId,
        data: data,
        departmentName: departmentNames[clinicRoomDepartmentId(data)] ?? '',
      ),
  ];
  result.sort((a, b) {
    final byDepartment = a.department.toLowerCase().compareTo(
      b.department.toLowerCase(),
    );
    if (byDepartment != 0) return byDepartment;
    final byRoomId = compareClinicRoomIds(a.id, b.id);
    if (byRoomId != 0) return byRoomId;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}

/// So sánh mã phòng theo phần số ở cuối (PK2 < PK10); hai mã cùng phần số
/// hoặc không có số cuối thì so sánh chuỗi như thường.
int compareClinicRoomIds(String a, String b) {
  final numberA = _trailingNumber(a);
  final numberB = _trailingNumber(b);
  if (numberA != null && numberB != null && numberA != numberB) {
    return numberA.compareTo(numberB);
  }
  return a.compareTo(b);
}

int? _trailingNumber(String value) {
  final match = RegExp(r'(\d+)$').firstMatch(value);
  return match == null ? null : int.parse(match.group(1)!);
}

/// Chuỗi đã cắt khoảng trắng hoặc số nguyên được chuyển thành chuỗi
/// trong các [keys]; không có giá trị phù hợp thì trả về chuỗi rỗng.
/// Dùng cho các mã trạng thái có thể được lưu dạng '2' hoặc 2.
String _stringOrNumberField(Map<String, Object?> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
  }
  return '';
}

/// Số thứ tự của một lịch hẹn (trường `so_thu_tu`, có thể lưu dạng
/// chuỗi '4' hoặc số 4). Thiếu/không hợp lệ/không dương thì null.
int? clinicAppointmentNumber(Map<String, Object?> data) {
  for (final key in const ['so_thu_tu', 'soThuTu', 'stt', 'so_thu_tu_kham']) {
    final value = data[key];
    if (value is num) {
      final number = value.toInt();
      if (number > 0) return number;
    } else if (value is String) {
      final number = int.tryParse(value.trim());
      if (number != null && number > 0) return number;
    }
  }
  return null;
}

/// Mã trạng thái của lịch hẹn (trường `trang_thai_id`).
String clinicAppointmentStatusId(Map<String, Object?> data) =>
    _stringOrNumberField(data, const [
      'trang_thai_id',
      'trangThaiId',
      'statusId',
      'trang_thai',
    ]);

/// Mã bệnh nhân của lịch hẹn (trường `benh_nhan_id`); thiếu thì rỗng.
String clinicAppointmentPatientId(Map<String, Object?> data) =>
    _stringOrNumberField(data, const [
      'benh_nhan_id',
      'benhNhanId',
      'patientId',
      'benh_nhan_uid',
      'patientUid',
    ]);

String _normalizePatientName(String? value) =>
    (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

/// Tên bệnh nhân chép sẵn ngay trong document lịch hẹn, nếu có.
/// Trường chuẩn hiện tại là `ten_benh_nhan`/`ho_ten`; các tên còn lại là
/// biến thể dự phòng để dữ liệu lệch chuẩn một chút vẫn đọc được.
String clinicAppointmentPatientName(Map<String, Object?> data) =>
    _normalizePatientName(
      _firstStringField(data, const [
        'ten_benh_nhan',
        'tenBenhNhan',
        'ho_ten_benh_nhan',
        'hoTenBenhNhan',
        'ho_ten',
        'hoTen',
        'ho_va_ten',
        'hoVaTen',
        'patientName',
        'patient_name',
        'fullName',
        'displayName',
        'name',
        'ten',
      ]),
    );

/// Tên bệnh nhân trong document hồ sơ BenhNhan/{benh_nhan_id}.
/// Trường chuẩn hiện tại là `ho_ten`.
String clinicPatientProfileName(Map<String, Object?> data) =>
    _normalizePatientName(
      _firstStringField(data, const [
        'ho_ten',
        'hoTen',
        'ho_va_ten',
        'hoVaTen',
        'ten_benh_nhan',
        'tenBenhNhan',
        'fullName',
        'displayName',
        'patientName',
        'patient_name',
        'name',
        'ten',
      ]),
    );

/// Ngày hẹn (chỉ phần ngày, giờ địa phương) của một lịch hẹn.
///
/// Ưu tiên trường `ngay_dat` dạng chuỗi ISO/Timestamp đã được chuẩn
/// hoá thành ISO; `...T17:00:00Z` của nửa đêm giờ Việt Nam sẽ quy về
/// đúng ngày hôm sau khi thiết bị đặt múi giờ địa phương. Thiếu hoặc
/// không đọc được trường này thì suy từ mã document dạng
/// `LH_yyyyMMdd_xxxxx`.
DateTime? clinicAppointmentDay(
  String appointmentId,
  Map<String, Object?> data,
) {
  final raw = _firstStringField(data, const [
    'ngay_dat',
    'ngayDat',
    'ngay_hen',
    'ngayHen',
    'appointmentDate',
  ]);
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed != null) {
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final match = RegExp(r'(\d{4})(\d{2})(\d{2})').firstMatch(appointmentId);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// Bản nháp nội bộ sau khi lọc LichHen: ngoài STT và mã lịch hẹn còn
/// giữ mã bệnh nhân để service tra hồ sơ BenhNhan, cùng tên bệnh nhân
/// đã chép sẵn trực tiếp trong LichHen (nếu có).
typedef _AppointmentQueueDraft = ({
  List<int> numbers,
  Map<int, String> appointmentIdByNumber,
  Map<int, String> patientIdByNumber,
  Map<int, String> directPatientNameByNumber,
});

/// Lọc lịch hẹn thô thành bản nháp số thứ tự cho một phòng/ngày.
///
/// Chỉ giữ lịch hẹn đúng bệnh viện/phòng (khi document có các trường
/// tương ứng), thuộc [day], có trạng thái trong [eligibleStatusIds]
/// và có `so_thu_tu` hợp lệ. Với mỗi số được giữ, hàm đồng thời trả về
/// mã lịch hẹn, `benh_nhan_id` và tên bệnh nhân chép sẵn trong LichHen
/// của đúng document đó. Số trùng nhau chỉ giữ một lần; document thắng
/// được chọn theo mã lịch hẹn tăng dần để kết quả ổn định.
_AppointmentQueueDraft _clinicAppointmentQueueDraftFromFirestore({
  required List<(String, Map<String, Object?>)> appointments,
  required String hospitalId,
  required String roomId,
  required DateTime day,
  Set<String> eligibleStatusIds = const <String>{'2'},
}) {
  final targetDay = DateTime(day.year, day.month, day.day);
  final sortedAppointments =
      List<(String, Map<String, Object?>)>.of(appointments)
        ..sort((a, b) => a.$1.compareTo(b.$1));
  final appointmentIdByNumber = <int, String>{};
  final patientIdByNumber = <int, String>{};
  final directPatientNameByNumber = <int, String>{};

  for (final (appointmentId, data) in sortedAppointments) {
    final roomField = _firstStringField(data, const [
      'phong_kham_id',
      'phongKhamId',
      'roomId',
    ]);
    if (roomField != null && roomField != roomId) continue;

    final hospitalField = _firstStringField(data, const [
      'benh_vien_id',
      'benhVienId',
      'hospitalId',
    ]);
    if (hospitalField != null && hospitalField != hospitalId) continue;
    if (!eligibleStatusIds.contains(clinicAppointmentStatusId(data))) {
      continue;
    }
    if (clinicAppointmentDay(appointmentId, data) != targetDay) continue;

    final number = clinicAppointmentNumber(data);
    if (number == null || appointmentIdByNumber.containsKey(number)) {
      continue;
    }
    appointmentIdByNumber[number] = appointmentId;
    final patientId = clinicAppointmentPatientId(data);
    if (patientId.isNotEmpty) patientIdByNumber[number] = patientId;
    final directPatientName = clinicAppointmentPatientName(data);
    if (directPatientName.isNotEmpty) {
      directPatientNameByNumber[number] = directPatientName;
    }
  }

  final numbers = appointmentIdByNumber.keys.toList()..sort();
  return (
    numbers: numbers,
    appointmentIdByNumber: <int, String>{
      for (final number in numbers) number: appointmentIdByNumber[number]!,
    },
    patientIdByNumber: <int, String>{
      for (final number in numbers)
        if (patientIdByNumber.containsKey(number))
          number: patientIdByNumber[number]!,
    },
    directPatientNameByNumber: <int, String>{
      for (final number in numbers)
        if (directPatientNameByNumber.containsKey(number))
          number: directPatientNameByNumber[number]!,
    },
  );
}

/// Ghép một bản nháp LichHen với tên đã tra từ hồ sơ BenhNhan thành đợt
/// cập nhật cho QueueScreen. Tên chép sẵn trong LichHen được ưu tiên;
/// nếu không có thì dùng [patientNamesById] theo `benh_nhan_id`.
AppointmentQueueUpdate _appointmentQueueUpdateFromDraft(
  _AppointmentQueueDraft draft, {
  Map<String, String> patientNamesById = const <String, String>{},
}) {
  final patientNameByNumber = <int, String>{};
  for (final number in draft.numbers) {
    final patientId = draft.patientIdByNumber[number];
    final name = _normalizePatientName(
      draft.directPatientNameByNumber[number] ??
          (patientId == null ? null : patientNamesById[patientId]),
    );
    if (name.isNotEmpty) patientNameByNumber[number] = name;
  }
  return (
    numbers: draft.numbers,
    appointmentIdByNumber: draft.appointmentIdByNumber,
    patientNameByNumber: patientNameByNumber,
  );
}

/// Lọc lịch hẹn thô thành đợt cập nhật số thứ tự cho một phòng/ngày.
///
/// Tên bệnh nhân chép sẵn trong LichHen được dùng ngay. Với lịch hẹn
/// chỉ có `benh_nhan_id`, truyền [patientNamesById] đã tra từ hồ sơ
/// BenhNhan để gắn đúng tên vào STT tương ứng; `watchAppointmentQueue`
/// tự làm bước tra cứu này theo thời gian thực.
AppointmentQueueUpdate clinicAppointmentQueueFromFirestore({
  required List<(String, Map<String, Object?>)> appointments,
  required String hospitalId,
  required String roomId,
  required DateTime day,
  Set<String> eligibleStatusIds = const <String>{'2'},
  Map<String, String> patientNamesById = const <String, String>{},
}) {
  final draft = _clinicAppointmentQueueDraftFromFirestore(
    appointments: appointments,
    hospitalId: hospitalId,
    roomId: roomId,
    day: day,
    eligibleStatusIds: eligibleStatusIds,
  );
  return _appointmentQueueUpdateFromDraft(
    draft,
    patientNamesById: patientNamesById,
  );
}
