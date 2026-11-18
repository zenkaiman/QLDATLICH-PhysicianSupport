import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../models/appointment_item.dart';
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

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  bool _isSpecialtyExpanded = true;
  Map<String, dynamic>? _hospitalData;
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingDepartments = true;
  String? _departmentLoadError;
  final Set<String> _selectedDepartmentIds = {};

  String? _activeDepartmentId;
  final Map<String, String> _selectedRoomByDept = {};
  final Map<String, DateTime> _selectedDayByDept = {};
  final Map<String, String> _selectedSlotByDept = {};

  final HospitalService _hospitalService = HospitalService();
  final LichHenService _lichHenService = LichHenService();
  String _hospitalId = '';
  final Map<String, List<PhongKhamModel>> _roomsByDept = {};
  final Set<String> _loadingRoomDepts = {};
  final Map<String, String> _roomErrorByDept = {};

  String? _bookingProfileId;

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
    if (_hospitalData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _hospitalData = args;
        _hospitalId = (args['id'] ?? args['ma_benh_vien'] ?? '').toString();
        _fetchDepartments(_hospitalId);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    }
  }

  /// _fetchDepartments: tải danh sách chuyên khoa của bệnh viện.
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

  /// _toggleDepartment: chọn hoặc bỏ chọn một chuyên khoa.
  void _toggleDepartment(String departmentId) {
    setState(() {
      if (_selectedDepartmentIds.contains(departmentId)) {
        _selectedDepartmentIds.remove(departmentId);
        _selectedRoomByDept.remove(departmentId);
        _selectedDayByDept.remove(departmentId);
        _selectedSlotByDept.remove(departmentId);
        _activeDepartmentId = _selectedDepartmentIds.isEmpty
            ? null
            : _selectedDepartmentIds.last;
      } else {
        _selectedDepartmentIds.add(departmentId);
        _activeDepartmentId = departmentId;
      }
    });
    if (_selectedDepartmentIds.contains(departmentId)) {
      _fetchRooms(departmentId);
    }
  }

  /// _hasScheduleFor: kiểm tra chuyên khoa đã chọn đủ phòng, ngày, giờ chưa.
  bool _hasScheduleFor(String id) =>
      _selectedRoomByDept.containsKey(id) &&
      _selectedDayByDept.containsKey(id) &&
      _selectedSlotByDept.containsKey(id);

  bool get _isScheduleComplete =>
      _selectedDepartmentIds.isNotEmpty &&
      _selectedDepartmentIds.every(_hasScheduleFor);

  /// _fetchRooms: tải danh sách phòng khám của một chuyên khoa.
  Future<void> _fetchRooms(String departmentId, {bool force = false}) async {
    if (_hospitalId.isEmpty ||
        (!force &&
            (_roomsByDept.containsKey(departmentId) ||
                _loadingRoomDepts.contains(departmentId)))) {
      return;
    }
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

  /// _selectRoom: chọn phòng khám và xóa ngày, giờ đã chọn trước đó.
  void _selectRoom(String departmentId, String roomId) {
    setState(() {
      if (_selectedRoomByDept[departmentId] != roomId) {
        _selectedRoomByDept[departmentId] = roomId;
        _selectedDayByDept.remove(departmentId);
        _selectedSlotByDept.remove(departmentId);
      }
    });
  }

  /// _selectDay: chọn ngày khám và nạp lại số chỗ còn trống của các ca.
  void _selectDay(String departmentId, String roomId, DateTime date) {
    setState(() {
      final current = _selectedDayByDept[departmentId];
      if (current == null || !BookingHelper.isSameDay(current, date)) {
        _selectedDayByDept[departmentId] = date;
        _selectedSlotByDept.remove(departmentId);
      }
    });
    context.read<LichHenProvider>().loadSlots(
      ngay: date,
      benhVienId: _hospitalId,
      khoaId: departmentId,
      phongKhamId: roomId,
      soBenhNhanToiDa: BookingHelper.roomMax(
        departmentId,
        roomId,
        _roomsByDept,
      ),
      force: true,
    );
  }

  /// _openMonthCalendar: mở lịch tháng để chọn ngày khám.
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

  /// _continueBooking: kiểm tra dữ liệu, xác nhận rồi lưu các lịch hẹn đã chọn.
  Future<void> _continueBooking() async {
    if (_selectedDepartmentIds.isEmpty) {
      context.showAppSnackBar(
        title: 'Chưa chọn chuyên khoa',
        message: 'Vui lòng chọn chuyên khoa khám',
        type: SnackBarType.warning,
      );
      return;
    }

    final family = context.read<FamilyProfileProvider>();
    final profile = family.byId(_bookingProfileId ?? family.currentId);
    if (profile == null) {
      context.showAppSnackBar(
        title: 'Chưa chọn người khám',
        message: 'Vui lòng chọn khám cho ai',
        type: SnackBarType.warning,
      );
      return;
    }

    if (!_isScheduleComplete) {
      context.showAppSnackBar(
        title: 'Chưa hoàn tất thông tin lịch khám',
        message:
            'Vui lòng chọn phòng khám, ngày và khung giờ cho tất cả chuyên khoa đã chọn',
        type: SnackBarType.warning,
      );
      return;
    }

    final lichHenProvider = context.read<LichHenProvider>();
    final String benhNhanId =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    const String trangThaiId = '1';
    final tenNguoiDat = context.read<AuthProvider>().user?.hoTen;
    final String tenBenhVien =
        _hospitalData?['ten_benh_vien']?.toString() ??
        'Bệnh viện không xác định';

    for (final departmentId in _selectedDepartmentIds) {
      final date = _selectedDayByDept[departmentId]!;

      final hasConflict = await _lichHenService.checkExistingBooking(
        benhNhanId: benhNhanId,
        benhVienId: _hospitalId,
        khoaId: departmentId,
        ngayDat: date,
        profileId: profile.id,
      );

      if (!mounted) return;

      if (hasConflict) {
        final tenKhoa = BookingHelper.departmentName(
          departmentId,
          _departments,
        );
        context.showAppSnackBar(
          title: 'Lịch khám bị trùng',
          message:
              '${profile.isSelf ? 'Bạn' : profile.hoTen} đã có lịch khám tại khoa $tenKhoa vào ngày ${BookingHelper.formatDayMonth(date)}. Vui lòng chọn ngày khác hoặc hủy lịch cũ.',
          type: SnackBarType.error,
        );
        return;
      }
    }

    final List<Map<String, String>> bookingDetails = [];
    final List<Future<void> Function()> saveTasks = [];
    final List<String> departmentNames = [];
    final List<String> dateLabels = [];
    final List<String> shiftLabels = [];
    final List<String> lichHenIds = [];

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

      CaSlotModel? selectedSlot;
      for (final slot in lichHenProvider.slotsOf(slotKey)) {
        if (slot.caId == caId) {
          selectedSlot = slot;
          break;
        }
      }

      if (selectedSlot == null) {
        context.showAppSnackBar(
          title: 'Không tìm thấy khung giờ',
          message: 'Không tìm thấy khung giờ đã chọn. Vui lòng chọn lại.',
          type: SnackBarType.warning,
        );
        return;
      }

      final String tenKhoa = BookingHelper.departmentName(
        departmentId,
        _departments,
      );
      String tenPhongKham = 'Phòng khám';
      final rooms = _roomsByDept[departmentId] ?? [];
      final selectedRoom = rooms.where((r) => r.id == roomId).firstOrNull;

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
            context.showAppSnackBar(
              title: 'Ca khám đã hết chỗ',
              message:
                  '${selectedSlot.tenCa} ngày ${BookingHelper.formatDayMonth(date)} tại khoa $tenKhoa đã đủ số lượng. Vui lòng chọn ca hoặc ngày khác.',
              type: SnackBarType.warning,
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
          trangThaiId: trangThaiId,
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

    final hospitalName = tenBenhVien;
    final address =
        _hospitalData!['dia_chi']?.toString() ?? 'Địa chỉ chưa cập nhật';
    final bhyt = (_hospitalData!['bhyt'] ?? _hospitalData!['bhyt_id'] ?? '')
        .toString()
        .toLowerCase();
    final bhytNote = (bhyt == 'co_bhyt' || bhyt == 'có bhyt')
        ? 'Có hỗ trợ khám BHYT'
        : 'Không hỗ trợ khám BHYT';
    final dateLabel = dateLabels.toSet().join(', ');

    final confirmed = await showBookingConfirmSheet(
      context,
      hospitalName: hospitalName,
      bookingDetails: bookingDetails,
      dateLabel: dateLabel,
      address: address,
      bhytNote: bhytNote,
      patientName: profile.isSelf
          ? profile.hoTen
          : '${profile.quanHe} - ${profile.hoTen}',
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await Future.wait(saveTasks.map((saveTask) => saveTask()));
        lichHenProvider.clearCache();

        for (final departmentId in _selectedDepartmentIds) {
          final roomId = _selectedRoomByDept[departmentId]!;
          lichHenProvider.loadSlots(
            ngay: _selectedDayByDept[departmentId]!,
            benhVienId: _hospitalId,
            khoaId: departmentId,
            phongKhamId: roomId,
            soBenhNhanToiDa: BookingHelper.roomMax(
              departmentId,
              roomId,
              _roomsByDept,
            ),
            force: true,
          );
        }

        if (!mounted) return;
        Navigator.pop(context);

        final departmentLabel = departmentNames.join(', ');
        final shiftLabel = shiftLabels.join('; ');
        family.select(profile.id);
        final appointment = MyAppointmentItem(
          id: lichHenIds.length == 1
              ? '#${lichHenIds.first}'
              : '#${lichHenIds.first} (+${lichHenIds.length - 1})',
          hospitalName: hospitalName,
          subtitle: '$departmentLabel · $dateLabel · $shiftLabel',
          status: AppointmentStatus.pending,
          departmentName: departmentLabel,
          dateLabel: dateLabel,
          timeLabel: shiftLabel,
        );

        Navigator.pushNamed(
          context,
          AppRoutes.bookingRequestSent,
          arguments: appointment,
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        context.showAppSnackBar(
          title: 'Đặt lịch thất bại',
          message: 'Lỗi khi đặt lịch: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hospitalData == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    final selectedNames = _departments
        .where(
          (d) =>
              _selectedDepartmentIds.contains(BookingHelper.departmentIdOf(d)),
        )
        .map((d) => d['ten_khoa']?.toString() ?? 'Chuyên khoa')
        .toList();
    final selectedIds = _selectedDepartmentIds.toList();
    final String? activeId = selectedIds.contains(_activeDepartmentId)
        ? _activeDepartmentId
        : (selectedIds.isEmpty ? null : selectedIds.first);

    final selectedRoomId = activeId != null
        ? _selectedRoomByDept[activeId]
        : null;
    final DateTime? selectedDay = activeId != null
        ? _selectedDayByDept[activeId]
        : null;
    final doneCount = selectedIds.where(_hasScheduleFor).length;

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

    final lichHen = context.watch<LichHenProvider>();
    final List<CaSlotModel> slots =
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

    CaSlotModel? selectedSlot;
    if (activeId != null) {
      for (final sl in slots) {
        if (sl.caId == _selectedSlotByDept[activeId]) {
          selectedSlot = sl;
          break;
        }
      }
    }

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
                      onSelected: (id) =>
                          setState(() => _bookingProfileId = id),
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

/// _BookingHeader: đầu trang có tên bệnh viện và tiến độ chọn lịch của các chuyên khoa.
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
                        Icon(
                          total == 0
                              ? Icons.touch_app_rounded
                              : (allDone
                                    ? Icons.check_circle_rounded
                                    : Icons.event_available_rounded),
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            total == 0
                                ? 'Chọn người khám, chuyên khoa, phòng và giờ khám'
                                : 'Đã hoàn tất $done/$total chuyên khoa',
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