import 'package:flutter/material.dart';
import '../../models/appointment_item.dart';

/// Bảng màu dùng chung cho các màn hình đặt lịch / lịch khám.
class ApptColors {
  static const primary = Color(0xFF1565C0);
  static const link = Color(0xFF2979FF);
  static const bg = Color(0xFFF5F6FA);
  static const textDark = Color(0xFF0F172A);
  static const textGrey = Color(0xFF64748B);
  static const border = Color(0xFFE6E9F0);
  static const green = Color(0xFF2E7D32);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFE53935);
}

/// Nhãn trạng thái bo tròn (Chờ duyệt / Đã duyệt / Đã hủy).
class StatusChip extends StatelessWidget {
  final AppointmentStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.borderColor),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: status.foreground,
        ),
      ),
    );
  }
}

/// Thẻ trắng bo góc có bóng nhẹ.
class ApptCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ApptCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ApptColors.border),
        boxShadow: [
          BoxShadow(
            color: ApptColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Thanh tiêu đề: nút quay lại + tên màn hình.
class ApptHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const ApptHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: ApptColors.border),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: onBack ?? () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: ApptColors.textDark,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ApptColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng "nhãn - giá trị".
/// [alignValueEnd] = true: giá trị căn phải; false: giá trị nằm ngay sau cột nhãn.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignValueEnd;
  final double labelWidth;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.alignValueEnd = false,
    this.labelWidth = 118,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: const TextStyle(fontSize: 13.5, color: ApptColors.textGrey),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          alignValueEnd
              ? labelText
              : SizedBox(width: labelWidth, child: labelText),
          if (alignValueEnd) const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: alignValueEnd ? TextAlign.end : TextAlign.start,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: valueColor ?? ApptColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút bấm to, bo góc, dùng cho các hành động chính / phụ.
class ApptButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  const ApptButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.background = ApptColors.primary,
    this.foreground = Colors.white,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}

/// Thanh điều hướng dưới của bệnh nhân: Trang chủ / Lịch khám của tôi / Đăng xuất.
class PatientBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const PatientBottomNav({super.key, this.currentIndex = 1, this.onTap});

  static const _items = [
    _NavItem(Icons.search_rounded, 'Trang chủ (tìm BV)'),
    _NavItem(Icons.calendar_month_rounded, 'Lịch khám của tôi'),
    _NavItem(Icons.logout_rounded, 'Đăng xuất'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: ApptColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isLogout = i == 2;
              final active = i == currentIndex;
              final color = isLogout
                  ? ApptColors.red
                  : (active ? ApptColors.primary : ApptColors.textGrey);

              return Expanded(
                child: InkWell(
                  onTap: () => onTap?.call(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 24, color: color),

                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
