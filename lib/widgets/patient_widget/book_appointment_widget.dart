import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/lichhen_model.dart';
import '../../models/phong_kham_model.dart';
import '../../providers/lich_hen_provider.dart';
import '../../providers/review_provider.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/booking_helper.dart';

/// AppTheme: bảng màu, bo góc và bóng đổ dùng chung cho màn đặt lịch.
class AppTheme {
  AppTheme._();

  static const Color bgColor = Color(0xFFF3F6FA);
  static const Color primaryBlue = Color(0xFF0F6CBD);
  static const Color primaryGreen = Color(0xFF0E9F6E);
  static const Color textDark = Color(0xFF0F2A43);
  static const Color textGrey = Color(0xFF5F6F82);
  static const Color borderColor = Color(0xFFDDE5EE);
  static const Color mutedFill = Color(0xFFEEF3F8);
  static const Color amber = Color(0xFFF5A623);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFC62828);

  static const double radiusCard = 18;
  static const double radiusItem = 14;
  static const int soNgayHienThi = 6;

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x0F0F2A43), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// tint: tạo màu nền nhạt từ một màu chính.
  static Color tint(Color color, [double opacity = 0.1]) =>
      color.withOpacity(opacity);
}

/// AppCard: khung thẻ trắng bo góc dùng chung cho các khối nội dung.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

/// SectionTitle: tiêu đề mục kèm biểu tượng, dấu bắt buộc và phần phụ bên phải.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool required;
  final Widget? trailing;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.text,
    this.required = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.tint(AppTheme.primaryBlue),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppTheme.danger),
                  ),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// InfoPill: nhãn nhỏ bo tròn hiển thị trạng thái hoặc thông tin ngắn.
class InfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;

  const InfoPill({
    super.key,
    required this.text,
    required this.color,
    this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? AppTheme.tint(color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// StatePanel: khung thông báo trống hoặc lỗi, có thể kèm nút thử lại.
class StatePanel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onRetry;

  const StatePanel({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.mutedFill,
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textGrey,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }
}

/// LoadingBox: vòng tròn tải dữ liệu căn giữa.
class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
    );
  }
}

/// SelectionTile: dòng lựa chọn dùng chung cho chuyên khoa, phòng khám và ca khám.
class SelectionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final bool square;
  final Widget? footer;
  final VoidCallback? onTap;

  const SelectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    this.iconColor,
    this.iconBackground,
    this.subtitle,
    this.disabled = false,
    this.square = false,
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = AppTheme.primaryBlue;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: selected ? AppTheme.tint(blue, 0.06) : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusItem),
          side: BorderSide(
            color: selected ? blue : AppTheme.borderColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            iconBackground ??
                            (selected
                                ? AppTheme.tint(blue, 0.14)
                                : AppTheme.mutedFill),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 21,
                        color:
                            iconColor ??
                            (selected ? blue : AppTheme.textGrey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? blue : AppTheme.textDark,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SelectIndicator(selected: selected, square: square),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// _SelectIndicator: ô tích (nhiều lựa chọn) hoặc nút tròn (một lựa chọn).
class _SelectIndicator extends StatelessWidget {
  final bool selected;
  final bool square;

  const _SelectIndicator({required this.selected, required this.square});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(7) : null,
        color: selected ? AppTheme.primaryBlue : Colors.transparent,
        border: Border.all(
          color: selected ? AppTheme.primaryBlue : const Color(0xFFB8C4D2),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

/// AppointmentHeader: thanh tiêu đề đơn giản có nút quay lại.
class AppointmentHeader extends StatelessWidget {
  final Color textDark;
  final VoidCallback onBack;

  const AppointmentHeader({
    super.key,
    required this.textDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: AppTheme.mutedFill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.arrow_back_ios_new, size: 16),
              ),
            ),
          ),
          Text(
            'Điền thông tin đặt lịch',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// HospitalInfoCard: thẻ thông tin bệnh viện gồm loại cơ sở, đánh giá, địa chỉ và BHYT.
class HospitalInfoCard extends StatelessWidget {
  final Map<String, dynamic> hospitalData;

  const HospitalInfoCard({super.key, required this.hospitalData});

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final name = hospitalData['ten_benh_vien']?.toString() ?? 'Tên bệnh viện';
    final address = hospitalData['dia_chi']?.toString() ?? 'Địa chỉ';
    final rating = _toDouble(
      hospitalData['diem_danh_gia_tb'] ?? hospitalData['diem_danh_gia'],
    );
    final reviewCount = _toInt(
      hospitalData['tong_so_danh_gia'] ?? hospitalData['so_luong_danh_gia'],
    );

    final facility = (hospitalData['co_so'] ?? hospitalData['co_so_id'] ?? '')
        .toString()
        .toLowerCase();
    final isPublic = facility == 'cong_lap' || facility == 'công lập';
    final isPrivate = facility == 'tu_nhan' || facility == 'tư nhân';
    final facilityLabel = isPublic
        ? 'Bệnh viện công'
        : isPrivate
        ? 'Bệnh viện tư'
        : 'Chưa cập nhật loại cơ sở';
    final facilityColor = isPublic
        ? AppTheme.primaryBlue
        : isPrivate
        ? AppTheme.warning
        : AppTheme.textGrey;

    final bhyt = (hospitalData['bhyt'] ?? hospitalData['bhyt_id'] ?? '')
        .toString()
        .toLowerCase();
    final hasBhyt = bhyt == 'co_bhyt' || bhyt == 'có bhyt' || bhyt == 'true';
    final noBhyt = bhyt == 'khong_bhyt' || bhyt == 'không bhyt';
    final bhytColor = hasBhyt
        ? AppTheme.primaryGreen
        : noBhyt
        ? AppTheme.danger
        : AppTheme.textGrey;
    final bhytText = hasBhyt
        ? 'Có hỗ trợ khám BHYT'
        : noBhyt
        ? 'Không hỗ trợ khám BHYT'
        : 'Chưa cập nhật thông tin BHYT';
    final bhytIcon = hasBhyt
        ? Icons.verified_rounded
        : noBhyt
        ? Icons.cancel_rounded
        : Icons.info_outline_rounded;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.tint(facilityColor, 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 28,
                  color: facilityColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InfoPill(text: facilityLabel, color: facilityColor),
                        InfoPill(
                          icon: Icons.star_rounded,
                          text: rating > 0
                              ? '${rating.toStringAsFixed(1)}'
                                    '${reviewCount > 0 ? ' ($reviewCount)' : ''}'
                              : 'Chưa có đánh giá',
                          color: rating > 0
                              ? AppTheme.warning
                              : AppTheme.textGrey,
                          background: rating > 0
                              ? const Color(0xFFFFF4DB)
                              : AppTheme.mutedFill,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 20,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppTheme.tint(bhytColor, 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(bhytIcon, size: 20, color: bhytColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bhytText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: bhytColor,
                    ),
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

/// BookingInfoBox: ghi chú hướng dẫn các bước đặt lịch.
class BookingInfoBox extends StatelessWidget {
  const BookingInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = AppTheme.primaryBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.tint(blue, 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusItem),
        border: Border.all(color: AppTheme.tint(blue, 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: blue, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textDark,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: 'Vui lòng chọn '),
                  TextSpan(
                    text: 'chuyên khoa',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ', '),
                  TextSpan(
                    text: 'phòng khám',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' và '),
                  TextSpan(
                    text: 'ngày khám',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' phù hợp. Lịch hẹn sẽ được bệnh viện '),
                  TextSpan(
                    text: 'xét duyệt',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SpecialtySelectionSection: ô chọn nhiều chuyên khoa với danh sách xổ xuống.
class SpecialtySelectionSection extends StatelessWidget {
  final int selectedCount;
  final List<String> selectedNames;
  final bool isExpanded;
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> departments;
  final Set<String> selectedDepartmentIds;
  final VoidCallback onToggleExpand;
  final Function(String) onToggleDepartment;

  const SpecialtySelectionSection({
    super.key,
    required this.selectedCount,
    required this.selectedNames,
    required this.isExpanded,
    required this.isLoading,
    this.error,
    required this.departments,
    required this.selectedDepartmentIds,
    required this.onToggleExpand,
    required this.onToggleDepartment,
  });

  /// _buildDepartmentList: dựng nội dung danh sách theo trạng thái tải, lỗi, rỗng.
  Widget _buildDepartmentList() {
    if (isLoading) return const LoadingBox();
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: StatePanel(
          icon: Icons.error_outline_rounded,
          text: error!,
          color: AppTheme.danger,
        ),
      );
    }
    if (departments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: StatePanel(
          icon: Icons.search_off_rounded,
          text: 'Bệnh viện chưa có danh sách chuyên khoa.',
          color: AppTheme.textGrey,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: departments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final department = departments[index];
          final id = BookingHelper.departmentIdOf(department);
          return SelectionTile(
            icon: Icons.health_and_safety_outlined,
            title: department['ten_khoa']?.toString() ?? 'Chuyên khoa',
            subtitle: department['mo_ta']?.toString(),
            selected: selectedDepartmentIds.contains(id),
            square: true,
            onTap: () => onToggleDepartment(id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = AppTheme.primaryBlue;
    final active = isExpanded || selectedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          icon: Icons.medical_services_outlined,
          text: 'Chọn chuyên khoa khám',
          required: true,
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            side: BorderSide(
              color: active ? blue : AppTheme.borderColor,
              width: 1.4,
            ),
          ),
          child: InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: selectedCount == 0
                        ? const Text(
                            'Chọn một hoặc nhiều chuyên khoa',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textGrey,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đã chọn ($selectedCount)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: blue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedNames.isEmpty
                                    ? '$selectedCount chuyên khoa'
                                    : selectedNames.join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 26,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !isExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildDepartmentList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// BookingStepTitle: tiêu đề bước 1-3, hiện dấu tích khi bước đã hoàn tất.
class BookingStepTitle extends StatelessWidget {
  final int step;
  final String text;
  final bool done;

  const BookingStepTitle({
    super.key,
    required this.step,
    required this.text,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? AppTheme.primaryGreen : AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '$step',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

/// RoomSelectionList: danh sách phòng khám của chuyên khoa đang chọn.
class RoomSelectionList extends StatelessWidget {
  final String activeId;
  final bool isLoading;
  final String? error;
  final List<PhongKhamModel> rooms;
  final String? selectedRoomId;
  final Function(String, String) onSelect;
  final Function(String, {bool force}) onRetry;

  const RoomSelectionList({
    super.key,
    required this.activeId,
    required this.isLoading,
    this.error,
    required this.rooms,
    required this.selectedRoomId,
    required this.onSelect,
    required this.onRetry,
  });

  /// _buildTile: dựng một dòng phòng khám.
  Widget _buildTile(PhongKhamModel room) {
    final roomId = BookingHelper.roomIdOf(room);
    return SelectionTile(
      icon: Icons.meeting_room_rounded,
      title: BookingHelper.roomNameOf(room),
      subtitle: BookingHelper.roomSubtitleOf(room),
      selected: selectedRoomId == roomId,
      onTap: () => onSelect(activeId, roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingBox();
    if (error != null) {
      return StatePanel(
        icon: Icons.error_outline_rounded,
        text: error!,
        color: AppTheme.danger,
        onRetry: () => onRetry(activeId, force: true),
      );
    }
    if (rooms.isEmpty) {
      return const StatePanel(
        icon: Icons.meeting_room_outlined,
        text: 'Chuyên khoa này chưa có phòng khám.',
        color: AppTheme.textGrey,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rooms.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rooms.length - 1 ? 0 : 10),
            child: _buildTile(rooms[i]),
          ),
      ],
    );
  }
}

/// DateTimeSelectionSection: chọn phòng khám, ngày và khung giờ cho từng chuyên khoa.
class DateTimeSelectionSection extends StatelessWidget {
  final List<String> selectedIds;
  final String? activeId;
  final String? selectedRoomId;
  final DateTime? selectedDay;
  final int doneCount;
  final List<Map<String, dynamic>> days;
  final LichHenProvider lichHen;
  final CaSlotModel? selectedSlot;
  final String monthLabel;
  final String hospitalId;
  final List<PhongKhamModel> rooms;
  final bool isLoadingRooms;
  final String? roomError;
  final bool Function(String) hasSchedule;
  final Function(String, {bool force}) onRetryFetch;
  final Function(String, String) onRoomSelected;
  final Function(String, String, DateTime) onDaySelected;
  final Function(String, String) onOpenCalendar;
  final String Function(String) getDepartmentName;
  final String Function(String, String) getRoomName;
  final String Function(DateTime) formatDayMonth;
  final int Function(String, String) getRoomMax;
  final Function(String, String, String) onSlotSelected;
  final Function(String) onSwitchActiveDepartment;
  final Map<String, int>? waitingByCa;

  const DateTimeSelectionSection({
    super.key,
    required this.selectedIds,
    required this.activeId,
    required this.selectedRoomId,
    required this.selectedDay,
    required this.doneCount,
    required this.days,
    required this.lichHen,
    required this.selectedSlot,
    required this.monthLabel,
    required this.hospitalId,
    required this.rooms,
    required this.isLoadingRooms,
    this.roomError,
    required this.hasSchedule,
    required this.onRetryFetch,
    required this.onRoomSelected,
    required this.onDaySelected,
    required this.onOpenCalendar,
    required this.getDepartmentName,
    required this.getRoomName,
    required this.formatDayMonth,
    required this.getRoomMax,
    required this.onSlotSelected,
    required this.onSwitchActiveDepartment,
    this.waitingByCa,
  });

  /// _buildDepartmentTabs: dãy nút chuyển giữa các chuyên khoa đã chọn.
  Widget _buildDepartmentTabs() {
    const blue = AppTheme.primaryBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: selectedIds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final id = selectedIds[i];
              final isActive = id == activeId;
              final isDone = hasSchedule(id);
              return Material(
                color: isActive ? blue : Colors.white,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isActive ? blue : AppTheme.borderColor,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSwitchActiveDepartment(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 17,
                          color: isActive
                              ? Colors.white
                              : (isDone
                                    ? AppTheme.primaryGreen
                                    : const Color(0xFFB8C4D2)),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            getDepartmentName(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Đã chọn lịch cho $doneCount/${selectedIds.length} chuyên khoa',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: doneCount == selectedIds.length
                ? AppTheme.primaryGreen
                : AppTheme.textGrey,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// _buildDayStrip: dải ngày khám cuộn ngang.
  Widget _buildDayStrip() {
    const blue = AppTheme.primaryBlue;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = days[i]['date'] as DateTime;
          final isSelected =
              selectedDay != null &&
              BookingHelper.isSameDay(date, selectedDay!);
          return Material(
            color: isSelected ? blue : Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
              side: BorderSide(color: isSelected ? blue : AppTheme.borderColor),
            ),
            child: InkWell(
              onTap: () => onDaySelected(activeId!, selectedRoomId!, date),
              child: SizedBox(
                width: 62,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      days[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white.withOpacity(0.85)
                            : AppTheme.textGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[i]['day'] as String,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// _buildSelectedSummary: khung tóm tắt lịch khám vừa chọn.
  Widget _buildSelectedSummary() {
    const green = AppTheme.primaryGreen;
    final slot = selectedSlot!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.tint(green, 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lịch khám đã chọn',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: green,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  getRoomName(activeId!, selectedRoomId!),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ngày ${formatDayMonth(selectedDay!)} · ${slot.tenCa} (${slot.gioBatDau} - ${slot.gioKetThuc})',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = AppTheme.primaryBlue;
    const title = SectionTitle(
      icon: Icons.event_available_rounded,
      text: 'Chọn phòng, ngày và giờ khám',
      required: true,
    );

    if (activeId == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Icon(Icons.calendar_month_rounded, size: 34, color: blue),
                SizedBox(height: 12),
                Text(
                  'Chưa chọn chuyên khoa',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chọn chuyên khoa ở trên để xem phòng khám,\nngày và khung giờ khám.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 12),
        if (selectedIds.length > 1) _buildDepartmentTabs(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lịch khám của',
                style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
              ),
              const SizedBox(height: 2),
              Text(
                getDepartmentName(activeId!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const Divider(height: 28, color: AppTheme.borderColor),
              BookingStepTitle(
                step: 1,
                text: 'Chọn phòng khám',
                done: selectedRoomId != null,
              ),
              const SizedBox(height: 12),
              RoomSelectionList(
                activeId: activeId!,
                isLoading: isLoadingRooms,
                error: roomError,
                rooms: rooms,
                selectedRoomId: selectedRoomId,
                onSelect: onRoomSelected,
                onRetry: onRetryFetch,
              ),
              if (selectedRoomId == null) ...[
                const SizedBox(height: 14),
                const StatePanel(
                  icon: Icons.lock_clock_rounded,
                  text: 'Chọn phòng khám để xem ngày và khung giờ khám.',
                  color: AppTheme.textGrey,
                ),
              ] else ...[
                const Divider(height: 28, color: AppTheme.borderColor),
                BookingStepTitle(
                  step: 2,
                  text: 'Chọn ngày khám',
                  done: selectedDay != null,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          onOpenCalendar(activeId!, selectedRoomId!),
                      style: TextButton.styleFrom(
                        foregroundColor: blue,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text(
                        'Xem lịch tháng',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildDayStrip(),
                const Divider(height: 28, color: AppTheme.borderColor),
                BookingStepTitle(
                  step: 3,
                  text: 'Chọn khung giờ khám',
                  done: selectedSlot != null,
                ),
                const SizedBox(height: 12),
                SlotSelectionList(
                  activeId: activeId!,
                  roomId: selectedRoomId!,
                  selectedDay: selectedDay,
                  lichHen: lichHen,
                  hospitalId: hospitalId,
                  getRoomMax: getRoomMax,
                  onSlotSelected: onSlotSelected,
                  selectedCaId: selectedSlot?.caId,
                  waitingByCa: waitingByCa,
                ),
                if (selectedDay != null && selectedSlot != null) ...[
                  const SizedBox(height: 16),
                  _buildSelectedSummary(),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// CrowdLevel: mức độ đông của một ca khám kèm nhãn và màu hiển thị.
enum CrowdLevel {
  quiet('Vắng', Color(0xFF0E9F6E)),
  moderate('Vừa phải', Color(0xFFC98A00)),
  busy('Đông', Color(0xFFE5701B)),
  veryBusy('Rất đông', Color(0xFFC62828));

  final String label;
  final Color color;
  const CrowdLevel(this.label, this.color);

  /// fromRatio: xác định mức đông theo tỷ lệ số người trên sức chứa của ca.
  static CrowdLevel fromRatio(double ratio) {
    if (ratio < 0.4) return CrowdLevel.quiet;
    if (ratio < 0.7) return CrowdLevel.moderate;
    if (ratio < 0.9) return CrowdLevel.busy;
    return CrowdLevel.veryBusy;
  }

  /// fromCount: xác định mức đông theo số người khi ca không có sức chứa cố định.
  static CrowdLevel fromCount(int count) {
    if (count < 10) return CrowdLevel.quiet;
    if (count < 25) return CrowdLevel.moderate;
    if (count < 40) return CrowdLevel.busy;
    return CrowdLevel.veryBusy;
  }
}

/// CrowdInfo: số người và mức đông đã tính của một ca khám.
class CrowdInfo {
  final CaSlotModel slot;
  final int booked;
  final CrowdLevel level;

  const CrowdInfo._(this.slot, this.booked, this.level);

  /// CrowdInfo.of: tính số người và mức đông của một ca, ưu tiên số người đang chờ nếu có.
  factory CrowdInfo.of(CaSlotModel slot, {int? waiting}) {
    final total = slot.tongSo;
    final used = total > 0 ? (total - slot.conLai < 0 ? 0 : total - slot.conLai) : 0;
    final booked = waiting ?? used;
    final level = total > 0
        ? CrowdLevel.fromRatio(booked / total)
        : CrowdLevel.fromCount(booked);
    return CrowdInfo._(slot, booked, level);
  }

  bool get isFull => slot.tongSo > 0 && slot.conLai <= 0;

  /// heightFactor: tỷ lệ chiều cao cột từ 0 đến 1, theo sức chứa hoặc theo ca đông nhất.
  double heightFactor(int maxBooked) {
    final base = slot.tongSo > 0
        ? booked / slot.tongSo
        : (maxBooked > 0 ? booked / maxBooked : 0.0);
    return base.clamp(0.0, 1.0).toDouble();
  }
}

/// SlotCrowdChart: biểu đồ cột độ đông theo từng ca khám, bấm vào cột để chọn ca.
class SlotCrowdChart extends StatelessWidget {
  final List<CaSlotModel> slots;
  final String? selectedCaId;
  final Map<String, int>? waitingByCa;
  final ValueChanged<String> onSelect;

  const SlotCrowdChart({
    super.key,
    required this.slots,
    required this.selectedCaId,
    required this.onSelect,
    this.waitingByCa,
  });

  static const double _maxBarHeight = 96;

  /// _buildBar: dựng cột biểu đồ, nhãn ca và giờ của một ca khám.
  Widget _buildBar(CrowdInfo info, int maxBooked) {
    final slot = info.slot;
    final selected = selectedCaId == slot.caId;
    final color = info.level.color;
    final barHeight = 6 + (_maxBarHeight - 6) * info.heightFactor(maxBooked);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: info.isFull ? null : () => onSelect(slot.caId),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${info.booked}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                height: barHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: selected
                      ? Border.all(color: AppTheme.textDark, width: 2)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.tint(AppTheme.primaryBlue, 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      slot.tenCa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppTheme.primaryBlue
                            : AppTheme.textDark,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${slot.gioBatDau} - ${slot.gioKetThuc}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ),
                    if (info.isFull)
                      const Text(
                        'Hết chỗ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// _buildLegend: chú thích bốn mức độ đông bằng chấm màu.
  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final level in CrowdLevel.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: level.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                level.label,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textGrey),
              ),
            ],
          ),
      ],
    );
  }

  /// _buildTip: gợi ý ca ít người nhất khi các ca còn chỗ có mức đông khác nhau.
  Widget? _buildTip(List<CrowdInfo> infos, int maxBooked) {
    final available = infos.where((e) => !e.isFull).toList();
    if (available.length < 2) return null;
    final best = available.reduce(
      (a, b) => a.heightFactor(maxBooked) <= b.heightFactor(maxBooked) ? a : b,
    );
    final worst = available.reduce(
      (a, b) => a.heightFactor(maxBooked) >= b.heightFactor(maxBooked) ? a : b,
    );
    if (best.level.index >= worst.level.index) return null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.tint(AppTheme.primaryGreen, 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ca ít người nhất: ${best.slot.tenCa} (${best.slot.gioBatDau} - ${best.slot.gioKetThuc}), thường chờ ngắn hơn.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final infos = [
      for (final slot in slots)
        CrowdInfo.of(slot, waiting: waitingByCa?[slot.caId]),
    ];
    final maxBooked = infos.fold<int>(0, (m, e) => e.booked > m ? e.booked : m);
    final tip = _buildTip(infos, maxBooked);

    return Material(
      color: AppTheme.mutedFill,
      borderRadius: BorderRadius.circular(AppTheme.radiusItem),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Độ đông theo khung giờ',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                waitingByCa != null
                    ? 'Số người đang chờ của từng ca'
                    : 'Số lượt đã đặt của từng ca',
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final info in infos) _buildBar(info, maxBooked)],
            ),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 10),
            _buildLegend(),
            if (tip != null) tip,
          ],
        ),
      ),
    );
  }
}

/// SlotSelectionList: biểu đồ độ đông và danh sách ca khám của ngày đã chọn.
class SlotSelectionList extends StatelessWidget {
  final String activeId;
  final String roomId;
  final DateTime? selectedDay;
  final LichHenProvider lichHen;
  final String hospitalId;
  final String? selectedCaId;
  final int Function(String, String) getRoomMax;
  final Function(String, String, String) onSlotSelected;
  final Map<String, int>? waitingByCa;

  const SlotSelectionList({
    super.key,
    required this.activeId,
    required this.roomId,
    required this.selectedDay,
    required this.lichHen,
    required this.hospitalId,
    required this.getRoomMax,
    required this.onSlotSelected,
    required this.selectedCaId,
    this.waitingByCa,
  });

  /// _buildSlotTile: dựng một dòng ca khám với thanh số chỗ còn trống.
  Widget _buildSlotTile(CaSlotModel slot) {
    final left = slot.conLai;
    final total = slot.tongSo;
    final isUnknownTotal = total <= 0;
    final isFull = !isUnknownTotal && left <= 0;
    final color = isUnknownTotal
        ? AppTheme.primaryGreen
        : BookingHelper.availabilityColor(left, total);
    final isMorning =
        slot.caId.toLowerCase().contains('sang') ||
        slot.tenCa.toLowerCase().contains('sáng');

    return SelectionTile(
      icon: isMorning ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded,
      iconColor: isMorning ? const Color(0xFFD97706) : const Color(0xFF4F46E5),
      iconBackground: isMorning
          ? const Color(0xFFFEF3C7)
          : const Color(0xFFE0E7FF),
      title: slot.tenCa,
      subtitle: '${slot.gioBatDau} - ${slot.gioKetThuc}',
      selected: selectedCaId == slot.caId,
      disabled: isFull,
      onTap: () => onSlotSelected(activeId, roomId, slot.caId),
      footer: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? left / total : 1.0,
                minHeight: 6,
                backgroundColor: AppTheme.tint(color, 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isFull
                ? 'Hết chỗ'
                : isUnknownTotal
                ? 'Còn trống'
                : 'Còn $left/$total chỗ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const StatePanel(
        icon: Icons.touch_app_rounded,
        text: 'Chọn ngày khám để xem các khung giờ còn trống.',
        color: AppTheme.textGrey,
      );
    }

    final key = BookingHelper.slotKeyFor(
      departmentId: activeId,
      roomId: roomId,
      date: selectedDay!,
      hospitalId: hospitalId,
    );
    final error = lichHen.slotsErrorOf(key);

    if (error != null) {
      return StatePanel(
        icon: Icons.error_outline_rounded,
        text: error,
        color: AppTheme.danger,
        onRetry: () => lichHen.loadSlots(
          ngay: selectedDay!,
          benhVienId: hospitalId,
          khoaId: activeId,
          phongKhamId: roomId,
          soBenhNhanToiDa: getRoomMax(activeId, roomId),
          force: true,
        ),
      );
    }

    if (lichHen.isLoadingSlots(key) || !lichHen.hasLoadedSlots(key)) {
      return const LoadingBox();
    }

    final slots = lichHen.slotsOf(key);
    if (slots.isEmpty) {
      return const StatePanel(
        icon: Icons.event_busy_rounded,
        text: 'Phòng khám chưa có lịch khám vào ngày này.\nVui lòng chọn ngày khác.',
        color: AppTheme.textGrey,
      );
    }

    return Column(
      children: [
        if (slots.length >= 2) ...[
          SlotCrowdChart(
            slots: slots,
            selectedCaId: selectedCaId,
            waitingByCa: waitingByCa,
            onSelect: (caId) => onSlotSelected(activeId, roomId, caId),
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < slots.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == slots.length - 1 ? 0 : 10),
            child: _buildSlotTile(slots[i]),
          ),
      ],
    );
  }
}

/// LocationSection: bản đồ minh họa vị trí, nút chỉ đường và sao chép địa chỉ.
class LocationSection extends StatelessWidget {
  final Map<String, dynamic> hospitalData;

  const LocationSection({super.key, required this.hospitalData});

  static double? _toCoordinate(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  /// _openGoogleMaps: mở Google Maps chỉ đường tới bệnh viện.
  Future<void> _openGoogleMaps(
    BuildContext context,
    double? latitude,
    double? longitude,
  ) async {
    if (latitude == null || longitude == null) {
      context.showAppSnackBar(
        title: 'Thiếu tọa độ bản đồ',
        message: 'Bệnh viện chưa có tọa độ bản đồ',
        type: SnackBarType.warning,
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      context.showAppSnackBar(
        title: 'Không thể mở bản đồ',
        message: 'Không thể mở bản đồ',
        type: SnackBarType.error,
      );
    }
  }

  /// _copyAddress: sao chép địa chỉ bệnh viện vào clipboard.
  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      context.showAppSnackBar(
        title: 'Sao chép thành công',
        message: 'Đã sao chép địa chỉ',
        type: SnackBarType.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude = _toCoordinate(hospitalData['vi_do']);
    final longitude = _toCoordinate(hospitalData['kinh_do']);
    final hasCoordinates = latitude != null && longitude != null;
    final name = hospitalData['ten_benh_vien']?.toString() ?? 'Bệnh viện';
    final address =
        hospitalData['dia_chi']?.toString() ?? 'Địa chỉ chưa cập nhật';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(icon: Icons.map_rounded, text: 'Vị trí bệnh viện'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: AppTheme.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: InkWell(
                    onTap: () => _openGoogleMaps(context, latitude, longitude),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(
                          painter: MiniMapPainter(accent: AppTheme.primaryBlue),
                        ),
                        Align(
                          alignment: const Alignment(0, -0.15),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.danger,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.danger.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 120,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasCoordinates
                                      ? Icons.place_rounded
                                      : Icons.location_off_rounded,
                                  size: 15,
                                  color: hasCoordinates
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textGrey,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    hasCoordinates
                                        ? name
                                        : 'Chưa có tọa độ bản đồ',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: hasCoordinates
                                  ? AppTheme.primaryBlue
                                  : Colors.grey.shade500,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Chỉ đường',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Địa chỉ',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textGrey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sao chép địa chỉ',
                        onPressed: () => _copyAddress(context, address),
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 19,
                          color: AppTheme.primaryBlue,
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
    );
  }
}

/// ReviewSection: tổng quan và danh sách đánh giá của chuyên khoa đang xem.
class ReviewSection extends StatefulWidget {
  final String? activeId;
  final Set<String> selectedDepartmentIds;
  final String hospitalId;
  final String Function(String) getDepartmentName;

  const ReviewSection({
    super.key,
    required this.activeId,
    required this.selectedDepartmentIds,
    required this.hospitalId,
    required this.getDepartmentName,
  });

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  int _selectedStar = 5;
  int _reviewVisibleCount = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReviewsForActive();
    });
  }

  @override
  void didUpdateWidget(covariant ReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId) {
      setState(() {
        _selectedStar = 5;
        _reviewVisibleCount = 5;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadReviewsForActive(force: true);
      });
    }
  }

  /// _loadReviewsForActive: tải đánh giá của chuyên khoa đang xem, xóa nếu chưa chọn.
  void _loadReviewsForActive({bool force = false}) {
    final provider = context.read<ReviewProvider>();
    final id = widget.activeId;

    if (id == null ||
        id.isEmpty ||
        !widget.selectedDepartmentIds.contains(id)) {
      provider.clearReviews();
      return;
    }
    if (widget.hospitalId.isEmpty) return;

    provider.fetchReviews(
      hospitalId: widget.hospitalId,
      khoaId: id,
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDepartment =
        widget.activeId != null &&
        widget.selectedDepartmentIds.contains(widget.activeId);

    return Consumer<ReviewProvider>(
      builder: (context, reviewProvider, child) {
        final total = reviewProvider.totalCount;
        final counts = reviewProvider.countByStar;
        final starReviews = reviewProvider.reviewsByStar(_selectedStar);
        final visible = starReviews.take(_reviewVisibleCount).toList();

        const avatarColors = [
          Color(0xFFD6E8FA),
          Color(0xFFFFE8CC),
          Color(0xFFD3F0E3),
          Color(0xFFE6DDF5),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              icon: Icons.rate_review_rounded,
              text: 'Đánh giá và nhận xét',
              trailing: hasDepartment
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: InfoPill(
                        text: widget.getDepartmentName(widget.activeId!),
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            if (!hasDepartment)
              const StatePanel(
                icon: Icons.touch_app_rounded,
                text: 'Chọn chuyên khoa để xem đánh giá của khoa đó.',
                color: AppTheme.primaryBlue,
              )
            else if (reviewProvider.isLoading)
              const LoadingBox()
            else if (reviewProvider.error != null)
              StatePanel(
                icon: Icons.error_outline_rounded,
                text: reviewProvider.error!,
                color: AppTheme.danger,
                onRetry: () => _loadReviewsForActive(force: true),
              )
            else if (total == 0)
              const StatePanel(
                icon: Icons.rate_review_outlined,
                text: 'Chưa có đánh giá nào cho chuyên khoa này.',
                color: AppTheme.textGrey,
              )
            else ...[
              _buildReviewSummary(reviewProvider.averageRating, total, counts),
              const SizedBox(height: 14),
              Row(
                children: [5, 4, 3, 2, 1]
                    .map(
                      (star) => _buildStarTab(
                        star: star,
                        count: counts[star] ?? 0,
                        selected: star == _selectedStar,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey<int>(_selectedStar),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: starReviews.isEmpty
                      ? <Widget>[
                          StatePanel(
                            icon: Icons.star_border_rounded,
                            text: 'Chưa có đánh giá $_selectedStar sao nào.',
                            color: AppTheme.textGrey,
                          ),
                        ]
                      : List<Widget>.generate(visible.length, (index) {
                          final review = visible[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == visible.length - 1 ? 0 : 12,
                            ),
                            child: _buildReviewCard(
                              name: review.displayName,
                              rating: review.diemDanhGia,
                              comment: review.nhanXet,
                              avatarText: BookingHelper.reviewerInitial(review),
                              avatarColor:
                                  avatarColors[index % avatarColors.length],
                              timeAgo: BookingHelper.getTimeAgo(review.ngayTao),
                            ),
                          );
                        }),
                ),
              ),
              if (starReviews.length > visible.length) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _reviewVisibleCount += 5),
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    label: Text(
                      'Xem thêm ${starReviews.length - visible.length} đánh giá',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: BorderSide(
                        color: AppTheme.tint(AppTheme.primaryBlue, 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusItem,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  /// _buildReviewSummary: khối điểm trung bình và biểu đồ phân bố số sao.
  Widget _buildReviewSummary(double average, int total, Map<int, int> counts) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Column(
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                BookingHelper.starRow(average, size: 15, center: true),
                const SizedBox(height: 8),
                InfoPill(
                  text: BookingHelper.ratingLabelOfAverage(average),
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 6),
                Text(
                  '$total đánh giá',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = counts[star] ?? 0;
                final fraction = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 10,
                        child: Text(
                          '$star',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppTheme.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fraction.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppTheme.mutedFill,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.amber,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// _buildStarTab: nút lọc đánh giá theo số sao.
  Widget _buildStarTab({
    required int star,
    required int count,
    required bool selected,
  }) {
    const blue = AppTheme.primaryBlue;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: star == 1 ? 0 : 8),
        child: Material(
          color: selected ? blue : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            side: BorderSide(color: selected ? blue : AppTheme.borderColor),
          ),
          child: InkWell(
            onTap: () => setState(() {
              _selectedStar = star;
              _reviewVisibleCount = 5;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$star',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : (count == 0
                                    ? AppTheme.textGrey
                                    : AppTheme.textDark),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: selected
                            ? Colors.white
                            : (count == 0
                                  ? const Color(0xFFB8C4D2)
                                  : AppTheme.amber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// _buildReviewCard: thẻ một đánh giá gồm người viết, số sao và nhận xét.
  Widget _buildReviewCard({
    required String name,
    required int rating,
    required String comment,
    required String avatarText,
    required Color avatarColor,
    required String timeAgo,
  }) {
    final chipText = BookingHelper.ratingChipText(rating);
    final chipColor = BookingHelper.ratingChipColor(rating);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    avatarText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        BookingHelper.starRow(rating.toDouble(), size: 15),
                        const SizedBox(width: 8),
                        InfoPill(text: chipText, color: chipColor),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpandableText(
                text: comment.trim(),
                accent: AppTheme.primaryBlue,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// BookingBottomActionArea: thanh cố định phía dưới chứa nút tiếp tục đặt lịch.
class BookingBottomActionArea extends StatelessWidget {
  final Color color;
  final VoidCallback onContinue;

  const BookingBottomActionArea({
    super.key,
    required this.color,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusItem),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tiếp tục đặt lịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// MiniMapPainter: vẽ bản đồ phác họa với đường phố, sông và lộ trình minh họa.
class MiniMapPainter extends CustomPainter {
  final Color accent;
  const MiniMapPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF0F6),
    );
    const cols = 6;
    const rows = 4;
    final cw = w / cols;
    final ch = h / rows;
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 9;
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cw, 0), Offset(c * cw, h), roadPaint);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * ch), Offset(w, r * ch), roadPaint);
    }
    final blockPaint = Paint()..color = const Color(0xFFDDE6EF);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * cw + 8, r * ch + 8, cw - 16, ch - 16),
            const Radius.circular(6),
          ),
          blockPaint,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.12, w * 0.22, h * 0.34),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFFCFE9DC),
    );
    final river = Path()
      ..moveTo(w * 0.66, -10)
      ..cubicTo(w * 0.56, h * 0.3, w * 0.84, h * 0.6, w * 0.74, h + 10);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFFBFDDF3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );
    final avenue = Path()
      ..moveTo(-10, h * 0.78)
      ..lineTo(w + 10, h * 0.3);
    canvas.drawPath(
      avenue,
      Paint()
        ..color = const Color(0xFFD3DCE6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    canvas.drawPath(
      avenue,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    final route = Path()
      ..moveTo(w * 0.08, h * 0.96)
      ..cubicTo(w * 0.3, h * 0.84, w * 0.3, h * 0.66, w * 0.5, h * 0.6);
    final routePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final metric in route.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 10),
          routePaint,
        );
        distance += 18;
      }
    }
  }

  @override
  bool shouldRepaint(covariant MiniMapPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// ExpandableText: đoạn văn dài tự rút gọn 3 dòng, bấm để xem thêm hoặc thu gọn.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color accent;

  const ExpandableText({
    super.key,
    required this.text,
    required this.style,
    required this.accent,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  static const int _collapsedLines = 3;
  static const int _longThreshold = 140;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > _longThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: (_expanded || !isLong) ? null : _collapsedLines,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          ),
        ),
        if (isLong)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _expanded ? 'Thu gọn' : 'Xem thêm',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}