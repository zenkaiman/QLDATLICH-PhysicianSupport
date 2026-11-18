import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_routes.dart';
import '../../models/appointment_item.dart';
import '../../widgets/appointment_card.dart';
import '../../utils/app_snackbar.dart';
import 'book_appointment_widget.dart' show AppTheme, AppCard, InfoPill, SectionTitle;

/// AppointmentDetailHeader: thanh tiêu đề của màn chi tiết lịch khám.
class AppointmentDetailHeader extends StatelessWidget {
  const AppointmentDetailHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Material(
            color: AppTheme.tint(AppTheme.primaryBlue),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Chi tiết lịch khám',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Thông tin và trạng thái',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// AppointmentStatusHero: thẻ trạng thái lịch khám, kèm các bước tiến trình khi đang chờ hoặc đã duyệt.
class AppointmentStatusHero extends StatelessWidget {
  final bool isPending;
  final bool isApproved;
  final bool isCancelled;

  const AppointmentStatusHero({
    super.key,
    required this.isPending,
    required this.isApproved,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String title;
    final String message;
    final Color color;

    if (isCancelled) {
      icon = Icons.event_busy_rounded;
      title = 'Lịch khám đã bị hủy';
      message = 'Lịch khám này không còn hiệu lực.';
      color = AppTheme.danger;
    } else if (isApproved) {
      icon = Icons.verified_rounded;
      title = 'Lịch khám đã được duyệt';
      message = 'Vui lòng đến đúng ngày và khung giờ đã đặt.';
      color = AppTheme.primaryGreen;
    } else if (isPending) {
      icon = Icons.hourglass_top_rounded;
      title = 'Đang chờ bệnh viện xác nhận';
      message = 'Bạn sẽ được thông báo ngay khi lịch khám được duyệt.';
      color = AppTheme.warning;
    } else {
      icon = Icons.event_note_rounded;
      title = 'Thông tin lịch khám';
      message = 'Chi tiết lịch khám của bạn.';
      color = AppTheme.primaryBlue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.tint(color, 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.tint(color, 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 25, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPending || isApproved) ...[
            const SizedBox(height: 20),
            AppointmentStatusSteps(
              completed: isApproved ? 3 : 1,
              current: isApproved ? null : 1,
              accent: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// AppointmentStatusSteps: dải ba bước Đã gửi, Chờ duyệt, Đã duyệt.
class AppointmentStatusSteps extends StatelessWidget {
  final int completed;
  final int? current;
  final Color accent;

  const AppointmentStatusSteps({
    super.key,
    required this.completed,
    required this.current,
    required this.accent,
  });

  /// _circle: vòng tròn đánh dấu một bước (đã xong, đang chờ hoặc chưa tới).
  Widget _circle(int step) {
    final done = step < completed;
    final isCurrent = step == current;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? accent : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: done || isCurrent ? accent : AppTheme.borderColor,
          width: 2,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : isCurrent
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Đã gửi', 'Chờ duyệt', 'Đã duyệt'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(5, (i) {
        if (i.isOdd) {
          final lineDone = (i ~/ 2) + 1 < completed;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 6, right: 6),
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  color: lineDone ? accent : AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }
        final step = i ~/ 2;
        final highlighted = step < completed || step == current;
        return Column(
          children: [
            _circle(step),
            const SizedBox(height: 6),
            Text(
              labels[step],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                color: highlighted ? AppTheme.textDark : AppTheme.textGrey,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// AppointmentInfoCard: thẻ thông tin bệnh viện, chuyên khoa, mã lịch, ngày và giờ khám.
class AppointmentInfoCard extends StatelessWidget {
  final MyAppointmentItem appointment;
  final AppointmentStatus status;

  const AppointmentInfoCard({
    super.key,
    required this.appointment,
    required this.status,
  });

  /// _copyId: sao chép mã lịch hẹn vào clipboard.
  Future<void> _copyId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: appointment.id));
    if (!context.mounted) return;
    context.showAppSnackBar(
      title: 'Sao chép thành công',
      message: 'Đã sao chép mã lịch hẹn',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.tint(AppTheme.primaryBlue),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    size: 26,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.hospitalName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InfoPill(
                        icon: Icons.medical_services_outlined,
                        text: appointment.departmentName,
                        color: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                AppointmentInfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Mã lịch hẹn',
                  value: appointment.id,
                  trailing: IconButton(
                    tooltip: 'Sao chép mã',
                    onPressed: () => _copyId(context),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 19,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                AppointmentInfoRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Ngày khám',
                  value: appointment.dateLabel,
                ),
                const Divider(height: 1, color: AppTheme.borderColor),
                AppointmentInfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Khung giờ',
                  value: appointment.timeLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AppointmentInfoRow: một dòng thông tin gồm biểu tượng, nhãn, giá trị và nút phụ.
class AppointmentInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const AppointmentInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.mutedFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
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
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// AppointmentPendingSection: lưu ý chờ duyệt và nút hủy lịch.
class AppointmentPendingSection extends StatelessWidget {
  final VoidCallback onCancel;

  const AppointmentPendingSection({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DB),
            borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lịch khám đang chờ bệnh viện xác nhận. Bạn có thể hủy nếu có thay đổi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF7A4A07),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close_rounded, size: 19),
          label: const Text(
            'Hủy lịch khám này',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.danger,
            backgroundColor: Colors.white,
            side: BorderSide(color: AppTheme.tint(AppTheme.danger, 0.45)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            ),
          ),
        ),
      ],
    );
  }
}

/// AppointmentApprovedSection: số thứ tự, thời gian chờ ước tính (nhận từ hàng chờ thời gian thực) và các nút theo dõi.
class AppointmentApprovedSection extends StatelessWidget {
  final Future<Map<String, dynamic>?> detailsFuture;
  final String waitLabel;
  final VoidCallback onRefresh;
  final VoidCallback onTrack;
  final void Function(Map<String, dynamic> data) onShareTicket;

  const AppointmentApprovedSection({
    super.key,
    required this.detailsFuture,
    required this.waitLabel,
    required this.onRefresh,
    required this.onTrack,
    required this.onShareTicket,
  });

  /// _statSkeleton: ô giữ chỗ khi đang tải số thứ tự.
  Widget _statSkeleton() {
    return const AppCard(
      child: SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Expanded(child: _statSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _statSkeleton()),
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.tint(AppTheme.primaryGreen, 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Không thể tải thông tin số thứ tự. Vui lòng thử lại sau.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF0B6B49),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final soThuTu = data['so_thu_tu']?.toString() ?? 'Chưa có';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppointmentStatTile(
                    icon: Icons.format_list_numbered_rounded,
                    label: 'Số thứ tự của bạn',
                    value: soThuTu,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppointmentStatTile(
                    icon: Icons.timer_outlined,
                    label: 'Thời gian chờ ước tính',
                    value: waitLabel,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.track_changes_rounded, size: 19),
              label: const Text(
                'Theo dõi số thứ tự trực tiếp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onShareTicket(data),
              icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              label: const Text(
                'Xem và chia sẻ vé khám',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: AppTheme.tint(AppTheme.primaryBlue, 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusItem),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text(
                'Làm mới trạng thái',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textGrey,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// AppointmentStatTile: ô số liệu lớn kèm biểu tượng và nhãn.
class AppointmentStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const AppointmentStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.tint(color, 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

/// AppointmentCancelledSection: gợi ý đặt lại, về trang chủ và xóa lịch đã hủy.
class AppointmentCancelledSection extends StatelessWidget {
  final VoidCallback onGoToBooking;
  final VoidCallback onDelete;

  const AppointmentCancelledSection({
    super.key,
    required this.onGoToBooking,
    required this.onDelete,
  });

  /// _iconBox: ô biểu tượng màu đặc dùng trong dòng gợi ý.
  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const SectionTitle(
          icon: Icons.lightbulb_outline_rounded,
          text: 'Gợi ý cho bạn',
        ),
        const SizedBox(height: 12),
        SuggestionTile(
          background: AppTheme.tint(AppTheme.primaryGreen, 0.08),
          accent: AppTheme.primaryGreen,
          leading: _iconBox(
            Icons.access_time_filled_rounded,
            AppTheme.primaryGreen,
          ),
          title: 'Đặt lịch ca khác',
          subtitle: 'Xem các khung giờ còn trống trong ngày',
          onTap: onGoToBooking,
        ),
        const SizedBox(height: 10),
        SuggestionTile(
          background: AppTheme.tint(AppTheme.primaryBlue, 0.08),
          accent: AppTheme.primaryBlue,
          leading: _iconBox(
            Icons.calendar_month_rounded,
            AppTheme.primaryBlue,
          ),
          title: 'Chọn ngày khác',
          subtitle: 'Xem lịch trống các ngày tới',
          onTap: onGoToBooking,
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: onGoToBooking,
          icon: const Icon(Icons.event_available_rounded, size: 20),
          label: const Text(
            'Đặt lịch khám mới',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.patientMain,
            (route) => route.isFirst,
          ),
          icon: const Icon(Icons.home_rounded, size: 20),
          label: const Text(
            'Về trang chủ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textDark,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppTheme.borderColor),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, size: 19),
          label: const Text(
            'Xóa lịch khám này',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.danger,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// ConfirmActionDialog: hộp thoại xác nhận hủy hoặc xóa lịch khám kèm tóm tắt lịch.
class ConfirmActionDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String warning;
  final String keepLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final MyAppointmentItem appointment;
  final VoidCallback onConfirm;

  const ConfirmActionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.warning,
    required this.keepLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.appointment,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusItem),
    );

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.tint(AppTheme.danger, 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textGrey,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.mutedFill,
                borderRadius: BorderRadius.circular(AppTheme.radiusItem),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppointmentDialogInfoRow(
                    icon: Icons.local_hospital_rounded,
                    text: appointment.hospitalName,
                    bold: true,
                  ),
                  const SizedBox(height: 10),
                  AppointmentDialogInfoRow(
                    icon: Icons.calendar_month_rounded,
                    text: appointment.dateLabel,
                  ),
                  const SizedBox(height: 10),
                  AppointmentDialogInfoRow(
                    icon: Icons.schedule_rounded,
                    text: appointment.timeLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: buttonShape,
                    ),
                    child: Text(
                      keepLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    icon: Icon(confirmIcon, size: 18),
                    label: Text(
                      confirmLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: buttonShape,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AppointmentDialogInfoRow: dòng thông tin ngắn trong hộp thoại xác nhận.
class AppointmentDialogInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;

  const AppointmentDialogInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 15, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.3,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// SuggestionTile: dòng gợi ý bấm được với biểu tượng, tiêu đề và mô tả.
class SuggestionTile extends StatelessWidget {
  final Color background;
  final Color accent;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SuggestionTile({
    super.key,
    required this.background,
    required this.accent,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
        side: BorderSide(color: AppTheme.tint(accent, 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// DetailRow: dòng nhãn và giá trị dạng "Nhãn: giá trị".
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double? labelWidth;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth ?? 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}