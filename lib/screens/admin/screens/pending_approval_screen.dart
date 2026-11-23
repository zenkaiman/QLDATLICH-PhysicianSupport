import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';
import 'approve_confirm_screen.dart';
import 'reject_screen.dart';
import 'pending_hospital_detail_screen.dart';

// ================= MÀN 6: BỆNH VIỆN CHỜ DUYỆT =================
class PendingApprovalScreen extends StatefulWidget {
  final bool isEmbedded;
  const PendingApprovalScreen({super.key, this.isEmbedded = false});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
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

  Widget _buildPendingCard(BuildContext context, Map<String, String> h) {
    final name = h['name'] ?? 'Bệnh viện mới';
    final type = h['type'] ?? 'Bệnh viện Công lập';
    final code = h['code'] ?? '';
    final location = h['location'] ?? 'Chưa cập nhật địa chỉ';
    final docFile = h['docs'] ?? 'Hồ sơ BYT';
    final time = h['time'] ?? 'Vừa gửi';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PendingHospitalDetailScreen(hospital: h),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarBox(
                      text: h['tag'] ?? 'BV',
                      bg: kOrangeBg,
                      fg: kAmber,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                    color: kSlate900,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: kSlate400,
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                type,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kSlate600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kOrangeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.hourglass_top_rounded, size: 11, color: kAmber),
                                    SizedBox(width: 3),
                                    Text(
                                      'Chờ duyệt',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: kAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Thông tin chi tiết hồ sơ
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: kSlate400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kSlate600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 15, color: kPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Giấy tờ pháp lý: $docFile · Mã: $code',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 15, color: kSlate400),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11.5, color: kSlate400),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Hai nút hành động Duyệt và Từ chối
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Xác nhận Duyệt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            shadowColor: kGreen.withValues(alpha: 0.3),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ApproveConfirmScreen(hospital: h),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kRed,
                            side: const BorderSide(color: Color(0xFFFECACA), width: 1.4),
                            backgroundColor: const Color(0xFFFFF5F5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RejectScreen(hospital: h),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            if (!widget.isEmbedded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: Colors.white,
                child: Row(
                  children: [
                    const BackCircle(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xét Duyệt Hồ Sơ Cơ Sở Y Tế',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: kSlate900,
                            ),
                          ),
                          Text(
                            '${store.pendingTotal} đơn đăng ký đang chờ quản trị viên kiểm định',
                            style: const TextStyle(fontSize: 12, color: kSlate500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kOrangeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${store.pendingTotal} Chờ',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: kAmber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: store.pending.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: kGreenLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.task_alt_rounded, size: 44, color: kGreen),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Đã hoàn thành duyệt tất cả!',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: kSlate900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hiện tại không có cơ sở y tế nào đang chờ phê duyệt. Hệ thống đang cập nhật tự động khi có hồ sơ mới từ Firebase.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: kSlate500, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: store.pending.length,
                      itemBuilder: (context, index) {
                        return _buildPendingCard(context, store.pending[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
