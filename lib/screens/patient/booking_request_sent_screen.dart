import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appointment_item.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/appointment_card.dart';

/// BookingRequestSentScreen: màn "Đã gửi yêu cầu đặt lịch" (chờ bệnh viện duyệt).
/// Dữ liệu lấy theo thứ tự: tham số constructor, rồi route arguments
/// (Map hoặc MyAppointmentItem), cuối cùng là dấu '—'.
class BookingRequestSentScreen extends StatelessWidget {
  final String? requestCode;
  final String? hospitalName;
  final String? departmentName;
  final String? dateLabel;
  final String? shiftLabel;
  final VoidCallback? onViewStatus;
  final VoidCallback? onGoHome;

  const BookingRequestSentScreen({
    super.key,
    this.requestCode,
    this.hospitalName,
    this.departmentName,
    this.dateLabel,
    this.shiftLabel,
    this.onViewStatus,
    this.onGoHome,
  });

  static const _gold = Color(0xFF8A5B00);
  static const _empty = '—';

  /// _arg: đọc một giá trị từ route arguments. Map thì lấy theo [mapKey],
  /// kiểu khác (vd MyAppointmentItem) thì đọc bằng [fromObject]. Không có thì trả null.
  static String? _arg(
    Object? args,
    String mapKey,
    dynamic Function(dynamic a) fromObject,
  ) {
    if (args == null) return null;
    dynamic value;
    if (args is Map) {
      value = args[mapKey];
    } else {
      try {
        value = fromObject(args);
      } catch (_) {
        value = null;
      }
    }
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final code =
        requestCode ?? _arg(args, 'requestCode', (a) => a.id) ?? _empty;
    final hospital = hospitalName ??
        _arg(args, 'hospitalName', (a) => a.hospitalName) ??
        _empty;
    final department = departmentName ??
        _arg(args, 'departmentName', (a) => a.departmentName) ??
        _empty;
    final date =
        dateLabel ?? _arg(args, 'dateLabel', (a) => a.dateLabel) ?? _empty;
    final shift =
        shiftLabel ?? _arg(args, 'shiftLabel', (a) => a.timeLabel) ?? _empty;

    return Scaffold(
      backgroundColor: ApptColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            children: [
              const _HourglassBadge(),
              const SizedBox(height: 14),
              const Text(
                'Đã gửi yêu cầu đặt lịch',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bệnh viện đang xét duyệt dựa trên số bác sĩ\nkhám ngày hôm đó',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: ApptColors.textGrey,
                ),
              ),
              const SizedBox(height: 22),
              _buildProgressCard(),
              const SizedBox(height: 16),
              _buildRequestCard(
                context,
                code: code,
                hospital: hospital,
                department: department,
                date: date,
                shift: shift,
              ),
              const SizedBox(height: 16),
              _buildNotifyHint(),
              const SizedBox(height: 24),
              ApptButton(text: 'Xem trạng thái đặt lịch', onPressed: onViewStatus),
              const SizedBox(height: 12),
              ApptButton(
                text: 'Về trang chủ',
                background: Colors.white,
                foreground: ApptColors.textDark,
                borderColor: ApptColors.border,
                // Mặc định quay về màn hình đầu tiên của ứng dụng.
                onPressed: onGoHome ??
                    () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// _buildProgressCard: thanh tiến trình 3 bước (đã gửi, chờ duyệt, nhận số).
  Widget _buildProgressCard() {
    return ApptCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepItem(
            icon: Icons.check_rounded,
            label: 'Đã gửi\nyêu cầu',
            state: _StepState.done,
          ),
          _StepLine(active: true),
          _StepItem(
            icon: Icons.hourglass_top_rounded,
            label: 'Bệnh viện\nxét duyệt',
            state: _StepState.current,
          ),
          _StepLine(active: false),
          _StepItem(
            icon: Icons.confirmation_number_rounded,
            label: 'Nhận số thứ\ntự & giờ khám',
            state: _StepState.todo,
          ),
        ],
      ),
    );
  }

  /// _buildRequestCard: thẻ mã yêu cầu (có nút sao chép) và thông tin lịch khám.
  Widget _buildRequestCard(
    BuildContext context, {
    required String code,
    required String hospital,
    required String department,
    required String date,
    required String shift,
  }) {
    return ApptCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'MÃ YÊU CẦU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ApptColors.textGrey,
                  ),
                ),
              ),
              StatusChip(AppointmentStatus.pending),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                // Mã dài thì tự thu nhỏ cho vừa khung.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: ApptColors.primary,
                    ),
                  ),
                ),
              ),
              if (code != _empty)
                IconButton(
                  tooltip: 'Sao chép mã',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: ApptColors.textGrey,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    context.showAppSnackBar(
                      title: 'Sao chép thành công',
                      message: 'Đã sao chép mã yêu cầu',
                      type: SnackBarType.success,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.local_hospital_rounded,
            label: 'Bệnh viện',
            value: hospital,
          ),
          _InfoLine(
            icon: Icons.medical_services_outlined,
            label: 'Chuyên khoa',
            value: department,
          ),
          _InfoLine(
            icon: Icons.calendar_today_rounded,
            label: 'Ngày khám',
            value: date,
          ),
          _InfoLine(icon: Icons.schedule_rounded, label: 'Ca', value: shift),
        ],
      ),
    );
  }

  /// _buildNotifyHint: khung nhắc người dùng sẽ nhận thông báo khi được duyệt.
  Widget _buildNotifyHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 18,
              color: ApptColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Bạn sẽ nhận thông báo ngay khi bệnh viện xác nhận, '
                'kèm số thứ tự và giờ khám chính thức.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: ApptColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// _HourglassBadge: biểu tượng đồng hồ cát nhiều lớp, phóng to dần khi xuất hiện.
class _HourglassBadge extends StatelessWidget {
  const _HourglassBadge();

  static const _amber = Color(0xFFF59E0B);

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: SizedBox(
        width: 136,
        height: 136,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _circle(136, _amber.withOpacity(0.10)),
            _circle(108, _amber.withOpacity(0.16)),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFC857), _amber],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _amber.withOpacity(0.40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, todo }

/// _StepItem: một bước trong quy trình (vòng tròn icon + nhãn), màu theo trạng thái bước.
class _StepItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final _StepState state;

  const _StepItem({
    required this.icon,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final (circle, iconColor, textColor) = switch (state) {
      _StepState.done => (
        const Color(0xFF22C55E),
        Colors.white,
        ApptColors.textDark,
      ),
      _StepState.current => (
        const Color(0xFFF59E0B),
        Colors.white,
        ApptColors.textDark,
      ),
      _StepState.todo => (
        const Color(0xFFE2E8F0),
        ApptColors.textGrey,
        ApptColors.textGrey,
      ),
    };

    return Expanded(
      flex: 3,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: circle,
              shape: BoxShape.circle,
              // Vòng sáng quanh bước hiện tại.
              boxShadow: state == _StepState.current
                  ? [
                      BoxShadow(
                        color: circle.withOpacity(0.35),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              fontWeight:
                  state == _StepState.current ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// _StepLine: đường nối giữa hai bước (xanh nếu bước trước đã xong).
class _StepLine extends StatelessWidget {
  final bool active;

  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// _InfoLine: một dòng thông tin có icon, nhãn nhỏ phía trên và giá trị đậm phía dưới.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ApptColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: ApptColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApptColors.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: ApptColors.textDark,
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

/// _DashedDivider: đường kẻ nét đứt kiểu phiếu.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 9).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 5, height: 1.5, color: ApptColors.border),
          ),
        );
      },
    );
  }
}