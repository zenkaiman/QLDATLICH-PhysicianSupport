import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';
import 'pending_approval_screen.dart';
import 'error_reports_screen.dart';

// ===================================================
// TRUNG TÂM XỬ LÝ: GỘP CHỜ DUYỆT & BÁO LỖI (2 TABS CON)
// ===================================================
class OperationsScreen extends StatefulWidget {
  final bool isEmbedded;
  final int initialTab; // 0 = Chờ duyệt, 1 = Báo lỗi

  const OperationsScreen({
    super.key,
    this.isEmbedded = false,
    this.initialTab = 0,
  });

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    final totalPendingTasks = store.pendingTotal + store.reports.length;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ============ HEADER TRUNG TÂM XỬ LÝ ============
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      if (!widget.isEmbedded) ...[
                        const BackCircle(),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trung Tâm Xử Lý Yêu Cầu',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: kSlate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đang có $totalPendingTasks đầu việc cần Quản trị viên xử lý',
                              style: const TextStyle(
                                fontSize: 12,
                                color: kSlate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: totalPendingTasks > 0 ? kOrangeBg : kGreenLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: totalPendingTasks > 0
                                ? kAmber.withValues(alpha: 0.3)
                                : kGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              totalPendingTasks > 0
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_circle_rounded,
                              size: 13,
                              color: totalPendingTasks > 0 ? kAmber : kGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              totalPendingTasks > 0
                                  ? '$totalPendingTasks việc chờ'
                                  : 'Đã hoàn tất',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: totalPendingTasks > 0 ? kAmber : kGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ============ 2 TABS CON: CHỜ DUYỆT & BÁO LỖI ============
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: kPrimary,
                      unselectedLabelColor: kSlate500,
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.domain_verification_rounded, size: 16),
                              const SizedBox(width: 6),
                              const Text('Chờ duyệt'),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: store.pendingTotal > 0
                                      ? kOrangeBg
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${store.pendingTotal}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: store.pendingTotal > 0
                                        ? kAmber
                                        : kSlate500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bug_report_rounded, size: 16),
                              const SizedBox(width: 6),
                              const Text('Báo lỗi'),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: store.reports.isNotEmpty
                                      ? kRedBg
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${store.reports.length}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: store.reports.isNotEmpty
                                        ? kRed
                                        : kSlate500,
                                  ),
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
            ),

            // ============ NỘI DUNG 2 TABS ============
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  PendingApprovalScreen(isEmbedded: true),
                  ErrorReportsScreen(isEmbedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
