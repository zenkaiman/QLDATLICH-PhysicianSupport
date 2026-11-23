import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';

// ================= MÀN 7: XEM CÁC BÁO CÁO LỖI & SỰ CỐ =================
class ErrorReportsScreen extends StatefulWidget {
  final bool isEmbedded;
  const ErrorReportsScreen({super.key, this.isEmbedded = false});

  @override
  State<ErrorReportsScreen> createState() => _ErrorReportsScreenState();
}

class _ErrorReportsScreenState extends State<ErrorReportsScreen> {
  int _selectedTab = 0; // 0 = Chờ xử lý, 1 = Lịch sử báo lỗi
  int _filter = 0; // 0 = tất cả, 1 = đặt lịch, 2 = qr

  @override
  void initState() {
    super.initState();
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _buildChip(String label, int index, IconData icon) {
    final bool active = _filter == index;
    return GestureDetector(
      onTap: () => setState(() => _filter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? kPrimary : kBorder,
            width: 1.2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : kCardShadow,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : kSlate500,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : kSlate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD BÁO CÁO CHỜ XỬ LÝ ---
  Widget _buildReportCard(BuildContext context, ErrorReport r) {
    final bool isQR = r.kind == 'qr';
    final Color badgeColor = isQR ? kRed : kOrange;
    final Color badgeBg = isQR ? kRedBg : kOrangeBg;

    return InkWell(
      onTap: () => _showReportDetailModal(context, r),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isQR
                        ? Icons.qr_code_scanner_rounded
                        : Icons.calendar_today_rounded,
                    size: 16,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBadge(
                      text: r.badge,
                      color: badgeColor,
                      bg: badgeBg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: kSlate400),
                    const SizedBox(width: 4),
                    Text(
                      r.time,
                      style: const TextStyle(
                          fontSize: 11,
                          color: kSlate400,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: kSlate400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r.sender,
                    style: const TextStyle(fontSize: 12, color: kSlate500),
                  ),
                ),
              ],
            ),
            if (r.desc != null && r.desc!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  r.desc!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: kSlate800, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text(
                        'Xem & Phản Hồi',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showReportDetailModal(context, r),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 15),
                      label: const Text(
                        'Đã Sửa & Báo Tin',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showNotifyDialog(context, r),
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

  // --- CARD LỊCH SỬ BÁO CÁO ĐÃ XỬ LÝ ---
  Widget _buildResolvedReportCard(BuildContext context, ErrorReport r) {
    return InkWell(
      onTap: () => _showReportDetailModal(context, r),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: kGreen,
                  ),
                ),
                const SizedBox(width: 6),
                const AppBadge(
                  text: 'Đã giải quyết',
                  color: kGreen,
                  bg: kGreenLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBadge(
                      text: r.badge,
                      color: kSlate600,
                      bg: const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 12, color: kSlate400),
                    const SizedBox(width: 4),
                    Text(
                      r.resolvedTime ?? r.time,
                      style: const TextStyle(
                          fontSize: 11,
                          color: kSlate400,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              r.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: kSlate900,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: kSlate400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r.sender,
                    style: const TextStyle(fontSize: 12, color: kSlate500),
                  ),
                ),
              ],
            ),
            if (r.desc != null && r.desc!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  r.desc!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: kSlate700, height: 1.35),
                ),
              ),
            ],
            if (r.adminResponse != null && r.adminResponse!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply_rounded, color: kGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phản hồi từ Quản trị viên:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.adminResponse!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF166534),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: kPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showReportDetailModal(context, r),
                icon: const Icon(Icons.info_outline_rounded, size: 15),
                label: const Text('Xem toàn bộ chi tiết lịch sử',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL XEM CHI TIẾT SỰ CỐ & LỊCH SỬ PHẢN HỒI ---
  void _showReportDetailModal(BuildContext context, ErrorReport r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: r.isResolved
                          ? kGreenLight
                          : (r.kind == 'qr' ? kRedBg : kOrangeBg),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      r.isResolved
                          ? Icons.check_circle_rounded
                          : (r.kind == 'qr'
                              ? Icons.qr_code_scanner_rounded
                              : Icons.calendar_today_rounded),
                      color: r.isResolved
                          ? kGreen
                          : (r.kind == 'qr' ? kRed : kOrange),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.badge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: r.isResolved
                                      ? kGreen
                                      : (r.kind == 'qr' ? kRed : kOrange),
                                ),
                              ),
                            ),
                            if (r.isResolved) ...[
                              const SizedBox(width: 6),
                              const AppBadge(
                                text: 'Đã giải quyết',
                                color: kGreen,
                                bg: kGreenLight,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          r.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: kSlate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Thông tin người gửi & thời gian
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      size: 16, color: kSlate400),
                  const SizedBox(width: 8),
                  Text(
                    r.sender,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kSlate800),
                  ),
                  const Spacer(),
                  const Icon(Icons.schedule_rounded,
                      size: 15, color: kSlate400),
                  const SizedBox(width: 4),
                  Text(
                    r.time,
                    style: const TextStyle(fontSize: 12, color: kSlate500),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text(
                'NỘI DUNG SỰ CỐ BÁO CÁO:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: kSlate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  r.desc ?? 'Không có mô tả chi tiết kèm theo.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: kSlate800,
                    height: 1.45,
                  ),
                ),
              ),

              if (r.isResolved && r.adminResponse != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'LỊCH SỬ PHẢN HỒI CỦA QUẢN TRỊ VIÊN:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: kGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 16, color: kGreen),
                          const SizedBox(width: 6),
                          const Text(
                            'Quản trị viên đã xử lý',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kGreen,
                            ),
                          ),
                          const Spacer(),
                          if (r.resolvedTime != null)
                            Text(
                              r.resolvedTime!,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF15803D)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.adminResponse!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF14532D),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Nút hành động
              if (!r.isResolved)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSlate600,
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Đóng',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.outgoing_mail, size: 18),
                        label: const Text(
                          'Xử Lý & Gửi Báo Tin',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showNotifyDialog(context, r);
                        },
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng lịch sử',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // --- HỘP THOẠI SOẠN NỘI DUNG VÀ GỬI THÔNG BÁO CHO NGƯỜI GỬI ---
  void _showNotifyDialog(BuildContext context, ErrorReport r) {
    final senderName = r.sender.replaceFirst('Người gửi: ', '');
    final msgCtrl = TextEditingController(
      text:
          'Kính gửi $senderName, sự cố "${r.title}" bạn gửi đã được Quản trị viên xử lý và khắc phục hoàn tất. Cảm ơn bạn đã phản hồi!',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: kGreen, size: 24),
            SizedBox(width: 8),
            Text(
              'Gửi Thông Báo Đã Sửa',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xác nhận sự cố "${r.title}" đã được sửa chữa và gửi phản hồi thông báo đến $senderName:',
              style: const TextStyle(fontSize: 13.5, color: kSlate600, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Lời nhắn gửi đến người báo sự cố',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy',
                style: TextStyle(color: kSlate600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Gửi Thông Báo Ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final message = msgCtrl.text.trim();
              final finalMsg = message.isEmpty
                  ? 'Sự cố "${r.title}" đã được Quản trị viên xử lý hoàn tất.'
                  : message;

              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);

              await AdminStore.instance.resolveReportAndNotify(r, finalMsg);
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                      'Đã giải quyết sự cố và lưu vào lịch sử báo lỗi! Phản hồi tới $senderName thành công! ✓'),
                  backgroundColor: kGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    final pendingList = store.filteredReports(_filter);
    final historyList = store.filteredResolvedReports(_filter);
    final activeList = _selectedTab == 0 ? pendingList : historyList;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: widget.isEmbedded ? 8 : 14),
              color: Colors.white,
              child: Column(
                children: [
                  if (!widget.isEmbedded) ...[
                    Row(
                      children: [
                        const BackCircle(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Báo Cáo Sự Cố & Khiếu Nại',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: kSlate900,
                                ),
                              ),
                              Text(
                                '${store.reports.length} sự cố cần sửa · ${store.resolvedReports.length} đã giải quyết',
                                style: const TextStyle(
                                    fontSize: 12, color: kSlate500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: store.reports.isNotEmpty ? kRedBg : kGreenLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            store.reports.isNotEmpty
                                ? '${store.reports.length} Cần sửa'
                                : 'Ổn định',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: store.reports.isNotEmpty ? kRed : kGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // TAB SWITCHER: CHỜ XỬ LÝ vs LỊCH SỬ BÁO LỖI
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pending_actions_rounded,
                                    size: 16,
                                    color: _selectedTab == 0 ? kPrimary : kSlate500,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Chờ xử lý (${store.reports.length})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 0 ? kPrimary : kSlate600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: _selectedTab == 1 ? kGreen : kSlate500,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Lịch sử báo lỗi (${store.resolvedReports.length})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _selectedTab == 1 ? kGreen : kSlate600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Bộ lọc danh mục (cuộn ngang tránh tràn màn hình nhỏ)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip(
                          'Tất cả (${_selectedTab == 0 ? store.reports.length : store.resolvedReports.length})',
                          0,
                          Icons.list_alt_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildChip('Lỗi đặt lịch', 1, Icons.calendar_month_rounded),
                        const SizedBox(width: 8),
                        _buildChip('Lỗi QR Check-in', 2, Icons.qr_code_scanner_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: activeList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? kGreenLight : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _selectedTab == 0
                                    ? Icons.check_circle_rounded
                                    : Icons.history_edu_rounded,
                                size: 44,
                                color: _selectedTab == 0 ? kGreen : kSlate400,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _selectedTab == 0
                                  ? 'Hệ thống đang hoạt động ổn định'
                                  : 'Chưa có lịch sử báo lỗi',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: kSlate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedTab == 0
                                  ? 'Không còn báo cáo sự cố chưa xử lý trong danh mục này.'
                                  : 'Các báo cáo sự cố sau khi xử lý sẽ được lưu trữ tại đây.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: kSlate500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activeList.length,
                      itemBuilder: (context, index) {
                        final item = activeList[index];
                        if (_selectedTab == 0) {
                          return _buildReportCard(context, item);
                        } else {
                          return _buildResolvedReportCard(context, item);
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
