import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';

class PatientManagementScreen extends StatefulWidget {
  final bool isEmbedded;
  const PatientManagementScreen({super.key, this.isEmbedded = false});

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _statusFilter = 0; // 0: Tất cả, 1: Hoạt động, 2: Bị khóa
  String _searchQuery = '';

  int _globalChartMode = 0; // 0: Theo Ngày, 1: Theo Tháng, 2: Theo Năm
  int? _selectedGlobalBarIndex;
  bool _isGlobalStatsExpanded = true;
  Future<Map<String, dynamic>>? _globalStatsFuture;

  @override
  void initState() {
    super.initState();
    _loadGlobalStats();
    AdminStore.instance.addListener(_onStoreUpdate);
  }

  void _loadGlobalStats() {
    _globalStatsFuture = AdminStore.instance.getGlobalActivityStats();
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_onStoreUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStoreUpdate() {
    _loadGlobalStats();
    if (mounted) setState(() {});
  }

  List<AdminPatient> _getFilteredPatients() {
    final list = AdminStore.instance.patients;
    return list.where((p) {
      // 1. Lọc theo trạng thái
      if (_statusFilter == 1 && !p.isActive) return false;
      if (_statusFilter == 2 && p.isActive) return false;

      // 2. Lọc theo từ khóa tìm kiếm
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = p.hoTen.toLowerCase().contains(q);
        final codeMatch = p.maBenhNhan.toLowerCase().contains(q);
        final emailMatch = (p.email ?? '').toLowerCase().contains(q);
        final phoneMatch = (p.soDienThoai ?? '').contains(q);
        return nameMatch || codeMatch || emailMatch || phoneMatch;
      }
      return true;
    }).toList();
  }

  // ================= DIALOG KHÓA TÀI KHOẢN =================
  void _showBlockDialog(AdminPatient patient) {
    final reasonCtrl = TextEditingController(text: 'Vi phạm quy định đặt lịch khám');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: kRed, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Khóa tài khoản bệnh nhân',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn đang thực hiện tạm khóa tài khoản của bệnh nhân ${patient.hoTen} (${patient.maBenhNhan}).',
                style: const TextStyle(color: kSlate600, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              const Text(
                'Lý do tạm khóa:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kSlate800),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập lý do khóa tài khoản...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kRed),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Spam đặt lịch hủy nhiều lần',
                  'Thông tin giả mạo',
                  'Vi phạm quy định sử dụng',
                ].map((preset) => ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                  backgroundColor: kSlate100,
                  onPressed: () => reasonCtrl.text = preset,
                )).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ', style: TextStyle(color: kSlate600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Xác nhận khóa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final reason = reasonCtrl.text.trim().isEmpty
                  ? 'Vi phạm quy chế sử dụng hệ thống'
                  : reasonCtrl.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await AdminStore.instance.blockPatient(patient, reason);
              final emailNotice = patient.email != null && patient.email!.isNotEmpty
                  ? ' và gửi email thông báo tới ${patient.email}'
                  : '';
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Đã khóa tài khoản bệnh nhân ${patient.hoTen}$emailNotice.'),
                  backgroundColor: kRed,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= DIALOG MỞ KHÓA TÀI KHOẢN =================
  void _showUnblockDialog(AdminPatient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF16A34A), size: 24),
            SizedBox(width: 10),
            Text('Mở khóa tài khoản', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Kích hoạt lại tài khoản cho bệnh nhân ${patient.hoTen} (${patient.maBenhNhan})? Bệnh nhân sẽ có thể đăng nhập và đặt lịch khám trở lại bình thường.',
          style: const TextStyle(color: kSlate600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ', style: TextStyle(color: kSlate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await AdminStore.instance.unblockPatient(patient);
              final emailNotice = patient.email != null && patient.email!.isNotEmpty
                  ? ' và gửi email thông báo tới ${patient.email}'
                  : '';
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Đã mở khóa tài khoản cho ${patient.hoTen}$emailNotice.'),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            },
            child: const Text('Mở khóa ngay'),
          ),
        ],
      ),
    );
  }

  // ================= DIALOG XÓA TÀI KHOẢN =================
  void _showDeleteDialog(AdminPatient patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kRed, size: 24),
            SizedBox(width: 10),
            Text('Xóa vĩnh viễn tài khoản?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động này sẽ xóa hoàn toàn hồ sơ của bệnh nhân ${patient.hoTen} (${patient.maBenhNhan}) khỏi Firestore và xóa vĩnh viễn tài khoản khỏi Firebase Authentication. Không thể khôi phục sau khi xóa!',
              style: const TextStyle(color: kSlate600, fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ', style: TextStyle(color: kSlate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final emailNotice = patient.email != null && patient.email!.isNotEmpty
                  ? ' và gửi email thông báo tới ${patient.email}'
                  : '';
              await AdminStore.instance.deletePatientAccount(patient);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Đã xóa tài khoản bệnh nhân ${patient.hoTen}$emailNotice.'),
                  backgroundColor: kSlate900,
                ),
              );
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  // ================= CHI TIẾT BỆNH NHÂN (BOTTOM SHEET) =================
  void _showPatientDetails(AdminPatient patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: AdminStore.instance,
          // Lấy patient mới nhất từ store mỗi khi store thay đổi
          builder: (context, _) {
            final updatedPatient = AdminStore.instance.patients
                .firstWhere((p) => p.uid == patient.uid, orElse: () => patient);
            return _buildPatientDetailSheet(ctx, updatedPatient);
          },
        );
      },
    );
  }

  Widget _buildPatientDetailSheet(BuildContext ctx, AdminPatient patient) {
    int chartMode = 0; // 0: Theo Ngày (7 ngày), 1: Theo Tháng (12 tháng), 2: Theo Năm
    int? selectedBarIndex;

    return StatefulBuilder(
      builder: (modalCtx, setModalState) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSlate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: patient.avatarBg,
                      child: Text(
                        patient.initials,
                        style: TextStyle(
                          color: patient.avatarText,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  patient.hoTen,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: kSlate900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kPrimaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  patient.maBenhNhan,
                                  style: const TextStyle(
                                    color: kPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: patient.isActive ? const Color(0xFF16A34A) : kRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                patient.isActive ? 'Tài khoản hoạt động' : 'Tài khoản bị tạm khóa',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: patient.isActive ? const Color(0xFF16A34A) : kRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: kSlate400),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kBorder),

              // Nội dung chi tiết cuộn được
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Cảnh báo nếu bị khóa
                    if (!patient.isActive) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kRedBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: kRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tài khoản đang bị chặn đăng nhập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: kRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    patient.blockReason ?? 'Không có lý do cụ thể.',
                                    style: const TextStyle(fontSize: 12, color: kSlate700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Card thông tin cá nhân
                    _buildSectionHeader('Thông tin liên hệ & Hồ sơ', Icons.person_outline_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            'Email',
                            patient.email ?? 'Chưa đăng ký email',
                            trailing: patient.daXacThucEmail
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                                      SizedBox(width: 4),
                                      Text('Đã xác thực', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  )
                                : const Text('Chưa xác thực', style: TextStyle(color: kAmber, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow('Số điện thoại', patient.soDienThoai ?? 'Chưa cập nhật'),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow('Giới tính', patient.gioiTinh ?? 'Chưa xác định'),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow(
                            'Ngày sinh',
                            patient.ngaySinh != null
                                ? '${patient.ngaySinh!.day}/${patient.ngaySinh!.month}/${patient.ngaySinh!.year}'
                                : 'Chưa cập nhật',
                          ),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow('Địa chỉ', patient.diaChi ?? 'Chưa cập nhật'),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow(
                            'Ngày tham gia',
                            patient.ngayTao != null
                                ? '${patient.ngayTao!.day}/${patient.ngayTao!.month}/${patient.ngayTao!.year}'
                                : 'Mới tham gia',
                          ),
                          const Divider(height: 16, color: kBorder),
                          _buildDetailRow('UID hệ thống', patient.uid, isMonospace: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ================= PHẦN QUẢN LÝ HOẠT ĐỘNG, THỜI GIAN OFFLINE & BIỂU ĐỒ =================
                    _buildSectionHeader('Quản lý dữ liệu hoạt động & Tần suất', Icons.insights_rounded),
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, dynamic>>(
                      future: AdminStore.instance.getPatientActivityStats(patient),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                            ),
                          );
                        }

                        final stats = snapshot.data ?? {};
                        final offlineDurationText = stats['offlineDurationText']?.toString() ?? 'Chưa xác định';
                        final offlineStart = stats['offlineStart'] as DateTime? ?? patient.effectiveOfflineTime;
                        final totalAppointments = stats['totalAppointments'] ?? 0;
                        final completedCount = stats['completedCount'] ?? 0;
                        final cancelledCount = stats['cancelledCount'] ?? 0;
                        final freqPerMonth = stats['freqPerMonth']?.toString() ?? '0.0';
                        final freqPerWeek = stats['freqPerWeek']?.toString() ?? '0.0';
                        final totalDaysJoined = stats['totalDaysJoined'] ?? 1;

                        final dailyChart = (stats['dailyChart'] as List<Map<String, dynamic>>?) ?? [];
                        final monthlyChart = (stats['monthlyChart'] as List<Map<String, dynamic>>?) ?? [];
                        final yearlyChart = (stats['yearlyChart'] as List<Map<String, dynamic>>?) ?? [];
                        final chartData = chartMode == 0
                            ? dailyChart
                            : (chartMode == 1 ? monthlyChart : yearlyChart);

                        final maxVal = chartData.map((e) => (e['count'] as int?) ?? 0).fold(1, (prev, curr) => curr > prev ? curr : prev);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Trạng thái Offline / Online từ lúc bắt đầu off đến giờ
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: patient.isActive
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: patient.isActive
                                      ? const Color(0xFFBBF7D0)
                                      : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: patient.isActive
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFFEE2E2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          patient.isActive
                                              ? Icons.wifi_rounded
                                              : Icons.power_settings_new_rounded,
                                          color: patient.isActive ? const Color(0xFF16A34A) : kRed,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              patient.isActive
                                                  ? 'Trạng thái: Đang hoạt động'
                                                  : 'Thời gian ngưng hoạt động (Bắt đầu off):',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: patient.isActive
                                                    ? const Color(0xFF15803D)
                                                    : const Color(0xFF991B1B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              patient.isActive
                                                  ? 'Lần hoạt động/đăng nhập: $offlineDurationText'
                                                  : 'Bắt đầu off từ: ${_formatDateTime(offlineStart)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: kSlate900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!patient.isActive) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFCA5A5)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, color: kRed, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(fontSize: 12.5, color: kSlate700),
                                                children: [
                                                  const TextSpan(text: 'Từ lúc bắt đầu off đến giờ: '),
                                                  TextSpan(
                                                    text: offlineDurationText,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      color: kRed,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Các thẻ chỉ số tần suất hoạt động
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Tần suất TB', style: TextStyle(fontSize: 11, color: kSlate500)),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '$freqPerMonth lượt/tháng',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: kPrimary,
                                            ),
                                          ),
                                        ),
                                        Text('$freqPerWeek lượt/tuần', style: const TextStyle(fontSize: 10.5, color: kSlate400), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Tổng lịch hẹn', style: TextStyle(fontSize: 11, color: kSlate500)),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '$totalAppointments lượt',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: kSlate900,
                                            ),
                                          ),
                                        ),
                                        Text('Xong: $completedCount · Hủy: $cancelledCount', style: const TextStyle(fontSize: 10.5, color: kSlate500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Thời gian tham gia', style: TextStyle(fontSize: 11, color: kSlate500)),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '$totalDaysJoined ngày',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: kSlate900,
                                            ),
                                          ),
                                        ),
                                        Text('Tỉ lệ xong: ${totalAppointments > 0 ? ((completedCount / totalAppointments) * 100).toStringAsFixed(0) : 0}%', style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ================= BIỂU ĐỒ HOẠT ĐỘNG (NGÀY / THÁNG / NĂM) =================
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: kBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Biểu đồ tần suất hoạt động',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: kSlate900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(child: _buildChartModePill(chartMode, 0, 'Ngày', () => setModalState(() { chartMode = 0; selectedBarIndex = null; }))),
                                            Expanded(child: _buildChartModePill(chartMode, 1, 'Tháng', () => setModalState(() { chartMode = 1; selectedBarIndex = null; }))),
                                            Expanded(child: _buildChartModePill(chartMode, 2, 'Năm', () => setModalState(() { chartMode = 2; selectedBarIndex = null; }))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // Thanh Bar Chart
                                  SizedBox(
                                    height: 130,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: List.generate(chartData.length, (i) {
                                        final item = chartData[i];
                                        final count = (item['count'] as int?) ?? 0;
                                        final label = item['label']?.toString() ?? '';
                                        final isSelected = selectedBarIndex == i;
                                        final heightRatio = (count / maxVal).clamp(0.0, 1.0);
                                        final barHeight = count > 0 ? (heightRatio * 75).clamp(16.0, 75.0) : 6.0;

                                        return Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                selectedBarIndex = isSelected ? null : i;
                                              });
                                            },
                                            child: Container(
                                              color: Colors.transparent,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  SizedBox(
                                                    height: 16,
                                                    child: count > 0
                                                        ? Text(
                                                            '$count',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w800,
                                                              color: isSelected ? kPrimary : kSlate600,
                                                            ),
                                                          )
                                                        : const SizedBox.shrink(),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 250),
                                                    width: 14,
                                                    height: barHeight,
                                                    decoration: BoxDecoration(
                                                      gradient: count > 0
                                                          ? LinearGradient(
                                                              begin: Alignment.topCenter,
                                                              end: Alignment.bottomCenter,
                                                              colors: isSelected
                                                                  ? [kPrimary, const Color(0xFF1D4ED8)]
                                                                  : [const Color(0xFF60A5FA), kPrimary],
                                                            )
                                                          : null,
                                                      color: count == 0 ? const Color(0xFFE2E8F0) : null,
                                                      borderRadius: BorderRadius.circular(4),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: kPrimary.withValues(alpha: 0.4),
                                                                blurRadius: 6,
                                                                offset: const Offset(0, 2),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    label,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                      color: isSelected ? kPrimary : kSlate400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),

                                  if (selectedBarIndex != null && selectedBarIndex! < chartData.length) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: kPrimaryLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: kPrimary, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Thời điểm ${chartData[selectedBarIndex!]['label']}: có ${chartData[selectedBarIndex!]['count']} lượt hoạt động / lịch hẹn khám.',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Lịch hẹn khám từ Firebase
                    _buildSectionHeader('Lịch sử đặt lịch khám', Icons.calendar_month_outlined),
                    const SizedBox(height: 10),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: AdminStore.instance.getPatientAppointments(patient.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final appointments = snapshot.data ?? [];
                        if (appointments.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                            ),
                            child: const Center(
                              child: Text(
                                'Bệnh nhân chưa có lịch hẹn khám nào trên hệ thống.',
                                style: TextStyle(color: kSlate500, fontSize: 12.5),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: appointments.take(5).map((app) {
                            final code = app['id']?.toString() ?? 'LH';
                            final hospital = app['ten_benh_vien']?.toString() ??
                                'Cơ sở y tế ID: ${app['benh_vien_id'] ?? ''}';
                            final dept = app['ten_khoa']?.toString() ??
                                app['khoa_id']?.toString() ??
                                '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.event_note, color: kPrimary, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hospital,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: kSlate900,
                                          ),
                                        ),
                                        if (dept.isNotEmpty)
                                          Text(
                                            dept,
                                            style: const TextStyle(fontSize: 11, color: kSlate500),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kSlate100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kSlate600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // CÁC THAO TÁC QUẢN TRỊ
                    _buildSectionHeader('Tác vụ quản lý tài khoản', Icons.admin_panel_settings_outlined),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: patient.isActive
                              ? ElevatedButton.icon(
                                  icon: const Icon(Icons.block_rounded, size: 16),
                                  label: const Text('Khóa tài khoản'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kRedBg,
                                    foregroundColor: kRed,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: kRed),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showBlockDialog(patient);
                                  },
                                )
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                                  label: const Text('Mở khóa tài khoản'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showUnblockDialog(patient);
                                  },
                                ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete_forever_rounded, size: 16),
                          label: const Text('Xóa TK'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSlate100,
                            foregroundColor: kRed,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDeleteDialog(patient);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartModePill(int currentMode, int index, String label, VoidCallback onTap) {
    final isSelected = currentMode == index;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? kPrimary : kSlate500,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kSlate800,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Widget? trailing, bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: kSlate500, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: kSlate900,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildGlobalKpiCard({
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: kSlate500, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              sub,
              style: const TextStyle(fontSize: 9.5, color: kSlate400, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalModePill(int index, String label) {
    final isSelected = _globalChartMode == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _globalChartMode = index;
          _selectedGlobalBarIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? kPrimary : kSlate500,
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalActivityOverview(AdminStore store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với nút thu gọn / mở rộng
          InkWell(
            onTap: () => setState(() => _isGlobalStatsExpanded = !_isGlobalStatsExpanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: kPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tần suất hoạt động chung toàn hệ thống',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: kSlate900,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Thống kê tổng hợp tất cả tài khoản bệnh nhân',
                          style: TextStyle(fontSize: 11, color: kSlate500),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isGlobalStatsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kSlate500,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (_isGlobalStatsExpanded) ...[
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _globalStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final totalAppointments = data['totalAppointments'] ?? 0;
                  final completedCount = data['completedCount'] ?? 0;
                  final cancelledCount = data['cancelledCount'] ?? 0;
                  final activePercent = data['activePercent']?.toString() ?? '0';
                  final avgPerDay = data['avgPerDay']?.toString() ?? '0.0';
                  final avgPerMonth = data['avgPerMonth']?.toString() ?? '0.0';

                  final dailyChart = (data['dailyChart'] as List<Map<String, dynamic>>?) ?? [];
                  final monthlyChart = (data['monthlyChart'] as List<Map<String, dynamic>>?) ?? [];
                  final yearlyChart = (data['yearlyChart'] as List<Map<String, dynamic>>?) ?? [];
                  final currentChart = _globalChartMode == 0
                      ? dailyChart
                      : (_globalChartMode == 1 ? monthlyChart : yearlyChart);

                  final maxCount = currentChart
                      .map((e) => (e['count'] as int?) ?? 0)
                      .fold(1, (prev, curr) => curr > prev ? curr : prev);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chỉ số KPI nhanh
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlobalKpiCard(
                              label: 'Lượt khám',
                              value: '$totalAppointments',
                              sub: 'Xong: $completedCount · Hủy: $cancelledCount',
                              valueColor: kSlate900,
                              icon: Icons.event_available_rounded,
                              iconBg: const Color(0xFFEFF6FF),
                              iconColor: kPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGlobalKpiCard(
                              label: 'Tần suất',
                              value: '$avgPerDay/ngày',
                              sub: '$avgPerMonth lượt/tháng',
                              valueColor: kPrimary,
                              icon: Icons.speed_rounded,
                              iconBg: const Color(0xFFF0FDF4),
                              iconColor: kGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildGlobalKpiCard(
                              label: 'Hoạt động',
                              value: '$activePercent%',
                              sub: '${data['activePatientsCount'] ?? 0}/${data['totalPatientsCount'] ?? 0} tài khoản',
                              valueColor: const Color(0xFF16A34A),
                              icon: Icons.people_alt_rounded,
                              iconBg: const Color(0xFFDCFCE7),
                              iconColor: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Thanh chuyển đổi Ngày / Tháng / Năm: xếp gọn gàng full-width không bao giờ tràn màn hình
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Biểu đồ tần suất chung:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: kSlate700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: _buildGlobalModePill(0, 'Theo Ngày')),
                                Expanded(child: _buildGlobalModePill(1, 'Theo Tháng')),
                                Expanded(child: _buildGlobalModePill(2, 'Theo Năm')),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Biểu đồ cột tổng thể
                      SizedBox(
                        height: 110,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(currentChart.length, (i) {
                            final item = currentChart[i];
                            final count = (item['count'] as int?) ?? 0;
                            final label = item['label']?.toString() ?? '';
                            final isSelected = _selectedGlobalBarIndex == i;
                            final heightRatio = (count / maxCount).clamp(0.0, 1.0);
                            final barHeight = count > 0 ? (heightRatio * 65).clamp(16.0, 65.0) : 5.0;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedGlobalBarIndex = isSelected ? null : i;
                                  });
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: 15,
                                        child: count > 0
                                            ? FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '$count',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected ? kPrimary : kSlate600,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      const SizedBox(height: 3),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        width: currentChart.length > 8 ? 12 : 16,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          gradient: count > 0
                                              ? LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: isSelected
                                                      ? [kPrimary, const Color(0xFF1D4ED8)]
                                                      : [const Color(0xFF38BDF8), kPrimary],
                                                )
                                              : null,
                                          color: count == 0 ? const Color(0xFFE2E8F0) : null,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: kPrimary.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? kPrimary : kSlate400,
                                          ),
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

                      if (_selectedGlobalBarIndex != null && _selectedGlobalBarIndex! < currentChart.length) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: kPrimary, size: 15),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Giai đoạn ${currentChart[_selectedGlobalBarIndex!]['label']}: Tổng cộng ${currentChart[_selectedGlobalBarIndex!]['count']} lượt hoạt động khám bệnh từ tất cả tài khoản.',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    final filtered = _getFilteredPatients();
    final activeCount = store.patients.where((p) => p.isActive).length;
    final blockedCount = store.patients.where((p) => !p.isActive).length;

    return Scaffold(
      backgroundColor: kBg,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: kSlate900),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Quản lý Bệnh nhân',
                style: TextStyle(
                  color: kSlate900,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              centerTitle: true,
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: LiveSyncBadge(),
                ),
              ],
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await AdminStore.instance.syncNow();
            if (mounted) setState(() {});
          },
          child: Column(
            children: [
              // HEADER KHI EMBEDDED
              if (widget.isEmbedded)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QUẢN TRỊ NGƯỜI DÙNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: kPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Quản lý Bệnh nhân',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: kSlate900,
                            ),
                          ),
                        ],
                      ),
                      LiveSyncBadge(),
                    ],
                  ),
                ),

              // THANH TÌM KIẾM & THỐNG KÊ NHANH
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // Ô tìm kiếm
                    SearchBox(
                      controller: _searchCtrl,
                      hint: 'Tìm theo tên, mã BN, SĐT, email...',
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab(0, 'Tất cả (${store.totalPatients})'),
                          const SizedBox(width: 8),
                          _buildFilterTab(1, 'Đang hoạt động ($activeCount)'),
                          const SizedBox(width: 8),
                          _buildFilterTab(2, 'Bị tạm khóa ($blockedCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: kBorder),

              // DANH SÁCH BỆNH NHÂN KÈM TỔNG QUAN TẦN SUẤT HOẠT ĐỘNG CHUNG
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _buildGlobalActivityOverview(store);
                    }

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: kSlate100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.people_outline_rounded, size: 36, color: kSlate400),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Không tìm thấy bệnh nhân nào',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kSlate700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
                                style: TextStyle(fontSize: 12.5, color: kSlate500),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final patient = filtered[i - 1];
                    return _buildPatientCard(patient);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final active = _statusFilter == index;
    return InkWell(
      onTap: () => setState(() => _statusFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kPrimary : kSlate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : kSlate700,
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(AdminPatient patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: patient.isActive ? kBorder : kRed.withValues(alpha: 0.4),
          width: patient.isActive ? 1 : 1.5,
        ),
        boxShadow: kCardShadow,
      ),
      child: InkWell(
        onTap: () => _showPatientDetails(patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng thông tin chính
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: patient.avatarBg,
                    child: Text(
                      patient.initials,
                      style: TextStyle(
                        color: patient.avatarText,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
                            Flexible(
                              child: Text(
                                patient.hoTen,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kSlate900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kPrimaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                patient.maBenhNhan,
                                style: const TextStyle(
                                  color: kPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          patient.email ?? 'Chưa đăng ký email',
                          style: const TextStyle(fontSize: 12, color: kSlate500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Badge trạng thái
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: patient.isActive ? const Color(0xFFDCFCE7) : kRedBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: patient.isActive
                            ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                            : kRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      patient.isActive ? 'Hoạt động' : 'Bị khóa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: patient.isActive ? const Color(0xFF16A34A) : kRed,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: kBorder),
              const SizedBox(height: 10),

              // Thông tin phụ: Số điện thoại + ngày tham gia
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 13, color: kSlate400),
                  const SizedBox(width: 4),
                  Text(
                    patient.soDienThoai ?? 'Chưa có SĐT',
                    style: const TextStyle(fontSize: 11.5, color: kSlate600, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined, size: 12, color: kSlate400),
                  const SizedBox(width: 4),
                  Text(
                    patient.ngayTao != null
                        ? '${patient.ngayTao!.day}/${patient.ngayTao!.month}/${patient.ngayTao!.year}'
                        : 'Mới',
                    style: const TextStyle(fontSize: 11.5, color: kSlate600),
                  ),
                ],
              ),

              // Lý do khóa nếu bị khóa
              if (!patient.isActive && patient.blockReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kRedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: kRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Lý do: ${patient.blockReason}',
                          style: const TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Hàng nút hành động nhanh
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kSlate700,
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _showPatientDetails(patient),
                      child: const Text('Xem hồ sơ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (patient.isActive)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.block_rounded, size: 14),
                      label: const Text('Khóa TK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRedBg,
                        foregroundColor: kRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: kRed.withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showBlockDialog(patient),
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lock_open_rounded, size: 14),
                      label: const Text('Mở khóa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _showUnblockDialog(patient),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
