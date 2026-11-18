import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../config/app_routes.dart';
import '../../models/appointment_item.dart';
import '../../models/lichhen_model.dart';
import '../../providers/lich_hen_provider.dart';
import '../../services/hospital_service.dart';
import '../../services/lichhen_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/queue_time_estimator.dart';
import '../../widgets/patient_widget/appointment_detail_widget.dart';
import '../../widgets/patient_widget/appointment_ticket_widget.dart';
import '../../widgets/patient_widget/book_appointment_widget.dart'
    show AppTheme;

/// _outOfQueueStatuses: các trạng thái không còn nằm trong hàng chờ khám.
const Set<String> _outOfQueueStatuses = {'3', '4', '5', '6', '7'};

/// AppointmentDetailScreen: màn hình chi tiết lịch khám, gồm trạng thái, số thứ tự và thời gian chờ ước tính.
class AppointmentDetailScreen extends StatefulWidget {
  final MyAppointmentItem appointment;
  final String? currentQueue;
  final String? estimatedMinutes;
  final String? benhNhanId;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.currentQueue,
    this.estimatedMinutes,
    this.benhNhanId,
  });

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final LichHenService _lichHenService = LichHenService();
  final HospitalService _hospitalService = HospitalService();
  final QueueTimeEstimator _queueTimeEstimator = QueueTimeEstimator();

  late Future<Map<String, dynamic>?> _detailsFuture;
  StreamSubscription<List<LichHenModel>>? _queueSubscription;
  List<LichHenModel> _queue = [];
  int? _thoiGianKham;
  String _waitLabel = 'Đang tính...';

  @override
  void initState() {
    super.initState();
    _detailsFuture = _loadDetails();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  String get _benhNhanId =>
      widget.benhNhanId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _cleanId =>
      widget.appointment.id.replaceFirst('#', '').split(' ').first;

  /// _fetchAppointmentDetails: lấy chi tiết lịch hẹn mới nhất từ Firestore theo mã lịch.
  Future<Map<String, dynamic>?> _fetchAppointmentDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('LichHen')
          .where('id', isEqualTo: _cleanId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.data();

      final docSnapshot = await FirebaseFirestore.instance
          .collection('LichHen')
          .doc(_cleanId)
          .get();
      if (docSnapshot.exists) return docSnapshot.data();

      return null;
    } catch (e) {
      debugPrint('Lỗi khi lấy chi tiết lịch hẹn: $e');
      return null;
    }
  }

  /// _loadDetails: tải chi tiết lịch hẹn và bắt đầu theo dõi hàng chờ nếu lịch đã được duyệt.
  Future<Map<String, dynamic>?> _loadDetails() async {
    final data = await _fetchAppointmentDetails();
    if (data != null &&
        mounted &&
        widget.appointment.status == AppointmentStatus.approved) {
      _listenQueue(data);
    }
    return data;
  }

  /// _listenQueue: lắng nghe hàng chờ của phòng khám và lấy thời gian khám của phòng để tính thời gian chờ.
  void _listenQueue(Map<String, dynamic> data) {
    final booking = LichHenModel.fromJson(data, id: _cleanId);
    if (booking.phongKhamId.isEmpty || booking.ngayDat == null) {
      _setWaitLabel('Chưa xác định');
      return;
    }

    _queueSubscription?.cancel();
    _queueTimeEstimator.reset();
    _thoiGianKham = null;
    _queue = [];

    _hospitalService
        .getThoiGianKhamPhong(
          hospitalId: booking.benhVienId,
          khoaId: booking.khoaId,
          phongKhamId: booking.phongKhamId,
        )
        .then((minutes) {
          if (!mounted) return;
          _thoiGianKham = minutes;
          _recalculateWait();
        });

    _queueSubscription = _lichHenService
        .listenToQueue(
          ngay: booking.ngayDat!,
          benhVienId: booking.benhVienId,
          khoaId: booking.khoaId,
          phongKhamId: booking.phongKhamId,
        )
        .listen(
          (queue) {
            _queue = queue;
            _recalculateWait();
          },
          onError: (e) {
            debugPrint('Lỗi khi lắng nghe hàng chờ: $e');
            _setWaitLabel('Chưa xác định');
          },
        );
  }

  /// _recalculateWait: tính lại thời gian chờ theo cùng công thức với màn theo dõi lịch khám.
  void _recalculateWait() {
    final waiting = _queue
        .where((b) => !_outOfQueueStatuses.contains(b.trangThaiId.toString()))
        .toList();
    final myIndex = waiting.indexWhere((b) => b.id == _cleanId);

    if (myIndex == -1) {
      _setWaitLabel('Chưa xác định');
      return;
    }

    final currentServing = waiting.first.soThuTu;
    final estimator = _queueTimeEstimator.update(currentServing);
    final perPatient = _thoiGianKham ?? estimator.perPatient;
    final waitMinutes = _queueTimeEstimator.waitMinutes(myIndex, perPatient);
    _setWaitLabel('~$waitMinutes phút');
  }

  /// _setWaitLabel: cập nhật nội dung thời gian chờ hiển thị trên màn hình.
  void _setWaitLabel(String label) {
    if (!mounted) return;
    setState(() => _waitLabel = label);
  }

  /// _refresh: tải lại chi tiết lịch hẹn và hàng chờ.
  void _refresh() {
    setState(() {
      _waitLabel = 'Đang tính...';
      _detailsFuture = _loadDetails();
    });
    context.showAppSnackBar(
      title: 'Đang cập nhật lịch hẹn',
      message: 'Đang cập nhật số thứ tự mới nhất...',
      duration: const Duration(seconds: 1),
    );
  }

  /// _openTicket: dựng vé khám điện tử từ dữ liệu lịch hẹn rồi mở bảng xem trước và chia sẻ.
  void _openTicket(Map<String, dynamic> data) {
    final appointment = widget.appointment;
    final queue = int.tryParse(data['so_thu_tu']?.toString() ?? '') ?? 0;
    final patient = (data['ten_nguoi_kham'] ?? data['tenNguoiKham'] ?? '')
        .toString();
    final qr = (data['ma_qr'] ?? data['maQr'] ?? '').toString();

    showAppointmentTicketSheet(
      context,
      hospitalName: appointment.hospitalName,
      patientName: patient.isEmpty ? 'Người bệnh' : patient,
      departmentName: appointment.departmentName,
      dateLabel: appointment.dateLabel,
      timeLabel: appointment.timeLabel,
      appointmentId: _cleanId,
      qrData: qr.isEmpty ? _cleanId : qr,
      queueNumber: queue,
    );
  }

  /// _goToBooking: quay về trang chính để đặt lịch mới.
  void _goToBooking() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.patientMain,
      (route) => route.isFirst,
    );
  }

  /// _cancelAppointment: hủy lịch hẹn, báo kết quả rồi quay lại màn hình trước.
  Future<void> _cancelAppointment(BuildContext context) async {
    final provider = context.read<LichHenProvider>();
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await provider.huyLichHen(
        benhNhanId: _benhNhanId,
        lichHenId: widget.appointment.id,
      );

      if (!navigator.canPop()) return;
      navigator.pop();

      if (!context.mounted) return;
      context.showAppSnackBar(
        title: 'Hủy lịch thành công',
        message: 'Đã hủy lịch khám thành công',
        type: SnackBarType.success,
      );

      if (navigator.canPop()) navigator.pop(true);
    } catch (e) {
      if (!navigator.canPop()) return;
      navigator.pop();

      if (!context.mounted) return;
      context.showAppSnackBar(
        title: 'Hủy lịch thất bại',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  /// _deleteAppointment: xóa lịch đã hủy khỏi danh sách rồi quay lại màn hình trước.
  Future<void> _deleteAppointment(BuildContext context) async {
    final provider = context.read<LichHenProvider>();
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await provider.xoaLichHen(
        benhNhanId: _benhNhanId,
        lichHenId: widget.appointment.id,
      );
      navigator.pop();
      if (!context.mounted) return;
      context.showAppSnackBar(
        title: 'Xóa lịch thành công',
        message: 'Đã xóa lịch khám',
        type: SnackBarType.success,
      );
      navigator.pop();
    } catch (e) {
      navigator.pop();
      if (!context.mounted) return;
      context.showAppSnackBar(
        title: 'Xóa lịch thất bại',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackBarType.error,
      );
    }
  }

  /// _showCancelDialog: hiện hộp thoại xác nhận hủy lịch khám.
  void _showCancelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmActionDialog(
        icon: Icons.event_busy_rounded,
        title: 'Hủy lịch khám?',
        message: 'Bạn có chắc chắn muốn hủy lịch khám này không?',
        warning: 'Hành động này không thể hoàn tác.',
        keepLabel: 'Giữ lịch',
        confirmLabel: 'Hủy lịch',
        confirmIcon: Icons.close_rounded,
        appointment: widget.appointment,
        onConfirm: () => _cancelAppointment(context),
      ),
    );
  }

  /// _showDeleteDialog: hiện hộp thoại xác nhận xóa lịch khám đã hủy.
  void _showDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmActionDialog(
        icon: Icons.delete_forever_rounded,
        title: 'Xóa lịch khám?',
        message: 'Lịch khám đã hủy này sẽ bị xóa khỏi danh sách của bạn.',
        warning: 'Dữ liệu bị xóa vĩnh viễn và không thể khôi phục.',
        keepLabel: 'Giữ lại',
        confirmLabel: 'Xóa',
        confirmIcon: Icons.delete_outline_rounded,
        appointment: widget.appointment,
        onConfirm: () => _deleteAppointment(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.appointment.status;
    final isCancelled = status == AppointmentStatus.cancelled;
    final isPending = status == AppointmentStatus.pending;
    final isApproved = status == AppointmentStatus.approved;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const AppointmentDetailHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppointmentStatusHero(
                      isPending: isPending,
                      isApproved: isApproved,
                      isCancelled: isCancelled,
                    ),
                    const SizedBox(height: 14),
                    AppointmentInfoCard(
                      appointment: widget.appointment,
                      status: status,
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 14),
                      AppointmentPendingSection(
                        onCancel: () => _showCancelDialog(context),
                      ),
                    ],
                    if (isApproved) ...[
                      const SizedBox(height: 14),
                      AppointmentApprovedSection(
                        detailsFuture: _detailsFuture,
                        waitLabel: _waitLabel,
                        onRefresh: _refresh,
                        onTrack: () => Navigator.pushNamed(
                          context,
                          AppRoutes.appointmentTracking,
                          arguments: widget.appointment,
                        ),
                        onShareTicket: _openTicket,
                      ),
                    ],
                    if (isCancelled) ...[
                      const SizedBox(height: 14),
                      AppointmentCancelledSection(
                        onGoToBooking: _goToBooking,
                        onDelete: () => _showDeleteDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}