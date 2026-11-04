import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../models/letan_c1/letan_ui_components_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';

class LetanLichhenScreenC1 extends StatefulWidget {
  final String tuKhoaBanDau;
  final bool laTab;
  final String? tenKhoa;
  final DateTime? ngayChonBanDau;

  const LetanLichhenScreenC1({
    super.key,
    this.tuKhoaBanDau = '',
    this.laTab = true,
    this.tenKhoa,
    this.ngayChonBanDau,
  });

  @override
  State<LetanLichhenScreenC1> createState() => _LetanLichhenScreenC1State();
}

class _LetanLichhenScreenC1State extends State<LetanLichhenScreenC1> {
  late TextEditingController _timKiemController;
  late DateTime _ngayChon;
  String _boLocHienTai = 'Tất cả'; // Tất cả, Đang chờ, Đã khám, Vắng
  String _tuKhoa = '';
  bool _dangTaiLamMoi = false;

  final List<String> _danhSachBoLoc = ['Tất cả', 'Đang chờ', 'Đã khám', 'Vắng'];

  Future<void> _xuLyLamMoiDuLieu() async {
    AppDesignSystemC1.hapticLight();
    setState(() {
      _dangTaiLamMoi = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _dangTaiLamMoi = false;
      });
    }
  }

  Future<void> _chonNgay() async {
    AppDesignSystemC1.hapticLight();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayChon,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY XEM LỊCH HẸN',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );
    if (picked != null && picked != _ngayChon) {
      setState(() {
        _ngayChon = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ngayChon = widget.ngayChonBanDau ?? DateTime.now();
    _tuKhoa = widget.tuKhoaBanDau;
    _timKiemController = TextEditingController(text: widget.tuKhoaBanDau);
  }

  @override
  void didUpdateWidget(covariant LetanLichhenScreenC1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ngayChonBanDau != null && widget.ngayChonBanDau != oldWidget.ngayChonBanDau) {
      _ngayChon = widget.ngayChonBanDau!;
    }
  }

  @override
  void dispose() {
    _timKiemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    final content = StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseServiceC1.streamDanhSachLichHen(
        tenKhoa: widget.tenKhoa,
        boLocTrangThai: _boLocHienTai,
        tuKhoa: _tuKhoa,
        ngayChon: _ngayChon,
        benhVienId: bvid,
      ),
      builder: (context, snapshot) {
        final danhSach = snapshot.data ?? [];
        final tongSo = danhSach.length;

        return Column(
          children: [
            // Thanh tiêu đề khi ở dạng Tab
            if (widget.laTab)
              Container(
                color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lịch hẹn hôm nay',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.tenKhoa != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          FirebaseServiceC1.laCheDoTong(widget.tenKhoa) ? 'Toàn viện' : widget.tenKhoa!,
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Thanh tìm kiếm trực tiếp theo Tên hoặc SĐT
            Container(
              color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _timKiemController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                onChanged: (val) {
                  setState(() {
                    _tuKhoa = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc số điện thoại...',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                  suffixIcon: _tuKhoa.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF8E8E93), size: 18),
                          onPressed: () {
                            _timKiemController.clear();
                            setState(() {
                              _tuKhoa = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Dòng hiển thị Ngày và Tổng số lịch hẹn
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _chonNgay,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF1E88E5)),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày ${_ngayChon.day.toString().padLeft(2, '0')}/${_ngayChon.month.toString().padLeft(2, '0')}/${_ngayChon.year}',
                            style: TextStyle(
                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '$tongSo lịch hẹn',
                    style: const TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Bộ lọc 4 tab phong cách Segmented Button chuẩn M3
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  borderRadius: AppDesignSystemC1.borderRadMedium,
                ),
                child: Row(
                  children: _danhSachBoLoc.map((tab) {
                    final bool isSelected = _boLocHienTai == tab;
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          AppDesignSystemC1.hapticLight();
                          setState(() {
                            _boLocHienTai = tab;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            tab,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.white : AppDesignSystemC1.primary)
                                  : (isDark ? AppDesignSystemC1.darkTextSecondary : AppDesignSystemC1.textSecondary),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Danh sách lịch hẹn với Pull-to-refresh và Empty state
            Expanded(
              child: _dangTaiLamMoi || snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData
                  ? const SkeletonLichHenListC1()
                  : RefreshIndicator(
                      color: AppDesignSystemC1.primary,
                      onRefresh: _xuLyLamMoiDuLieu,
                      child: danhSach.isEmpty
                          ? EmptyStateWidgetC1(
                              title: _tuKhoa.isNotEmpty ? 'Không Tìm Thấy Bệnh Nhân' : 'Chưa Có Lịch Hẹn Nào',
                              message: _tuKhoa.isNotEmpty
                                  ? 'Không có kết quả trùng khớp với từ khóa "$_tuKhoa". Vui lòng kiểm tra lại.'
                                  : 'Hiện tại chưa có bệnh nhân nào trong danh mục "$_boLocHienTai".',
                              onRetry: () {
                                setState(() {
                                  _tuKhoa = '';
                                  _timKiemController.clear();
                                  _boLocHienTai = 'Tất cả';
                                });
                              },
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: danhSach.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildItemLichHenMap(danhSach[index]);
                              },
                            ),
                    ),
            ),
          ],
        );
      },
    );

    if (widget.laTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lịch hẹn hôm nay',
          style: TextStyle(
            color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildItemLichHenMap(Map<String, dynamic> item) {
    final isDark = AppDesignSystemC1.laCheDoToi;
    Color badgeBg;
    Color badgeText;
    Color avatarBg;
    Color avatarText;

    final trangThai = item['trangThai'] ?? 'Đang chờ';
    if (trangThai == 'Tiếp theo' || trangThai == 'Đang chờ' || trangThai == 'Đã tiếp nhận') {
      badgeBg = trangThai == 'Tiếp theo' ? const Color(0xFFE8F8EF) : const Color(0xFFE8F4FD);
      badgeText = trangThai == 'Tiếp theo' ? const Color(0xFF34C759) : const Color(0xFF007AFF);
      avatarBg = badgeBg;
      avatarText = badgeText;
    } else if (trangThai == 'Đã khám') {
      badgeBg = const Color(0xFFE8F8EF);
      badgeText = const Color(0xFF34C759);
      avatarBg = const Color(0xFFE8F8EF);
      avatarText = const Color(0xFF34C759);
    } else if (trangThai == 'Vắng') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFEF4444);
      avatarBg = const Color(0xFFFEE2E2);
      avatarText = const Color(0xFFEF4444);
    } else {
      badgeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF2F2F7);
      badgeText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93);
      avatarBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF2F2F7);
      avatarText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF8E8E93);
    }

    final cardBg = isDark ? AppDesignSystemC1.darkSurface : Colors.white;
    final borderCol = isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA);
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    final hoTen = (item['hoTen'] ?? 'Bệnh nhân').toString();
    final initials = hoTen.trim().isNotEmpty
        ? hoTen.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'BN';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar viết tắt
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: avatarText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Thông tin Tên, Khoa, Giờ, SĐT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hoTen,
                  style: TextStyle(
                    color: textCol,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 13, color: Color(0xFF007AFF)),
                    const SizedBox(width: 4),
                    Text(
                      (item['sdt'] ?? '').toString(),
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${item['tenKhoa']} • ${item['phongKham']}',
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Giờ khám: ${item['gioKham']} • STT: ${item['stt']}',
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Nhãn trạng thái
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trangThai,
              style: TextStyle(
                color: badgeText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
