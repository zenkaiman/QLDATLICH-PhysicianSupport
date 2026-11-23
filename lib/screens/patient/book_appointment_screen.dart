import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../models/appointment_item.dart';
import '../../models/family_profile_model.dart';
import '../../models/lichhen_model.dart';
import '../../models/phong_kham_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_profile_provider.dart';
import '../../providers/lich_hen_provider.dart';
import '../../services/hospital_service.dart';
import '../../services/lichhen_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/booking_helper.dart';
import '../../widgets/family_widgets.dart';
import '../../widgets/patient_widget/book_appointment_widget.dart';
import 'booking_confirm_sheet.dart';

/// BookAppointmentScreen: màn đặt lịch khám tại một bệnh viện (nhận dữ liệu bệnh viện
/// qua route arguments). Người dùng chọn người khám, một hoặc nhiều chuyên khoa,
/// rồi với mỗi chuyên khoa chọn phòng, ngày và ca; sau đó xác nhận để gửi yêu cầu.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _hospitalService = HospitalService();
  final _lichHenService = LichHenService();

  // Bệnh viện và danh sách chuyên khoa.
  Map<String, dynamic>? _hospitalData;
  String _hospitalId = '';
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingDepartments = true;
  String? _departmentLoadError;
  bool _isSpecialtyExpanded = true;

  // Lựa chọn của người dùng (khóa là id chuyên khoa).
  final Set<String> _selectedDepartmentIds = {};
  String? _activeDepartmentId;
  final Map<String, String> _selectedRoomByDept = {};
  final Map<String, DateTime> _selectedDayByDept = {};
  final Map<String, String> _selectedSlotByDept = {};
  String? _bookingProfileId;

  // Danh sách phòng khám theo chuyên khoa.
  final Map<String, List<PhongKhamModel>> _roomsByDept = {};
  final Set<String> _loadingRoomDepts = {};
  final Map<String, String> _roomErrorByDept = {};

  /// Chuyên khoa đã chọn đủ phòng, ngày và ca chưa.
  bool _hasScheduleFor(String id) =>
      _selectedRoomByDept.containsKey(id) &&
      _selectedDayByDept.containsKey(id) &&
      _selectedSlotByDept.containsKey(id);

  bool get _isScheduleComplete =>
      _selectedDepartmentIds.isNotEmpty &&
      _selectedDepartmentIds.every(_hasScheduleFor);

  // ───────────── Vòng đời ─────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LichHenProvider>().clearCache();
      setState(() {
        _bookingProfileId = context.read<FamilyProfileProvider>().currentId;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hospitalData != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _hospitalData = args;
      _hospitalId = (args['id'] ?? args['ma_benh_vien'] ?? '').toString();
      _fetchDepartments(_hospitalId);
    } else {
      // Thiếu dữ liệu bệnh viện thì thoát màn hình.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // ───────────── Tải dữ liệu ─────────────

  /// _fetchDepartments: tải danh sách chuyên khoa của bệnh viện từ Firestore.
  Future<void> _fetchDepartments(String hospitalId) async {
    if (hospitalId.isEmpty) {
      setState(() {
        _isLoadingDepartments = false;
        _departmentLoadError = 'Không xác định được bệnh viện.';
      });
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Khoa')
          .doc(hospitalId)
          .collection('danh_sach')
          .get();
      if (!mounted) return;
      setState(() {
        _departments = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoadingDepartments = false;
        _departmentLoadError = null;
      });
    } catch (e) {
      debugPrint('Lỗi khi lấy danh sách khoa: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingDepartments = false;
        _departmentLoadError = 'Không thể tải danh sách chuyên khoa.';
      });
    }
  }

  /// _fetchRooms: tải danh sách phòng khám của một chuyên khoa
  /// (bỏ qua nếu đã có hoặc đang tải, trừ khi [force]).
  Future<void> _fetchRooms(String departmentId, {bool force = false}) async {
    final alreadyHandled = _roomsByDept.containsKey(departmentId) ||
        _loadingRoomDepts.contains(departmentId);
    if (_hospitalId.isEmpty || (!force && alreadyHandled)) return;

    setState(() {
      _loadingRoomDepts.add(departmentId);
      _roomErrorByDept.remove(departmentId);
    });
    try {
      final rooms = await _hospitalService.getPhongKhamList(
        hospitalId: _hospitalId,
        khoaId: departmentId,
      );
      if (!mounted) return;
      setState(() {
        _roomsByDept[departmentId] = rooms;
        _loadingRoomDepts.remove(departmentId);
      });
    } catch (e) {
      debugPrint('Lỗi khi lấy danh sách phòng khám: $e');
      if (!mounted) return;
      setState(() {
        _loadingRoomDepts.remove(departmentId);
        _roomErrorByDept[departmentId] = 'Không thể tải danh sách phòng khám.';
      });
    }
  }

  // ───────────── Xử lý lựa chọn ─────────────

  /// _toggleDepartment: chọn hoặc bỏ chọn một chuyên khoa; chọn mới thì tải phòng khám.
  void _toggleDepartment(String departmentId) {
    setState(() {
      if (_selectedDepartmentIds.remove(departmentId)) {
        _selectedRoomByDept.remove(departmentId);
        _selectedDayByDept.remove(departmentId);
        _selectedSlotByDept.remove(departmentId);
        _activeDepartmentId =
            _selectedDepartmentIds.isEmpty ? null : _selectedDepartmentIds.last;
      } else {
        _selectedDepartmentIds.add(departmentId);
        _activeDepartmentId = departmentId;
      }
    });
    if (_selectedDepartmentIds.contains(departmentId)) {
      _fetchRooms(departmentId);
    }
  }

  /// _selectRoom: chọn phòng khám; đổi phòng thì xóa ngày và ca đã chọn trước đó.
  void _selectRoom(String departmentId, String roomId) {
    setState(() {
      if (_selectedRoomByDept[departmentId] != roomId) {
        _selectedRoomByDept[departmentId] = roomId;
        _selectedDayByDept.remove(departmentId);
        _selectedSlotByDept.remove(departmentId);
      }
    });
  }

  /// _selectDay: chọn ngày khám rồi nạp lại số chỗ còn trống của các ca.
  void _selectDay(String departmentId, String roomId, DateTime date) {
    setState(() {
      final current = _selectedDayByDept[departmentId];
      if (current == null || !BookingHelper.isSameDay(current, date)) {
        _selectedDayByDept[departmentId] = date;
        _selectedSlotByDept.remove(departmentId);
      }
    });
    _reloadSlots(departmentId, roomId, date);
  }

  /// _reloadSlots: nạp lại các ca khám (và số chỗ còn trống) của phòng trong một ngày.
  void _reloadSlots(String departmentId, String roomId, DateTime date) {
    context.read<LichHenProvider>().loadSlots(
      ngay: date,
      benhVienId: _hospitalId,
      khoaId: departmentId,
      phongKhamId: roomId,
      soBenhNhanToiDa: BookingHelper.roomMax(departmentId, roomId, _roomsByDept),
      force: true,
    );
  }

  /// _openMonthCalendar: mở lịch tháng (trong 3 tháng tới) để chọn ngày khám.
  Future<void> _openMonthCalendar(String departmentId, String roomId) async {
    final today = BookingHelper.today();
    var initial = _selectedDayByDept[departmentId] ?? today;
    if (initial.isBefore(today)) initial = today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year, today.month + 3, today.day),
      helpText: 'Chọn ngày khám',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primaryBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    _selectDay(departmentId, roomId, picked);
  }

  // ───────────── Đặt lịch ─────────────

  /// _warn: hiện snackbar cảnh báo.
  void _warn(String title, String message) => context.showAppSnackBar(
    title: title,
    message: message,
    type: SnackBarType.warning,
  );

  /// _hasConflict: kiểm tra từng chuyên khoa đã chọn có trùng lịch cũ của người khám không.
  /// Có trùng thì báo lỗi và trả true.
  Future<bool> _hasConflict({
    required FamilyProfileModel profile,
    required String benhNhanId,
  }) async {
    for (final departmentId in _selectedDepartmentIds) {
      final date = _selectedDayByDept[departmentId]!;
      final conflict = await _lichHenService.checkExistingBooking(
        benhNhanId: benhNhanId,
        benhVienId: _hospitalId,
        khoaId: departmentId,
        ngayDat: date,
        profileId: profile.id,
      );
      if (!mounted) return true;
      if (!conflict) continue;

      final tenKhoa = BookingHelper.departmentName(departmentId, _departments);
      final who = profile.isSelf ? 'Bạn' : profile.hoTen;
      context.showAppSnackBar(
        title: 'Lịch khám bị trùng',
        message:
            '$who đã có lịch khám tại khoa $tenKhoa vào ngày ${BookingHelper.formatDayMonth(date)}. Vui lòng chọn ngày khác hoặc hủy lịch cũ.',
        type: SnackBarType.error,
      );
      return true;
    }
    return false;
  }

  /// _continueBooking: kiểm tra dữ liệu, hiện bảng xác nhận rồi lưu các lịch hẹn đã chọn.
  Future<void> _continueBooking() async {
    // 1. Kiểm tra đầu vào.
    if (_selectedDepartmentIds.isEmpty) {
      _warn('Chưa chọn chuyên khoa', 'Vui lòng chọn chuyên khoa khám');
      return;
    }

    final family = context.read<FamilyProfileProvider>();
    final profile = family.byId(_bookingProfileId ?? family.currentId);
    if (profile == null) {
      _warn('Chưa chọn người khám', 'Vui lòng chọn khám cho ai');
      return;
    }
    if (!_isScheduleComplete) {
      _warn(
        'Chưa hoàn tất thông tin lịch khám',
        'Vui lòng chọn phòng khám, ngày và khung giờ cho tất cả chuyên khoa đã chọn',
      );
      return;
    }

    final lichHenProvider = context.read<LichHenProvider>();
    final benhNhanId =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    final tenNguoiDat = context.read<AuthProvider>().user?.hoTen;
    final tenBenhVien =
        _hospitalData?['ten_benh_vien']?.toString() ?? 'Bệnh viện không xác định';

    // 2. Không cho đặt trùng lịch.
    if (await _hasConflict(profile: profile, benhNhanId: benhNhanId)) return;

    // 3. Với mỗi chuyên khoa: kiểm tra ca còn chỗ, sinh mã lịch, chuẩn bị tác vụ lưu.
    final bookingDetails = <Map<String, String>>[];
    final saveTasks = <Future<void> Function()>[];
    final departmentNames = <String>[];
    final dateLabels = <String>[];
    final shiftLabels = <String>[];
    final lichHenIds = <String>[];

    for (final departmentId in _selectedDepartmentIds) {
      final roomId = _selectedRoomByDept[departmentId]!;
      final date = _selectedDayByDept[departmentId]!;
      final caId = _selectedSlotByDept[departmentId]!;

      final slotKey = BookingHelper.slotKeyFor(
        departmentId: departmentId,
        roomId: roomId,
        date: date,
        hospitalId: _hospitalId,
      );
      final selectedSlot = lichHenProvider
          .slotsOf(slotKey)
          .where((slot) => slot.caId == caId)
          .firstOrNull;
      if (selectedSlot == null) {
        _warn(
          'Không tìm thấy khung giờ',
          'Không tìm thấy khung giờ đã chọn. Vui lòng chọn lại.',
        );
        return;
      }

      final tenKhoa = BookingHelper.departmentName(departmentId, _departments);
      final selectedRoom = (_roomsByDept[departmentId] ?? [])
          .where((r) => r.id == roomId)
          .firstOrNull;
      var tenPhongKham = 'Phòng khám';
      if (selectedRoom != null) {
        tenPhongKham = selectedRoom.tenPhong.isNotEmpty
            ? selectedRoom.tenPhong
            : BookingHelper.roomNameOf(selectedRoom);
      }

      if (selectedSlot.tongSo > 0) {
        try {
          final conLai = await _lichHenService.soChoConLai(
            ngay: date,
            benhVienId: _hospitalId,
            khoaId: departmentId,
            phongKhamId: roomId,
            caId: caId,
            soBenhNhanToiDa: selectedSlot.tongSo,
          );
          if (!mounted) return;
          if (conLai <= 0) {
            lichHenProvider.loadSlots(
              ngay: date,
              benhVienId: _hospitalId,
              khoaId: departmentId,
              phongKhamId: roomId,
              soBenhNhanToiDa: selectedSlot.tongSo,
              force: true,
            );
            _warn(
              'Ca khám đã hết chỗ',
              '${selectedSlot.tenCa} ngày ${BookingHelper.formatDayMonth(date)} tại khoa $tenKhoa đã đủ số lượng. Vui lòng chọn ca hoặc ngày khác.',
            );
            return;
          }
        } catch (e) {
          debugPrint('Không kiểm tra được số chỗ còn lại: $e');
        }
      }

      final lichHenId = await _lichHenService.generateLichHenId(
        ngayDat: date,
        benhVienId: _hospitalId,
        khoaId: departmentId,
      );
      final shiftLabel =
          '${selectedSlot.tenCa} (${selectedSlot.gioBatDau} - ${selectedSlot.gioKetThuc})';

      bookingDetails.add({'departmentName': tenKhoa, 'shiftLabel': shiftLabel});
      departmentNames.add(tenKhoa);
      dateLabels.add(BookingHelper.formatDayMonth(date));
      shiftLabels.add(shiftLabel);
      lichHenIds.add(lichHenId);

      saveTasks.add(
        () => _lichHenService.saveBooking(
          trangThaiId: '1', // 1 = chờ duyệt
          ngayDat: date,
          caId: caId,
          benhVienId: _hospitalId,
          tenBenhVien: tenBenhVien,
          khoaId: departmentId,
          tenKhoa: tenKhoa,
          phongKhamId: roomId,
          tenPhongKham: tenPhongKham,
          benhNhanId: benhNhanId,
          lichHenId: lichHenId,
          profileId: profile.id,
          tenNguoiKham: profile.hoTen,
          quanHe: profile.quanHe,
          tenNguoiDat: tenNguoiDat,
        ),
      );
    }

    // 4. Hiện bảng xác nhận.
    final bhyt = (_hospitalData!['bhyt'] ?? _hospitalData!['bhyt_id'] ?? '')
        .toString()
        .toLowerCase();
    final dateLabel = dateLabels.toSet().join(', ');

    final confirmed = await showBookingConfirmSheet(
      context,
      hospitalName: tenBenhVien,
      bookingDetails: bookingDetails,
      dateLabel: dateLabel,
      address: _hospitalData!['dia_chi']?.toString() ?? 'Địa chỉ chưa cập nhật',
      bhytNote: (bhyt == 'co_bhyt' || bhyt == 'có bhyt')
          ? 'Có hỗ trợ khám BHYT'
          : 'Không hỗ trợ khám BHYT',
      patientName: profile.isSelf
          ? profile.hoTen
          : '${profile.quanHe} - ${profile.hoTen}',
    );
    if (confirmed != true || !mounted) return;

    // 5. Lưu tất cả lịch hẹn rồi chuyển sang màn "Đã gửi yêu cầu".
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await Future.wait(saveTasks.map((save) => save()));
      lichHenProvider.clearCache();
      for (final departmentId in _selectedDepartmentIds) {
        _reloadSlots(
          departmentId,
          _selectedRoomByDept[departmentId]!,
          _selectedDayByDept[departmentId]!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // đóng vòng xoay
      family.select(profile.id);

      final first = lichHenIds.first;
      final appointment = MyAppointmentItem(
        id: lichHenIds.length == 1
            ? '#$first'
            : '#$first (+${lichHenIds.length - 1})',
        hospitalName: tenBenhVien,
        subtitle:
            '${departmentNames.join(', ')} · $dateLabel · ${shiftLabels.join('; ')}',
        status: AppointmentStatus.pending,
        departmentName: departmentNames.join(', '),
        dateLabel: dateLabel,
        timeLabel: shiftLabels.join('; '),
      );
      Navigator.pushNamed(
        context,
        AppRoutes.bookingRequestSent,
        arguments: appointment,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // đóng vòng xoay
      context.showAppSnackBar(
        title: 'Đặt lịch thất bại',
        message: 'Lỗi khi đặt lịch: $e',
        type: SnackBarType.error,
      );
    }
  }

  // ───────────── Giao diện ─────────────

  @override
  Widget build(BuildContext context) {
    if (_hospitalData == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    final selectedIds = _selectedDepartmentIds.toList();
    final selectedNames = _departments
        .where(
          (d) =>
              _selectedDepartmentIds.contains(BookingHelper.departmentIdOf(d)),
        )
        .map((d) => d['ten_khoa']?.toString() ?? 'Chuyên khoa')
        .toList();

    // Chuyên khoa đang được cấu hình lịch (mặc định là chuyên khoa chọn đầu tiên).
    final activeId = selectedIds.contains(_activeDepartmentId)
        ? _activeDepartmentId
        : (selectedIds.isEmpty ? null : selectedIds.first);
    final selectedRoomId =
        activeId != null ? _selectedRoomByDept[activeId] : null;
    final selectedDay = activeId != null ? _selectedDayByDept[activeId] : null;
    final doneCount = selectedIds.where(_hasScheduleFor).length;

    // Dải ngày hiển thị; ngày chọn từ lịch tháng nằm ngoài dải thì được thêm vào.
    final today = BookingHelper.today();
    final days = selectedRoomId == null
        ? <Map<String, dynamic>>[]
        : BookingHelper.scheduleDays(today, AppTheme.soNgayHienThi);
    if (selectedDay != null &&
        days.isNotEmpty &&
        !days.any(
          (d) => BookingHelper.isSameDay(d['date'] as DateTime, selectedDay),
        )) {
      days.add(BookingHelper.dayEntry(selectedDay, today));
    }

    // Các ca khám của ngày đang chọn và ca đang được chọn.
    final lichHen = context.watch<LichHenProvider>();
    final slots =
        (activeId != null && selectedRoomId != null && selectedDay != null)
        ? lichHen.slotsOf(
            BookingHelper.slotKeyFor(
              departmentId: activeId,
              roomId: selectedRoomId,
              date: selectedDay,
              hospitalId: _hospitalId,
            ),
          )
        : <CaSlotModel>[];
    final selectedSlot = activeId == null
        ? null
        : slots
              .where((s) => s.caId == _selectedSlotByDept[activeId])
              .firstOrNull;

    final labelDate = selectedDay ?? today;
    final monthLabel =
        'Tháng ${labelDate.month.toString().padLeft(2, '0')}, ${labelDate.year}';

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Column(
        children: [
          _BookingHeader(
            hospitalName: _hospitalData?['ten_benh_vien']?.toString() ?? '',
            total: selectedIds.length,
            done: doneCount,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HospitalInfoCard(hospitalData: _hospitalData!),
                  const SizedBox(height: 14),
                  const BookingInfoBox(),
                  const SizedBox(height: 20),
                  Consumer<FamilyProfileProvider>(
                    builder: (_, fp, __) => ProfileChipsRow(
                      profiles: fp.profiles,
                      selectedId: _bookingProfileId ?? fp.currentId,
                      onSelected: (id) => setState(() => _bookingProfileId = id),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SpecialtySelectionSection(
                    selectedCount: _selectedDepartmentIds.length,
                    selectedNames: selectedNames,
                    isExpanded: _isSpecialtyExpanded,
                    isLoading: _isLoadingDepartments,
                    error: _departmentLoadError,
                    departments: _departments,
                    selectedDepartmentIds: _selectedDepartmentIds,
                    onToggleExpand: () => setState(
                      () => _isSpecialtyExpanded = !_isSpecialtyExpanded,
                    ),
                    onToggleDepartment: _toggleDepartment,
                  ),
                  const SizedBox(height: 28),
                  DateTimeSelectionSection(
                    selectedIds: selectedIds,
                    activeId: activeId,
                    selectedRoomId: selectedRoomId,
                    selectedDay: selectedDay,
                    doneCount: doneCount,
                    days: days,
                    lichHen: lichHen,
                    selectedSlot: selectedSlot,
                    monthLabel: monthLabel,
                    hospitalId: _hospitalId,
                    rooms: _roomsByDept[activeId] ?? [],
                    isLoadingRooms: _loadingRoomDepts.contains(activeId),
                    roomError: _roomErrorByDept[activeId],
                    hasSchedule: _hasScheduleFor,
                    onRetryFetch: _fetchRooms,
                    onRoomSelected: _selectRoom,
                    onDaySelected: _selectDay,
                    onOpenCalendar: _openMonthCalendar,
                    getDepartmentName: (id) =>
                        BookingHelper.departmentName(id, _departments),
                    getRoomName: (deptId, roomId) =>
                        BookingHelper.roomName(deptId, roomId, _roomsByDept),
                    formatDayMonth: BookingHelper.formatDayMonth,
                    getRoomMax: (deptId, roomId) =>
                        BookingHelper.roomMax(deptId, roomId, _roomsByDept),
                    onSlotSelected: (deptId, roomId, caId) =>
                        setState(() => _selectedSlotByDept[deptId] = caId),
                    onSwitchActiveDepartment: (id) =>
                        setState(() => _activeDepartmentId = id),
                  ),
                  const SizedBox(height: 28),
                  LocationSection(hospitalData: _hospitalData!),
                  const SizedBox(height: 28),
                  ReviewSection(
                    activeId: activeId,
                    selectedDepartmentIds: _selectedDepartmentIds,
                    hospitalId: _hospitalId,
                    getDepartmentName: (id) =>
                        BookingHelper.departmentName(id, _departments),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: BookingBottomActionArea(
              color: AppTheme.primaryBlue,
              onContinue: _continueBooking,
            ),
          ),
        ],
      ),
    );
  }
}

/// _BookingHeader: đầu trang gồm nút quay lại, tên bệnh viện và thanh tiến độ
/// "đã hoàn tất x/y chuyên khoa".
class _BookingHeader extends StatelessWidget {
  final String hospitalName;
  final int total;
  final int done;
  final VoidCallback onBack;

  const _BookingHeader({
    required this.hospitalName,
    required this.total,
    required this.done,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;
    final progressIcon = total == 0
        ? Icons.touch_app_rounded
        : (allDone ? Icons.check_circle_rounded : Icons.event_available_rounded);
    final progressText = total == 0
        ? 'Chọn người khám, chuyên khoa, phòng và giờ khám'
        : 'Đã hoàn tất $done/$total chuyên khoa';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đặt lịch khám',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (hospitalName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            hospitalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(progressIcon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            progressText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF7EE0C3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
