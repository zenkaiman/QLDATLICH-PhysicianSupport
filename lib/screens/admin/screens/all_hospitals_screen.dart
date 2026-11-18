import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/mock_data.dart';
import '../data/admin_store.dart';
import '../widgets/shared_widgets.dart';
import 'hospital_detail_screen.dart';
import 'operations_screen.dart';

// =========================================================================
// MÀN: QUẢN LÝ TẤT CẢ CƠ SỞ Y TẾ TRONG HỆ THỐNG
// Thiết kế chuẩn Admin SaaS: Segmented Control, Filter Chips, Elevated Cards
// =========================================================================
class AllHospitalsScreen extends StatefulWidget {
  final int initialSort; // 0 = mặc định, 1 = thấp→cao, 2 = cao→thấp
  final bool isEmbedded; // Khi hiển thị trong Tab của MainShell

  const AllHospitalsScreen({
    super.key,
    this.initialSort = 0,
    this.isEmbedded = false,
  });

  @override
  State<AllHospitalsScreen> createState() => _AllHospitalsScreenState();
}

class _AllHospitalsScreenState extends State<AllHospitalsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late int _sort;
  String _selectedType = 'all'; // 'all', 'Công lập', 'Tư nhân'
  int _statusTab = 0; // 0: Đang hợp tác, 1: Đã hủy hợp tác

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort;
    AdminStore.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdminStore.instance.removeListener(_refresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ================= HỘP THOẠI KHÔI PHỤC HỢP TÁC =================
  void _showRestoreDialog(BuildContext context, Hospital h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: kGreen, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Khôi phục hợp tác?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kSlate900),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn kích hoạt lại thỏa thuận hợp tác và đưa "${h.name}" quay trở lại danh sách hoạt động bình thường?',
          style: const TextStyle(fontSize: 13.5, color: kSlate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: kSlate500, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AdminStore.instance.restoreHospitalPartnership(h);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã khôi phục hợp tác thành công với "${h.name}"! ✓'),
                  backgroundColor: kGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Khôi phục ngay'),
          ),
        ],
      ),
    );
  }

  // ================= HỘP THOẠI XÓA VĨNH VIỄN HỒ SƠ =================
  void _showDeletePermanentDialog(BuildContext context, Hospital h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: kRed, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Xóa vĩnh viễn hồ sơ?',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kRed),
              ),
            ),
          ],
        ),
        content: Text(
          'Hành động này sẽ xóa hoàn toàn cơ sở "${h.name}" và xóa vĩnh viễn tài khoản đăng nhập khỏi Firebase Authentication (không thể hoàn tác).',
          style: const TextStyle(fontSize: 13.5, color: kSlate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy bỏ', style: TextStyle(color: kSlate500, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AdminStore.instance.deleteHospitalAccount(h);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã xóa vĩnh viễn hồ sơ và tài khoản Auth của "${h.name}".'),
                  backgroundColor: kSlate900,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  // ============ TAB TRẠNG THÁI (SEGMENTED CONTROL STYLE) ============
  Widget _buildStatusTab(int tabIndex, String label, int count, {bool isDanger = false}) {
    final active = _statusTab == tabIndex;
    final color = isDanger ? kRed : kPrimary;
    return InkWell(
      onTap: () => setState(() => _statusTab = tabIndex),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? color : kSlate600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: active ? (isDanger ? kRedBg : kPrimaryLight) : kSlate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: active ? color : kSlate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ CHIP BỘ LỌC ============
  Widget _buildFilterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? kPrimary : kBorder,
            width: 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : kCardShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : kSlate600,
          ),
        ),
      ),
    );
  }

  // ============ THẺ CƠ SỞ Y TẾ TRONG DANH SÁCH ============
  Widget _buildHospitalItem(BuildContext context, Hospital h) {
    final isCancelled = h.isUnpartnered || _statusTab == 1;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HospitalDetailScreen(hospital: h)),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCancelled
                ? kRed.withValues(alpha: 0.35)
                : kBorder,
            width: isCancelled ? 1.4 : 1,
          ),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarBox(
                  text: h.initials,
                  bg: isCancelled ? const Color(0xFFF1F5F9) : h.avatarBg,
                  fg: isCancelled ? kSlate500 : h.avatarText,
                  size: 46,
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
                              h.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: isCancelled ? kSlate700 : kSlate900,
                              ),
                            ),
                          ),
                          if (!isCancelled) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 14, color: kPrimary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: h.type == 'Công lập' ? kPrimaryLight : kOrangeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              h.type,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: h.type == 'Công lập' ? kPrimary : kAmber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            h.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kSlate800,
                            ),
                          ),
                          const Spacer(),
                          // Huy hiệu trạng thái
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? kRedBg
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCancelled
                                      ? Icons.link_off_rounded
                                      : Icons.check_circle_rounded,
                                  size: 12,
                                  color: isCancelled ? kRed : kGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCancelled
                                      ? 'Đã hủy'
                                      : 'Đang hợp tác',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isCancelled ? kRed : kGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (h.address != null && h.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: kSlate400),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                h.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: kSlate500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: kSlate400, size: 20),
              ],
            ),

            // Nút Khôi phục hợp tác hoặc Xóa hẳn khi ở Tab Đã hủy
            if (isCancelled) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: kBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.handshake_outlined, size: 15),
                      label: const Text('Khôi phục hợp tác', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _showRestoreDialog(context, h),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded, size: 15, color: kRed),
                    label: const Text('Xóa hẳn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRed)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _showDeletePermanentDialog(context, h),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AdminStore.instance;
    final q = _query.trim().toLowerCase();

    // 1. Xác định tập nguồn bệnh viện theo Tab trạng thái: 0: Đang hợp tác, 1: Đã hủy hợp tác
    final List<Hospital> sourceList = _statusTab == 1
        ? store.cancelledHospitals
        : store.hospitals;

    // 2. Lọc theo từ khóa
    List<Hospital> filtered = sourceList.where((h) {
      if (q.isEmpty) return true;
      final matchName = h.name.toLowerCase().contains(q);
      final matchInitials = h.initials.toLowerCase().contains(q);
      final matchCode = (h.code ?? '').toLowerCase().contains(q);
      final matchAddress = (h.address ?? '').toLowerCase().contains(q);
      return matchName || matchInitials || matchCode || matchAddress;
    }).toList();

    // 3. Lọc theo loại hình
    if (_selectedType != 'all') {
      filtered = filtered.where((h) => h.type.contains(_selectedType)).toList();
    }

    // 4. Sắp xếp
    if (_sort == 1) {
      filtered.sort((a, b) => a.rating.compareTo(b.rating));
    } else if (_sort == 2) {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    }

    final activeCount = store.hospitals.length;
    final cancelledCount = store.cancelledHospitals.length;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ============ HEADER ============
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              'Danh Sách Bệnh Viện',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: kSlate900,
                              ),
                            ),
                            Text(
                              '${store.totalBV} cơ sở đang kết nối · $cancelledCount đã ngừng hợp tác',
                              style: const TextStyle(fontSize: 12, color: kSlate500),
                            ),
                          ],
                        ),
                      ),
                      const LiveSyncBadge(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Thanh tìm kiếm
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20, color: kSlate400),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            style: const TextStyle(fontSize: 13.5, color: kSlate900, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'Tìm theo tên, địa chỉ, mã bệnh viện...',
                              hintStyle: TextStyle(fontSize: 13, color: kSlate400, fontWeight: FontWeight.w500),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(Icons.cancel_rounded, size: 18, color: kSlate400),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // HÀNG 1: TABS TRẠNG THÁI HỢP TÁC (SEGMENTED CONTROL FULL WIDTH)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatusTab(0, 'Đang hợp tác', activeCount)),
                        const SizedBox(width: 4),
                        Expanded(child: _buildStatusTab(1, 'Đã hủy hợp tác', cancelledCount, isDanger: true)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // HÀNG 2: BỘ LỌC LOẠI HÌNH & XẾP HẠNG
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('Tất cả', _selectedType == 'all', () {
                          setState(() => _selectedType = 'all');
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Công lập', _selectedType == 'Công lập', () {
                          setState(() => _selectedType = 'Công lập');
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Tư nhân', _selectedType == 'Tư nhân', () {
                          setState(() => _selectedType = 'Tư nhân');
                        }),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 18, color: kBorder),
                        const SizedBox(width: 8),
                        _buildFilterChip('★ Cao nhất', _sort == 2, () {
                          setState(() => _sort = (_sort == 2 ? 0 : 2));
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('★ Thấp nhất', _sort == 1, () {
                          setState(() => _sort = (_sort == 1 ? 0 : 1));
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ============ KẾT QUẢ DANH SÁCH ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Hiển thị ${filtered.length} kết quả',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kSlate600,
                    ),
                  ),
                  if (store.pendingTotal > 0) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OperationsScreen(initialTab: 0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, size: 14, color: kAmber),
                          const SizedBox(width: 4),
                          Text(
                            '${store.pendingTotal} chờ duyệt',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? EmptyStateWidget(
                      icon: _statusTab == 1 ? Icons.link_off_rounded : Icons.search_off_rounded,
                      title: _statusTab == 1
                          ? 'Không có bệnh viện nào đã hủy hợp tác'
                          : 'Không tìm thấy bệnh viện phù hợp',
                      message: 'Thử đổi từ khóa tìm kiếm hoặc đặt lại các bộ lọc danh mục.',
                      actionLabel: _query.isNotEmpty ? 'Xóa từ khóa tìm kiếm' : null,
                      onAction: _query.isNotEmpty
                          ? () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            }
                          : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildHospitalItem(context, filtered[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
