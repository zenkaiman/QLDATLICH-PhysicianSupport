import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../models/letan_c1/letan_ui_components_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'widgets/cskh_lich_su_ngay_bottom_sheet_c1.dart';
import 'widgets/medical_reusable_widgets_c1.dart';

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

  final List<String> _danhSachBoLoc = ['Tất cả', 'Chờ duyệt', 'Đã duyệt', 'Đã khám', 'Đã hủy'];

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

  /// Mở màn hình/BottomSheet danh sách ListView các ngày có lịch khám bệnh trên Firebase
  void _moDanhSachNgayKham({bool chiLichSu = false}) {
    AppDesignSystemC1.hapticLight();
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Modal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: chiLichSu ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            chiLichSu ? Icons.history_rounded : Icons.calendar_month_rounded,
                            color: chiLichSu ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chiLichSu ? 'Lịch sử khám bệnh' : 'Danh sách ngày có lịch khám',
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              chiLichSu
                                  ? 'Các ngày khám đã qua (từ hôm nay trở về trước)'
                                  : 'Chỉ hiển thị các ngày thực tế có bệnh nhân đặt hẹn',
                              style: TextStyle(
                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Chọn ngày bất kỳ qua lịch',
                          icon: const Icon(Icons.edit_calendar_rounded),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _chonNgay();
                          },
                          color: const Color(0xFF0284C7),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Danh sách ListView ngày có lịch khám
              Expanded(
                child: StreamBuilder<List<DateTime>>(
                  stream: FirebaseServiceC1.streamNgayCoLichKham(
                    tenKhoa: widget.tenKhoa,
                    benhVienId: bvid,
                    chiLichSuTuHomNayTroVeTruoc: chiLichSu,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                      );
                    }

                    final listNgay = snapshot.data ?? [];
                    if (listNgay.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                size: 48,
                                color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                chiLichSu ? 'Chưa có lịch sử khám bệnh nào' : 'Chưa có ngày nào có lịch khám',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Các ngày có lịch khám từ Firebase sẽ xuất hiện ở đây',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: listNgay.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dt = listNgay[index];
                        final bool laNgayDangChon = dt.year == _ngayChon.year &&
                            dt.month == _ngayChon.month &&
                            dt.day == _ngayChon.day;
                        final bool laHomNay = dt.year == DateTime.now().year &&
                            dt.month == DateTime.now().month &&
                            dt.day == DateTime.now().day;

                        final thuTrongTuan = [
                          'Chủ nhật',
                          'Thứ hai',
                          'Thứ ba',
                          'Thứ tư',
                          'Thứ năm',
                          'Thứ sáu',
                          'Thứ bảy'
                        ][dt.weekday % 7];

                        return InkWell(
                          onTap: () {
                            AppDesignSystemC1.hapticLight();
                            setState(() {
                              _ngayChon = dt;
                            });
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: laNgayDangChon
                                  ? (isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: laNgayDangChon
                                    ? const Color(0xFF0284C7)
                                    : (isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0)),
                                width: laNgayDangChon ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: laNgayDangChon
                                        ? const Color(0xFF0284C7)
                                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dt.day.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          color: laNgayDangChon
                                              ? Colors.white
                                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'T${dt.month}',
                                        style: TextStyle(
                                          color: laNgayDangChon
                                              ? Colors.white70
                                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '$thuTrongTuan, ${dt.day}/${dt.month}/${dt.year}',
                                            style: TextStyle(
                                              color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (laHomNay) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Hôm nay',
                                                style: TextStyle(
                                                  color: Color(0xFF059669),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Nhấn để xem các lịch hẹn của ngày này',
                                        style: TextStyle(
                                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  laNgayDangChon ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                                  color: laNgayDangChon
                                      ? const Color(0xFF0284C7)
                                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  size: laNgayDangChon ? 22 : 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

            // Dòng hiển thị Ngày và Tổng số lịch hẹn & Nút Lịch sử khám bệnh
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Nút mở ListView chọn ngày có lịch khám
                          InkWell(
                            onTap: () => _moDanhSachNgayKham(chiLichSu: false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    '${_ngayChon.day.toString().padLeft(2, '0')}/${_ngayChon.month.toString().padLeft(2, '0')}/${_ngayChon.year}',
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
                          const SizedBox(width: 8),

                          // Nút Lịch sử khám bệnh (10 ngày gần nhất + Chọn ngày khác)
                          InkWell(
                            onTap: () {
                              AppDesignSystemC1.hapticLight();
                              CskhLichSuNgayBottomSheetC1.show(
                                context: context,
                                tenKhoa: widget.tenKhoa ?? DuLieuProfileMauC1.thongTinHienTai.khoa,
                                onSelectDate: (ngayDuocChon) {
                                  setState(() {
                                    _ngayChon = ngayDuocChon;
                                  });
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.6 : 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_rounded, size: 15, color: Color(0xFFD97706)),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Lịch sử khám bệnh',
                                    style: TextStyle(
                                      color: Color(0xFFB45309),
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
                  const SizedBox(width: 8),
                  Text(
                    '$tongSo lịch hẹn',
                    style: const TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 13.5,
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                tab,
                                maxLines: 1,
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
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    final hoTen = (item['hoTen'] ?? 'Bệnh nhân').toString();
    final initials = hoTen.trim().isNotEmpty
        ? hoTen.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'BN';

    return MedicalCardC1(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar viết tắt
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF007AFF),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (item['so_thu_tu'] != null && item['so_thu_tu'].toString().isNotEmpty)
                      ? 'Giờ khám: ${item['gioKham']} • STT: ${item['so_thu_tu']}'
                      : 'Giờ khám: ${item['gioKham']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Nhãn trạng thái chuẩn y tế
          MedicalStatusBadgeC1(trangThai: (item['trangThai'] ?? 'Đang chờ').toString()),
        ],
      ),
    );
  }
}
