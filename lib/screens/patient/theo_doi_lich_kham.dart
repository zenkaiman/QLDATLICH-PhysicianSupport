import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_routes.dart';
import '../../providers/family_profile_provider.dart';
import '../../providers/lich_hen_provider.dart';
import '../../models/lichhen_model.dart';
import '../../models/appointment_item.dart';
import '../../utils/queue_time_estimator.dart';
import '../../services/hospital_service.dart';
import '../../services/khoa_service.dart';
import '../../providers/khoa_provider.dart';
import '../../widgets/family_widgets.dart';

/// AppColors: bảng màu dùng chung cho màn hình theo dõi lịch khám.
class AppColors {
  static const background = Color(0xFFF2F6F8);
  static const surface = Colors.white;
  static const primary = Color(0xFF0B5CAD);
  static const primaryDark = Color(0xFF083D75);
  static const teal = Color(0xFF12A594);
  static const tealDark = Color(0xFF0B7A6C);
  static const ink = Color(0xFF14232F);
  static const muted = Color(0xFF6B7C89);
  static const line = Color(0xFFDCE5EB);
  static const warnBg = Color(0xFFFFF5E1);
  static const warnBorder = Color(0xFFF2C46D);
  static const warnText = Color(0xFF8A5A00);
  static const danger = Color(0xFFD64545);

  static const late = Color(0xFFF97316);
  static const lateDark = Color(0xFF9A3412);
  static const lateBg = Color(0xFFFFF3E0);
  static const lateBorder = Color(0xFFFED7AA);

  static const closed = Color(0xFF475569);
  static const closedBg = Color(0xFFEEF1F4);
}

/// _font: tạo TextStyle với font Be Vietnam Pro.
TextStyle _font(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
}) => GoogleFonts.beVietnamPro(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// _trackableStatuses: các trạng thái được hiển thị ở màn theo dõi (1, 2, 5, 6, 7).
const Set<String> _trackableStatuses = {'1', '2', '5', '6', '7'};

/// _outOfQueueStatuses: các trạng thái không còn nằm trong hàng chờ khám.
const Set<String> _outOfQueueStatuses = {'3', '4', '5', '6', '7'};

/// _statusIcon: trả về biểu tượng tương ứng với trạng thái lịch hẹn.
IconData _statusIcon(AppointmentStatus s) {
  switch (s) {
    case AppointmentStatus.pending:
      return Icons.hourglass_empty_rounded;
    case AppointmentStatus.approved:
      return Icons.verified_rounded;
    case AppointmentStatus.cancelled:
      return Icons.cancel_rounded;
    case AppointmentStatus.completed:
      return Icons.check_circle_rounded;
    case AppointmentStatus.missed:
      return Icons.person_off_rounded;
    case AppointmentStatus.late:
      return Icons.schedule_rounded;
  }
}

/// ClinicApp: ứng dụng mẫu để chạy riêng màn hình theo dõi lịch khám.
class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Theo dõi lịch khám',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const AppointmentTrackingScreen(),
    );
  }
}

/// AppointmentTrackingScreen: màn hình theo dõi số thứ tự và thời gian chờ theo thời gian thực.
class AppointmentTrackingScreen extends StatefulWidget {
  final String? bookingId;

  const AppointmentTrackingScreen({super.key, this.bookingId});

  @override
  State<AppointmentTrackingScreen> createState() =>
      _AppointmentTrackingScreenState();
}

class _AppointmentTrackingScreenState extends State<AppointmentTrackingScreen> {
  late final LichHenProvider _provider;
  late final KhoaProvider _khoaProvider;
  final QueueTimeEstimator _queueTimeEstimator = QueueTimeEstimator();
  final HospitalService _hospitalService = HospitalService();
  int? _thoiGianKham;
  Timer? _queueEstimateTimer;

  String? _listeningKey;
  String? _selectedId;
  bool _argsRead = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<LichHenProvider>();
    _khoaProvider = context.read<KhoaProvider>();
    _queueEstimateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBookings();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;

    _selectedId = widget.bookingId;
    if (_selectedId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _selectedId = args;
      } else if (args is LichHenModel) {
        _selectedId = args.id;
      } else if (args is MyAppointmentItem) {
        _selectedId = args.id;
      }
    }
  }

  @override
  void dispose() {
    _queueEstimateTimer?.cancel();
    final provider = _provider;
    Future.microtask(provider.stopListeningQueue);
    final khoaProvider = _khoaProvider;
    Future.microtask(khoaProvider.stopListeningPhong);
    super.dispose();
  }

  /// _loadBookings: tải danh sách lịch hẹn của người dùng đang đăng nhập.
  Future<void> _loadBookings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await _provider.loadMyBookings(userId);
    }
  }

  /// _ensureListening: bắt đầu lắng nghe hàng chờ và trạng thái phòng khám của lịch hẹn (mỗi lịch chỉ một lần).
  void _ensureListening(LichHenModel booking) {
    // Bước 1: bỏ qua nếu thiếu phòng khám, ngày khám hoặc đang lắng nghe đúng lịch này.
    if (booking.phongKhamId.isEmpty || booking.ngayDat == null) return;

    final key =
        '${booking.id}|${booking.benhVienId}|${booking.khoaId}|${booking.phongKhamId}|${booking.ngayDat}';
    if (_listeningKey == key) return;
    _listeningKey = key;
    _queueTimeEstimator.reset();
    _thoiGianKham = null;

    // Bước 2: lấy thời gian khám mỗi bệnh nhân của phòng.
    _hospitalService
        .getThoiGianKhamPhong(
          hospitalId: booking.benhVienId,
          khoaId: booking.khoaId,
          phongKhamId: booking.phongKhamId,
        )
        .then((minutes) {
          if (!mounted || _listeningKey != key) return;
          setState(() => _thoiGianKham = minutes);
        });

    // Bước 3: sau khung hình hiện tại, bắt đầu lắng nghe hàng chờ và trạng thái phòng khám.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider.startListeningQueue(
        ngay: booking.ngayDat!,
        benhVienId: booking.benhVienId,
        khoaId: booking.khoaId,
        phongKhamId: booking.phongKhamId,
      );
      _khoaProvider.startListeningPhong(
        benhVienId: booking.benhVienId,
        khoaId: booking.khoaId,
        phongKhamId: booking.phongKhamId,
      );
    });
  }

  /// _atTime: ghép giờ "HH:mm" với một ngày cụ thể.
  DateTime? _atTime(DateTime day, String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0].trim());
    final m = int.tryParse(p[1].trim());
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// _hhmm: định dạng thời gian thành "HH:mm".
  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// _estimateTurn: tính giờ dự kiến đến lượt từ giờ ca khám, số phút chờ và số phút phòng đã tạm dừng.
  ({DateTime eta, bool exceeds, bool shiftNotStarted}) _estimateTurn({
    required DateTime ngayKham,
    required String? gioBatDau,
    required String? gioKetThuc,
    required int waitMinutes,
    required int pauseMinutes,
  }) {
    // Bước 1: xác định giờ bắt đầu, giờ kết thúc ca và mốc tính (giờ bắt đầu nếu ca chưa mở, ngược lại là hiện tại).
    final now = DateTime.now();
    final start = _atTime(ngayKham, gioBatDau);
    final end = _atTime(ngayKham, gioKetThuc);

    final notStarted = start != null && now.isBefore(start);
    final base = notStarted ? start : now;

    // Bước 2: cộng số phút chờ và số phút tạm dừng để ra giờ dự kiến.
    final eta = base.add(Duration(minutes: waitMinutes + pauseMinutes));

    // Bước 3: kiểm tra giờ dự kiến có vượt quá giờ kết thúc ca không.
    final exceeds = end != null && eta.isAfter(end);

    return (eta: eta, exceeds: exceeds, shiftNotStarted: notStarted);
  }

  /// _appBar: thanh tiêu đề của màn hình.
  PreferredSizeWidget _appBar(BuildContext context) => AppBar(
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    leading: Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theo dõi lịch khám', style: _font(19, weight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(
          'Số thứ tự cập nhật theo thời gian thực',
          style: _font(12, color: AppColors.muted),
        ),
      ],
    ),
  );

  /// _formatDate: định dạng ngày thành "dd/MM/yyyy".
  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  /// _statusPriority: độ ưu tiên sắp xếp của trạng thái (số nhỏ hiển thị trước).
  int _statusPriority(String s) {
    switch (s) {
      case '2':
        return 0;
      case '7':
        return 1;
      case '1':
        return 2;
      case '5':
        return 3;
      default:
        return 4;
    }
  }

  /// _compareBookings: sắp xếp lịch còn hiệu lực lên trước, sau đó theo ngày rồi theo độ ưu tiên trạng thái.
  int _compareBookings(LichHenModel a, LichHenModel b) {
    final sa = a.trangThaiId.toString();
    final sb = b.trangThaiId.toString();
    final finishedA = sa == '5' || sa == '6';
    final finishedB = sb == '5' || sb == '6';
    if (finishedA != finishedB) return finishedA ? 1 : -1;

    final byDate = a.ngayDat!.compareTo(b.ngayDat!);
    if (byDate != 0) return byDate;
    return _statusPriority(sa).compareTo(_statusPriority(sb));
  }

  @override
  Widget build(BuildContext context) {
    // Bước 1: lấy dữ liệu từ các provider và lọc các lịch hẹn sắp tới.
    final provider = context.watch<LichHenProvider>();
    final khoaProvider = context.watch<KhoaProvider>();
    final family = context.watch<FamilyProfileProvider>();
    final profile = family.current;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final upcomingBookings = provider.activeBookingsOf(profile?.id).where((b) {
      return _trackableStatuses.contains(b.trangThaiId.toString()) &&
          b.ngayDat != null &&
          !b.ngayDat!.isBefore(startOfDay);
    }).toList()..sort(_compareBookings);

    // Bước 2: hiển thị màn hình đang tải, lỗi hoặc không có lịch nếu cần.
    if (provider.isLoadingMyBookings && upcomingBookings.isEmpty) {
      return Scaffold(
        appBar: _appBar(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Đang tải lịch khám...',
                style: _font(14, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.myBookingsError != null && upcomingBookings.isEmpty) {
      return Scaffold(
        appBar: _appBar(context),
        body: _StateView(
          icon: Icons.cloud_off_rounded,
          color: AppColors.danger,
          title: 'Không tải được lịch khám',
          message: provider.myBookingsError!,
          actionLabel: 'Thử lại',
          actionIcon: Icons.refresh_rounded,
          onAction: _loadBookings,
        ),
      );
    }

    if (upcomingBookings.isEmpty) {
      return Scaffold(
        appBar: _appBar(context),
        body: _StateView(
          icon: Icons.event_busy_rounded,
          color: AppColors.primary,
          title: 'Không có lịch khám nào sắp tới',
          message: 'Hãy đặt lịch khám để theo dõi số thứ tự tại đây.',
          actionLabel: 'Đặt lịch khám',
          actionIcon: Icons.add_rounded,
          onAction: () =>
              Navigator.pushNamed(context, AppRoutes.hospitalFilter),
        ),
      );
    }

    // Bước 3: chọn lịch cần theo dõi và bắt đầu lắng nghe nếu lịch đã xác nhận hoặc đến trễ.
    var booking = upcomingBookings.first;
    if (_selectedId != null) {
      final matches = upcomingBookings.where((b) => b.id == _selectedId);
      if (matches.isNotEmpty) booking = matches.first;
    }
    final status = statusFromTrangThaiId(booking.trangThaiId);
    final isTracking =
        status == AppointmentStatus.approved ||
        status == AppointmentStatus.late;

    if (isTracking) {
      _ensureListening(booking);
    }

    // Bước 4: lấy trạng thái phòng khám (chỉ áp dụng khi lịch đang được theo dõi).
    final room = isTracking
        ? khoaProvider.phongTrangThai
        : PhongKhamTrangThai.macDinh;
    final roomClosed = room.trangThai == TrangThaiPhong.dongCua;

    // Bước 5: chuẩn bị nội dung hiển thị của lịch hẹn.
    final department = booking.tenKhoa ?? 'Khoa chưa cập nhật';
    final roomName = booking.tenPhongKham ?? 'Phòng khám chưa cập nhật';
    final hospital = booking.tenBenhVien ?? 'Bệnh viện';
    final dateLabel = _formatDate(booking.ngayDat!);
    final hasTime = booking.gioBatDau != null && booking.gioKetThuc != null;
    final timeLabel = hasTime
        ? '${booking.gioBatDau} - ${booking.gioKetThuc}'
        : 'Chưa có giờ khám';

    final List<LichHenModel> queue = provider.activeQueue
        .where((b) => !_outOfQueueStatuses.contains(b.trangThaiId.toString()))
        .toList();

    final showPrep =
        (status == AppointmentStatus.pending ||
            status == AppointmentStatus.approved ||
            status == AppointmentStatus.late) &&
        !roomClosed;

    // Bước 6: dựng danh sách widget của màn hình.
    final children = <Widget>[
      if (profile != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person_pin_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.isSelf
                      ? 'Đang theo dõi cho: Tôi'
                      : 'Đang theo dõi cho: ${profile.quanHe} - ${profile.hoTen}',
                  style: _font(
                    13,
                    weight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showProfileSwitcherSheet(context),
                child: const Text('Đổi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (upcomingBookings.length > 1) ...[
        _BookingSelector(
          bookings: upcomingBookings,
          selectedId: booking.id,
          onSelect: (id) => setState(() => _selectedId = id),
        ),
        const SizedBox(height: 14),
      ],
      _HospitalInfoCard(
        hospital: hospital,
        department: department,
        room: roomName,
        date: dateLabel,
        time: timeLabel,
        status: status,
        roomStatus: isTracking && khoaProvider.phongLoaded
            ? room.trangThai
            : null,
      ),
      const SizedBox(height: 16),
      ..._statusSection(
        provider: provider,
        booking: booking,
        status: status,
        queue: queue,
        timeLabel: timeLabel,
        room: room,
      ),
      if (showPrep) ...const [
        SizedBox(height: 24),
        _PrepareChecklist(),
        SizedBox(height: 14),
        _ImportantNotice(),
      ],
    ];

    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadBookings,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: children,
          ),
        ),
      ),
    );
  }

  /// _statusSection: dựng phần nội dung thay đổi theo trạng thái của lịch hẹn và trạng thái phòng khám.
  List<Widget> _statusSection({
    required LichHenProvider provider,
    required LichHenModel booking,
    required AppointmentStatus status,
    required List<LichHenModel> queue,
    required String timeLabel,
    required PhongKhamTrangThai room,
  }) {
    final currentServing = queue.isNotEmpty ? queue.first.soThuTu : 0;
    final paused = room.trangThai == TrangThaiPhong.tamDung;
    final closed = room.trangThai == TrangThaiPhong.dongCua;

    switch (status) {
      case AppointmentStatus.pending:
        return const [
          _StatusMessageCard(
            icon: Icons.hourglass_empty_rounded,
            color: AppColors.primary,
            title: 'Lịch hẹn đang chờ duyệt',
            message:
                'Bệnh viện sẽ xem xét và xác nhận lịch hẹn của bạn. '
                'Bạn sẽ nhận được thông báo khi lịch được duyệt.',
          ),
        ];

      case AppointmentStatus.cancelled:
        return const [
          _StatusMessageCard(
            icon: Icons.cancel_rounded,
            color: AppColors.danger,
            title: 'Lịch hẹn đã bị hủy',
            message: 'Bạn có thể đặt lại lịch khám mới bất cứ lúc nào.',
          ),
        ];

      case AppointmentStatus.completed:
        return const [_CompletedCard()];

      case AppointmentStatus.missed:
        return const [
          _StatusMessageCard(
            icon: Icons.person_off_rounded,
            color: AppColors.muted,
            title: 'Bạn đã vắng mặt',
            message:
                'Lịch khám này được ghi nhận là vắng mặt. '
                'Bạn có thể đặt lại lịch khám khi cần.',
          ),
        ];

      case AppointmentStatus.late:
        if (closed) return const [_RoomClosedCard()];
        return [
          if (paused) ...[
            _RoomPausedCard(minutes: room.phutDangTamDung(DateTime.now())),
            const SizedBox(height: 16),
          ],
          _LockedSection(
            locked: paused,
            child: _NowServingCard(number: currentServing),
          ),
          const SizedBox(height: 16),
          _LateTicketCard(number: booking.soThuTu),
          const SizedBox(height: 16),
          const _LateSteps(),
          const SizedBox(height: 16),
          const _LateEstimateCard(),
        ];

      case AppointmentStatus.approved:
        if (closed) return const [_RoomClosedCard()];
        return _approvedSection(
          provider: provider,
          booking: booking,
          queue: queue,
          currentServing: currentServing,
          timeLabel: timeLabel,
          room: room,
        );
    }
  }

  /// _approvedSection: dựng phần hàng chờ thời gian thực cho lịch đã xác nhận, khóa phần theo dõi khi phòng tạm dừng.
  List<Widget> _approvedSection({
    required LichHenProvider provider,
    required LichHenModel booking,
    required List<LichHenModel> queue,
    required int currentServing,
    required String timeLabel,
    required PhongKhamTrangThai room,
  }) {
    final now = DateTime.now();
    final paused = room.trangThai == TrangThaiPhong.tamDung;
    final pausedBanner = <Widget>[
      if (paused) ...[
        _RoomPausedCard(minutes: room.phutDangTamDung(now)),
        const SizedBox(height: 16),
      ],
    ];

    // Bước 1: xác định vị trí và số thứ tự của bệnh nhân trong hàng chờ.
    final myIndex = queue.indexWhere((b) => b.id == booking.id);
    final myNumber = myIndex != -1
        ? queue[myIndex].soThuTu
        : (booking.soThuTu > 0 ? booking.soThuTu : 0);

    if (myNumber <= 0) {
      return [...pausedBanner, _NoTicketCard(timeLabel: timeLabel)];
    }

    final widgets = <Widget>[
      ...pausedBanner,
      _LockedSection(
        locked: paused,
        child: _NowServingCard(number: currentServing),
      ),
      const SizedBox(height: 16),
    ];

    // Bước 2: hiển thị thẻ lỗi, đang đồng bộ hoặc chưa thấy số nếu hàng chờ chưa sẵn sàng.
    if (provider.queueError != null) {
      widgets.add(
        _QueueStatusCard(loading: false, message: provider.queueError!),
      );
      return widgets;
    }

    if (!provider.queueLoaded) {
      widgets.add(
        _QueueStatusCard(
          loading: true,
          message: 'Số của bạn: $myNumber. Đang đồng bộ hàng chờ...',
        ),
      );
      return widgets;
    }

    if (myIndex == -1) {
      widgets.add(
        const _StatusMessageCard(
          icon: Icons.info_outline_rounded,
          color: AppColors.primary,
          title: 'Chưa thấy số của bạn trong hàng chờ',
          message:
              'Kéo xuống để làm mới. Nếu vẫn chưa thấy, vui lòng liên hệ '
              'nhân viên hỗ trợ tại phòng khám.',
        ),
      );
      return widgets;
    }

    // Bước 3: tính số người phía trước và số phút chờ.
    final peopleAhead = myIndex;
    final estimator = _queueTimeEstimator.update(currentServing);
    final perPatient = _thoiGianKham ?? estimator.perPatient;
    final waitMinutes = _queueTimeEstimator.waitMinutes(
      peopleAhead,
      perPatient,
    );

    // Bước 4: tính giờ dự kiến đến lượt, cộng thêm số phút phòng đã tạm dừng.
    final estimate = _estimateTurn(
      ngayKham: booking.ngayDat!,
      gioBatDau: booking.gioBatDau,
      gioKetThuc: booking.gioKetThuc,
      waitMinutes: waitMinutes,
      pauseMinutes: room.phutTamDung(now),
    );

    // Bước 5: dựng thẻ số của bạn, tiến độ hàng chờ (khóa khi tạm dừng) và thẻ giờ dự kiến.
    widgets.addAll([
      _LockedSection(
        locked: paused,
        child: Column(
          children: [
            _MyTurnCard(
              number: myNumber,
              peopleAhead: peopleAhead,
              waitMinutes: waitMinutes,
            ),
            const SizedBox(height: 16),
            _QueueTrack(serving: currentServing, mine: myNumber),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _EstimateCard(
        waitMinutes: waitMinutes,
        estimatedTimeStr: _hhmm(estimate.eta),
        isExceedingShift: estimate.exceeds,
        shiftNotStarted: estimate.shiftNotStarted,
        shiftStart: booking.gioBatDau,
        pausedMinutes: room.phutTamDung(now),
      ),
    ]);
    return widgets;
  }
}

/// _BookingSelector: thanh chọn lịch hẹn khi có nhiều hơn một lịch cần theo dõi.
class _BookingSelector extends StatelessWidget {
  const _BookingSelector({
    required this.bookings,
    required this.selectedId,
    required this.onSelect,
  });

  final List<LichHenModel> bookings;
  final String selectedId;
  final ValueChanged<String> onSelect;

  String _date(DateTime? d) => d == null
      ? '--/--'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = bookings[i];
          final selected = b.id == selectedId;
          final status = statusFromTrangThaiId(b.trangThaiId);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(b.id),
            child: Container(
              constraints: const BoxConstraints(minWidth: 130, maxWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.line,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_date(b.ngayDat)} · ${status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(
                      12.5,
                      weight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.tenKhoa ?? 'Chuyên khoa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(
                      12,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// _StateView: giao diện toàn màn hình cho trạng thái lỗi hoặc không có lịch.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.07),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.13),
                  ),
                  child: Icon(icon, size: 44, color: color),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _font(18.5, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _font(14, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 20),
              label: Text(
                actionLabel,
                style: _font(15, weight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _HospitalInfoCard: thẻ thông tin bệnh viện, phòng khám, ngày giờ và trạng thái lịch hẹn.
class _HospitalInfoCard extends StatelessWidget {
  const _HospitalInfoCard({
    required this.hospital,
    required this.department,
    required this.room,
    required this.date,
    required this.time,
    required this.status,
    this.roomStatus,
  });

  final String hospital;
  final String department;
  final String room;
  final String date;
  final String time;
  final AppointmentStatus status;
  final TrangThaiPhong? roomStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bệnh viện',
                        style: _font(
                          12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hospital,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _font(
                          16.5,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: status.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 14,
                        color: status.foreground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: _font(
                          11.5,
                          weight: FontWeight.w700,
                          color: status.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.teal.withValues(alpha: 0.14),
                        AppColors.teal.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.teal, AppColors.tealDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.meeting_room_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PHÒNG KHÁM',
                              style: _font(
                                10.5,
                                weight: FontWeight.w800,
                                color: AppColors.tealDark,
                              ).copyWith(letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              room,
                              style: _font(
                                17,
                                weight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.medical_services_outlined,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    department,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _font(13, color: AppColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (roomStatus != null) ...[
                        const SizedBox(width: 8),
                        _RoomStatusChip(status: roomStatus!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Ngày khám',
                        value: date,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        icon: Icons.access_time_rounded,
                        label: 'Giờ khám',
                        value: time,
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

/// _TimeTile: ô hiển thị một thông tin ngày hoặc giờ khám.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _font(11.5, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _font(14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// _NowServingCard: thẻ nổi bật hiển thị số thứ tự đang được khám.
class _NowServingCard extends StatelessWidget {
  const _NowServingCard({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(right: -50, top: -50, child: _ring(180)),
            Positioned(right: -15, top: -15, child: _ring(110)),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: CustomPaint(painter: _PulsePainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Đang khám số',
                            style: _font(
                              15,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const _LiveChip(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    number > 0 ? '$number' : '---',
                    style:
                        _font(
                          88,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.05,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tự động cập nhật theo thời gian thực',
                        style: _font(
                          13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 2),
    ),
  );
}

/// _PulsePainter: vẽ đường điện tim mờ làm họa tiết nền.
class _PulsePainter extends CustomPainter {
  const _PulsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height * 0.62;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(0, mid);
    const period = 132.0;
    for (double x = 0; x < size.width; x += period) {
      path
        ..lineTo(x + 34, mid)
        ..lineTo(x + 42, mid - 9)
        ..lineTo(x + 50, mid + 7)
        ..lineTo(x + 58, mid - 30)
        ..lineTo(x + 67, mid + 22)
        ..lineTo(x + 75, mid)
        ..lineTo(x + 85, mid - 7)
        ..lineTo(x + 95, mid)
        ..lineTo(x + period, mid);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// _LiveChip: nhãn "Trực tiếp" có chấm nhấp nháy.
class _LiveChip extends StatefulWidget {
  const _LiveChip();

  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF5CF2D6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Trực tiếp',
            style: _font(12.5, weight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// _MyTurnCard: thẻ số của bạn, số người phía trước, thời gian chờ và thông báo mức độ gần đến lượt.
class _MyTurnCard extends StatelessWidget {
  const _MyTurnCard({
    required this.number,
    required this.peopleAhead,
    required this.waitMinutes,
  });

  final int number;
  final int peopleAhead;
  final int waitMinutes;

  ({Color color, Color bg, IconData icon, String text}) get _banner {
    if (peopleAhead == 0) {
      return (
        color: AppColors.tealDark,
        bg: AppColors.teal.withValues(alpha: 0.13),
        icon: Icons.notifications_active_rounded,
        text: 'Sắp đến lượt bạn! Vui lòng có mặt tại phòng khám.',
      );
    }
    if (peopleAhead <= 3) {
      return (
        color: AppColors.warnText,
        bg: AppColors.warnBg,
        icon: Icons.directions_walk_rounded,
        text: 'Còn $peopleAhead người nữa. Hãy di chuyển đến phòng khám.',
      );
    }
    return (
      color: AppColors.primaryDark,
      bg: AppColors.primary.withValues(alpha: 0.08),
      icon: Icons.chair_alt_rounded,
      text: 'Bạn có thể nghỉ ngơi, chúng tôi sẽ báo khi gần đến lượt.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: AppColors.teal),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.teal.withValues(alpha: 0.16),
                                AppColors.teal.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'SỐ CỦA BẠN',
                                style: _font(
                                  10.5,
                                  weight: FontWeight.w800,
                                  color: AppColors.tealDark,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                              Text(
                                '$number',
                                style:
                                    _font(
                                      46,
                                      weight: FontWeight.w800,
                                      color: AppColors.tealDark,
                                      height: 1.1,
                                    ).copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Còn phía trước',
                              style: _font(13, color: AppColors.muted),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$peopleAhead',
                                    style: _font(32, weight: FontWeight.w800),
                                  ),
                                  TextSpan(
                                    text: ' người',
                                    style: _font(
                                      15,
                                      weight: FontWeight.w600,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '~$waitMinutes phút',
                                    style: _font(
                                      12.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: banner.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(banner.icon, size: 19, color: banner.color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              banner.text,
                              style: _font(
                                13,
                                weight: FontWeight.w600,
                                color: banner.color,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// _QueueTrack: thanh tiến độ hàng chờ từ số đang khám tới số của bạn.
class _QueueTrack extends StatelessWidget {
  const _QueueTrack({required this.serving, required this.mine});

  final int serving;
  final int mine;

  @override
  Widget build(BuildContext context) {
    final progress = (mine > 0 && serving > 0)
        ? (serving / mine).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Tiến độ hàng chờ',
                style: _font(14.5, weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: _font(
                  14.5,
                  weight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  const thumb = 22.0;
                  final trackWidth = constraints.maxWidth;
                  final fillWidth = (trackWidth - thumb) * value + thumb / 2;

                  return SizedBox(
                    height: thumb,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          width: fillWidth,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.teal],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Positioned(
                          left: (trackWidth - thumb) * value,
                          child: Container(
                            width: thumb,
                            height: thumb,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.teal,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.teal.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _trackLabel(
                'Đang khám',
                serving > 0 ? '#$serving' : '---',
                AppColors.primary,
                CrossAxisAlignment.start,
              ),
              _trackLabel(
                'Số của bạn',
                '#$mine',
                AppColors.tealDark,
                CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trackLabel(
    String label,
    String value,
    Color color,
    CrossAxisAlignment align,
  ) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: _font(12, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: _font(17, weight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

/// _EstimateCard: thẻ giờ dự kiến đến lượt, đổi màu cảnh báo khi vượt quá giờ ca khám.
class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.waitMinutes,
    required this.estimatedTimeStr,
    this.isExceedingShift = false,
    this.shiftNotStarted = false,
    this.shiftStart,
    this.pausedMinutes = 0,
  });

  final int pausedMinutes;
  final int waitMinutes;
  final String estimatedTimeStr;
  final bool isExceedingShift;
  final bool shiftNotStarted;
  final String? shiftStart;

  @override
  Widget build(BuildContext context) {
    final mainColor = isExceedingShift
        ? AppColors.warnText
        : AppColors.primaryDark;
    final bgColor = isExceedingShift
        ? AppColors.warnBg
        : AppColors.primary.withValues(alpha: 0.07);
    final borderColor = isExceedingShift
        ? AppColors.warnBorder
        : AppColors.primary.withValues(alpha: 0.18);
    final iconColor = isExceedingShift ? AppColors.warnText : AppColors.primary;
    final iconBgColor = isExceedingShift
        ? AppColors.warnBorder.withValues(alpha: 0.35)
        : AppColors.primary.withValues(alpha: 0.12);
    final pauseNote = pausedMinutes > 0
        ? ' Đã cộng $pausedMinutes phút phòng tạm dừng.'
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isExceedingShift
                  ? Icons.warning_amber_rounded
                  : Icons.timer_outlined,
              color: iconColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExceedingShift
                      ? 'Cảnh báo thời gian'
                      : 'Dự kiến đến lượt khoảng',
                  style: _font(12.5, color: mainColor),
                ),
                const SizedBox(height: 2),
                Text(
                  isExceedingShift
                      ? 'Có thể sang ca khám sau'
                      : estimatedTimeStr,
                  style: _font(22, weight: FontWeight.w800, color: mainColor),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              isExceedingShift
                  ? 'Số lượng bệnh nhân đông, vui lòng liên hệ quầy tiếp đón.'
                  : shiftNotStarted
                  ? 'Ca khám bắt đầu lúc ${shiftStart ?? ''}. '
                        'Còn ~$waitMinutes phút phục vụ trước bạn.$pauseNote'
                  : 'Còn ~$waitMinutes phút (tham khảo).$pauseNote',
              textAlign: TextAlign.right,
              style: _font(11.5, color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// _LateTicketCard: thẻ số cũ bị gạch ngang của người đến trễ, chưa xác định số người phía trước.
class _LateTicketCard extends StatelessWidget {
  const _LateTicketCard({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: AppColors.late),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lateBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.lateBorder),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'SỐ CỦA BẠN',
                                style: _font(
                                  10.5,
                                  weight: FontWeight.w800,
                                  color: AppColors.lateDark,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                              Text(
                                number > 0 ? '$number' : '--',
                                style:
                                    _font(
                                      46,
                                      weight: FontWeight.w800,
                                      color: AppColors.late.withValues(
                                        alpha: 0.55,
                                      ),
                                      height: 1.1,
                                    ).copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: AppColors.lateDark,
                                      decorationThickness: 2,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Còn phía trước',
                              style: _font(13, color: AppColors.muted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '—',
                              style: _font(
                                32,
                                weight: FontWeight.w800,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lateBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.lateBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: AppColors.late,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Chưa xác định',
                                    style: _font(
                                      12.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.lateDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lateBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 19,
                              color: AppColors.lateDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn đến trễ nên số thứ tự cũ đã được đưa ra khỏi '
                              'hàng chờ. Vui lòng gặp nhân viên hỗ trợ tại '
                              'phòng khám để được xếp lại.',
                              style: _font(
                                13,
                                weight: FontWeight.w600,
                                color: AppColors.lateDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

enum _StepState { done, current, upcoming }

/// _LateSteps: danh sách các bước xử lý khi đến trễ dạng timeline dọc.
class _LateSteps extends StatelessWidget {
  const _LateSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.late,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Việc cần làm tiếp theo',
                style: _font(15, weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _TimelineStep(
            state: _StepState.done,
            title: 'Đã ghi nhận bạn đến trễ',
            subtitle: 'Số thứ tự cũ được đưa ra khỏi hàng chờ.',
          ),
          const _TimelineStep(
            state: _StepState.current,
            title: 'Gặp nhân viên hỗ trợ',
            subtitle: 'Đến quầy hỗ trợ tại phòng khám và xuất trình mã QR.',
          ),
          const _TimelineStep(
            state: _StepState.upcoming,
            title: 'Được xếp lại vào hàng chờ',
            subtitle: 'Bạn sẽ nhận số mới và thông báo khi sắp đến lượt.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

/// _TimelineStep: một bước trong timeline với trạng thái đã xong, hiện tại hoặc sắp tới.
class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final _StepState state;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final Color bg;
    late final IconData icon;

    switch (state) {
      case _StepState.done:
        color = AppColors.teal;
        bg = AppColors.teal.withValues(alpha: 0.14);
        icon = Icons.check_rounded;
        break;
      case _StepState.current:
        color = AppColors.late;
        bg = AppColors.lateBg;
        icon = Icons.support_agent_rounded;
        break;
      case _StepState.upcoming:
        color = AppColors.muted;
        bg = AppColors.line.withValues(alpha: 0.5);
        icon = Icons.format_list_numbered_rounded;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: state == _StepState.current
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: state == _StepState.done
                          ? AppColors.teal.withValues(alpha: 0.4)
                          : AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _font(
                      14,
                      weight: FontWeight.w700,
                      color: state == _StepState.upcoming
                          ? AppColors.muted
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: _font(12.5, color: AppColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _LateEstimateCard: thẻ báo thời gian dự kiến chưa xác định khi đang đến trễ.
class _LateEstimateCard extends StatelessWidget {
  const _LateEstimateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lateBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lateBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.lateBorder.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.timer_off_outlined,
              color: AppColors.lateDark,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dự kiến đến lượt',
                  style: _font(12.5, color: AppColors.lateDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chưa xác định',
                  style: _font(
                    20,
                    weight: FontWeight.w800,
                    color: AppColors.lateDark,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              'Sẽ tự cập nhật sau khi nhân viên xếp lại số cho bạn.',
              textAlign: TextAlign.right,
              style: _font(11.5, color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// _CompletedCard: thẻ thông báo đã hoàn thành lượt khám.
class _CompletedCard extends StatelessWidget {
  const _CompletedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.teal, AppColors.tealDark],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Bạn đã hoàn thành lượt khám',
            style: _font(16.5, weight: FontWeight.w800, color: AppColors.teal),
          ),
          const SizedBox(height: 8),
          Text(
            'Cảm ơn bạn đã sử dụng dịch vụ. Chúc bạn nhiều sức khỏe!',
            textAlign: TextAlign.center,
            style: _font(14, color: AppColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// _StatusMessageCard: thẻ thông báo trạng thái chung (chờ duyệt, vắng mặt, đã hủy).
class _StatusMessageCard extends StatelessWidget {
  const _StatusMessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _font(16.5, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: _font(14, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// _NoTicketCard: thẻ thông báo chưa được cấp số thứ tự kèm các bước nhận số.
class _NoTicketCard extends StatelessWidget {
  const _NoTicketCard({required this.timeLabel});

  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              size: 34,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chưa được cấp số thứ tự',
            style: _font(16.5, weight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng có mặt tại bệnh viện trước $timeLabel để được nhân viên tiếp đón và cấp số.',
            textAlign: TextAlign.center,
            style: _font(14, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _StepDot(
                  icon: Icons.local_hospital_rounded,
                  label: 'Đến\nbệnh viện',
                ),
              ),
              _StepArrow(),
              Expanded(
                child: _StepDot(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Quét mã QR\ncheck-in',
                ),
              ),
              _StepArrow(),
              Expanded(
                child: _StepDot(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Nhận số\nthứ tự',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// _StepDot: biểu tượng và nhãn của một bước nhận số.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 23, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: _font(11.5, weight: FontWeight.w600, height: 1.3),
        ),
      ],
    );
  }
}

/// _StepArrow: mũi tên nối giữa các bước nhận số.
class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 13),
      child: Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.line),
    );
  }
}

/// _PrepareChecklist: danh sách việc cần chuẩn bị trước khi khám.
class _PrepareChecklist extends StatelessWidget {
  const _PrepareChecklist();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Chuẩn bị trước khi khám',
                style: _font(15, weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _CheckItem(
            icon: Icons.badge_rounded,
            text: 'Mang theo CCCD và thẻ BHYT (nếu có)',
          ),
          const _CheckItem(
            icon: Icons.qr_code_2_rounded,
            text: 'Chuẩn bị sẵn mã QR lịch khám để check-in',
          ),
          const _CheckItem(
            icon: Icons.notifications_active_rounded,
            text: 'Giữ điện thoại để nhận thông báo khi đến lượt',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

/// _CheckItem: một dòng trong danh sách chuẩn bị trước khi khám.
class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.tealDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: _font(13.5, weight: FontWeight.w500, height: 1.4),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

/// _ImportantNotice: khung lưu ý quan trọng về giờ có mặt trước khi khám.
class _ImportantNotice extends StatelessWidget {
  const _ImportantNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warnBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warnBorder.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warnText,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý quan trọng',
                  style: _font(
                    15.5,
                    weight: FontWeight.w700,
                    color: AppColors.warnText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vui lòng có mặt trước giờ khám 15 phút để làm thủ tục. '
                  'Nếu quá giờ, số thứ tự của bạn có thể bị hủy.',
                  style: _font(13.5, color: AppColors.warnText, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// _QueueStatusCard: thẻ hiển thị trạng thái đang đồng bộ hoặc lỗi của hàng chờ.
class _QueueStatusCard extends StatelessWidget {
  const _QueueStatusCard({required this.loading, required this.message});

  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = loading ? AppColors.primary : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Icon(Icons.cloud_off_rounded, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: _font(14, weight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// _cardDecoration: kiểu trang trí thẻ dùng chung.
BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF0B2A4A).withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

/// _roomLabel: nhãn hiển thị của trạng thái phòng khám.
String _roomLabel(TrangThaiPhong s) {
  switch (s) {
    case TrangThaiPhong.tamDung:
      return 'Tạm dừng';
    case TrangThaiPhong.dangKham:
      return 'Đang khám';
    case TrangThaiPhong.dongCua:
      return 'Đóng cửa';
  }
}

/// _roomColor: màu chủ đạo của trạng thái phòng khám.
Color _roomColor(TrangThaiPhong s) {
  switch (s) {
    case TrangThaiPhong.tamDung:
      return AppColors.warnText;
    case TrangThaiPhong.dangKham:
      return AppColors.tealDark;
    case TrangThaiPhong.dongCua:
      return AppColors.closed;
  }
}

/// _roomIcon: biểu tượng của trạng thái phòng khám.
IconData _roomIcon(TrangThaiPhong s) {
  switch (s) {
    case TrangThaiPhong.tamDung:
      return Icons.pause_circle_rounded;
    case TrangThaiPhong.dangKham:
      return Icons.play_circle_rounded;
    case TrangThaiPhong.dongCua:
      return Icons.lock_rounded;
  }
}

/// _RoomStatusChip: nhãn nhỏ hiển thị trạng thái của phòng khám cạnh tên phòng.
class _RoomStatusChip extends StatelessWidget {
  const _RoomStatusChip({required this.status});

  final TrangThaiPhong status;

  @override
  Widget build(BuildContext context) {
    final color = _roomColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_roomIcon(status), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            _roomLabel(status),
            style: _font(11, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// _LockedSection: làm mờ, chuyển xám và khóa thao tác phần bên trong, kèm nhãn "Tạm khóa theo dõi" khi bị khóa.
class _LockedSection extends StatelessWidget {
  const _LockedSection({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  static const ColorFilter _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Stack(
      children: [
        IgnorePointer(
          child: Opacity(
            opacity: 0.45,
            child: ColorFiltered(colorFilter: _grayscale, child: child),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Tạm khóa theo dõi',
                    style: _font(
                      13,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// _RoomPausedCard: thẻ thông báo phòng khám đang tạm dừng, kèm số phút đã tạm dừng.
class _RoomPausedCard extends StatelessWidget {
  const _RoomPausedCard({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warnBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warnBorder.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_filled_rounded,
              size: 28,
              color: AppColors.warnText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng khám đang tạm dừng',
                  style: _font(
                    15.5,
                    weight: FontWeight.w800,
                    color: AppColors.warnText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Việc khám tạm thời gián đoạn. Giờ dự kiến đến lượt sẽ '
                  'tự động cộng thêm thời gian tạm dừng.',
                  style: _font(13, color: AppColors.warnText, height: 1.45),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warnBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.warnText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Đã tạm dừng $minutes phút',
                        style: _font(
                          12.5,
                          weight: FontWeight.w700,
                          color: AppColors.warnText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// _RoomClosedCard: thẻ thông báo phòng khám đã đóng cửa, thay thế toàn bộ phần theo dõi hàng chờ.
class _RoomClosedCard extends StatelessWidget {
  const _RoomClosedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF64748B), AppColors.closed],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Phòng khám đã đóng cửa',
                  textAlign: TextAlign.center,
                  style: _font(
                    18.5,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hiện không tiếp nhận bệnh nhân',
                  style: _font(13, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: const [
                _ClosedInfoRow(
                  icon: Icons.sync_disabled_rounded,
                  text: 'Theo dõi số thứ tự và giờ dự kiến đã dừng.',
                ),
                SizedBox(height: 12),
                _ClosedInfoRow(
                  icon: Icons.support_agent_rounded,
                  text: 'Vui lòng liên hệ quầy tiếp đón để được hỗ trợ.',
                ),
                SizedBox(height: 12),
                _ClosedInfoRow(
                  icon: Icons.event_repeat_rounded,
                  text: 'Bạn có thể đặt lại lịch khám vào ngày khác.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// _ClosedInfoRow: một dòng hướng dẫn trong thẻ phòng khám đã đóng cửa.
class _ClosedInfoRow extends StatelessWidget {
  const _ClosedInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.closedBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: AppColors.closed),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: _font(13.5, weight: FontWeight.w500, height: 1.4),
          ),
        ),
      ],
    );
  }
}