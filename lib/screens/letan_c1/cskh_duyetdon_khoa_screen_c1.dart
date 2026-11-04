import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_danhsach_don_khoa_screen_c1.dart';
import 'cskh_danhsach_tinnhan_screen_c1.dart';
import 'cskh_profile_tab_c1.dart';
import 'letan_baocao_thanhcong_screen_c1.dart';
import 'letan_baocaoloi_screen_c1.dart';
import 'letan_trangchu_screen_c1.dart';
import 'widgets/cskh_bottom_nav_c1.dart';
import 'widgets/cskh_department_card_c1.dart';
import 'widgets/cskh_department_selector_card_c1.dart';
import 'widgets/cskh_stats_row_c1.dart';
import 'widgets/cskh_tab_duyet_phong_c1.dart';
import 'widgets/cskh_thong_bao_bottom_sheet_c1.dart';
import 'widgets/department_picker_modal_c1.dart';

export 'widgets/cskh_department_card_c1.dart' show KhoaKhamModelC1;

/// MÀN HÌNH TRANG CHỦ CSKH & DUYỆT ĐƠN THEO KHOA
/// Có cùng cấu trúc & chuẩn thẩm mỹ với Module Lễ tân C1
class CskhDuyetdonKhoaScreenC1 extends StatefulWidget {
  const CskhDuyetdonKhoaScreenC1({super.key});

  @override
  State<CskhDuyetdonKhoaScreenC1> createState() => _CskhDuyetdonKhoaScreenC1State();
}

class _CskhDuyetdonKhoaScreenC1State extends State<CskhDuyetdonKhoaScreenC1> {
  int _currentBottomNavIndex = 0; // 0: Trang chủ, 1: Duyệt đơn, 2: CSKH, 3: Profile
  DateTime _ngayChon = DateTime.now();

  late String _tenKhoaHienTai;
  String? _khoaIdHienTai;
  StreamSubscription? _subLoiDaSua;
  StreamSubscription? _subDonKhamMoi;

  @override
  void initState() {
    super.initState();
    final khoaNv = DuLieuProfileMauC1.thongTinHienTai.khoa.trim();
    if (khoaNv.isNotEmpty &&
        !khoaNv.toLowerCase().contains('bộ phận') &&
        !khoaNv.toLowerCase().contains('cskh') &&
        !khoaNv.toLowerCase().contains('toàn viện')) {
      _tenKhoaHienTai = khoaNv;
    } else {
      _tenKhoaHienTai = 'Tất cả các khoa (Tổng)';
    }
    _dangKyLangNgheLoiDaSua();
    _dangKyLangNgheDonKhamMoi();
    // Tự động dọn dẹp Document rác ở cấp 1 chuyển vào /NhanVien/BV502/danh_sach/
    FirebaseServiceC1.donDepDocumentNhanVienCap1('CSKH_02');
    FirebaseServiceC1.donDepDocumentNhanVienCap1();
  }

  void _dangKyLangNgheDonKhamMoi() {
    _subDonKhamMoi = FirebaseServiceC1.langNgheDonKhamChuaDuyet(
      onCoDonMoi: ({
        required String appointmentId,
        required String hoTen,
        required String tenKhoa,
        required String khungGio,
        required int soDonChuaDuyet,
      }) {
        if (!mounted) return;
        AppDesignSystemC1.hapticSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔔 Có đơn đặt khám mới cần duyệt!',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '$hoTen - $tenKhoa • Còn $soDonChuaDuyet đơn đang chờ',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'DUYỆT NGAY',
              textColor: const Color(0xFF38BDF8),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CskhDanhsachDonKhoaScreenC1(
                      tenKhoa: tenKhoa,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _dangKyLangNgheLoiDaSua() {
    _subLoiDaSua = FirebaseServiceC1.langNgheBaoCaoLoiDaSua(
      onLoiDaSua: (maLoi, tieuDe, phanHoi) {
        if (!mounted) return;
        AppDesignSystemC1.hapticSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã sửa lỗi $maLoi',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Sự cố "$tieuDe" đã được kỹ thuật viên sửa xong!',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'XEM',
              textColor: Colors.white,
              onPressed: () {
                LetanBaocaoThanhcongScreenC1.moLichSuBaoCao(context, maBaoCaoHienTai: maLoi);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _subLoiDaSua?.cancel();
    _subDonKhamMoi?.cancel();
    super.dispose();
  }

  // Mở BottomSheet cho phép đổi Chuyên khoa của Bệnh viện
  void _moModalChonKhoa() {
    DepartmentPickerModalC1.show(
      context: context,
      tenKhoaHienTai: _tenKhoaHienTai,
      onKhoaSelected: (tenKhoa, khoaId) {
        setState(() {
          _tenKhoaHienTai = tenKhoa;
          _khoaIdHienTai = khoaId;
        });
      },
    );
  }

  Future<void> _chonNgay() async {
    AppDesignSystemC1.hapticLight();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayChon,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY THỐNG KÊ',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );
    if (picked != null && picked != _ngayChon) {
      setState(() => _ngayChon = picked);
    }
  }

  void _onSelectKhoa(KhoaKhamModelC1 khoa) {
    AppDesignSystemC1.hapticLight();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CskhDanhsachDonKhoaScreenC1(
          tenKhoa: khoa.tenKhoa,
          phongKham: khoa.moTaPhong.split('•').first.trim(),
          caKham: khoa.moTaPhong.contains('•')
              ? khoa.moTaPhong.split('•').last.trim().replaceAll('\n', ' ')
              : 'Ca sáng',
          tongDon: 25,
        ),
      ),
    );
  }

  void _onSelectPhong(Map<String, dynamic> phong, String tenKhoa) {
    AppDesignSystemC1.hapticLight();
    final tenPhong = (phong['tenPhong'] ?? phong['soPhong'] ?? 'Phòng Khám').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CskhDanhsachDonKhoaScreenC1(
          tenKhoa: tenKhoa,
          phongKham: tenPhong,
          caKham: 'Tất cả các ca',
          tongDon: 0,
        ),
      ),
    );
  }

  void _moBaoCaoLoi() {
    AppDesignSystemC1.hapticLight();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LetanBaocaoloiScreenC1()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDesignSystemC1.isDarkMode,
      builder: (context, isDark, child) {
        return PopScope(
          canPop: _currentBottomNavIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_currentBottomNavIndex != 0) {
              setState(() => _currentBottomNavIndex = 0);
            }
          },
          child: Scaffold(
            backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: _buildBodyContent(isDark),
                  ),
                  CskhBottomNavC1(
                    currentIndex: _currentBottomNavIndex,
                    onTabSelected: (idx) => setState(() => _currentBottomNavIndex = idx),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(bool isDark) {
    if (_currentBottomNavIndex == 1) {
      return CskhTabDuyetPhongC1(
        tenKhoaHienTai: _tenKhoaHienTai,
        khoaIdHienTai: _khoaIdHienTai,
        ngayChon: _ngayChon,
        onSelectKhoa: _moModalChonKhoa,
        onSelectDate: _chonNgay,
        onSelectPhong: _onSelectPhong,
      );
    }

    if (_currentBottomNavIndex == 2) {
      return const CskhDanhsachTinnhanScreenC1();
    }

    if (_currentBottomNavIndex == 3) {
      return CskhProfileTabC1(
        onChuyenSangLeTan: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LeTanHomeScreenC1()),
            );
          }
        },
        onDangXuat: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
          }
        },
      );
    }

    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CskhDepartmentSelectorCardC1(
            tenKhoaHienTai: _tenKhoaHienTai,
            onChangeDepartment: _moModalChonKhoa,
          ),
          _buildBannerTongDon(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THỐNG KÊ DUYỆT ĐƠN HÔM NAY',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              InkWell(
                onTap: _chonNgay,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        '${_ngayChon.day}/${_ngayChon.month}',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CskhStatsRowC1(
            tenKhoa: _tenKhoaHienTai,
            ngayChon: _ngayChon,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DANH SÁCH CHUYÊN KHOA',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CskhDanhsachDonKhoaScreenC1(
                        tenKhoa: 'Tất cả các khoa (Tổng)',
                        phongKham: 'Toàn viện',
                        caKham: 'Tất cả các ca',
                        tongDon: 0,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Duyệt toàn viện',
                    style: TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseServiceC1.streamDanhSachKhoa(bvid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final danhSachKhoa = snapshot.data ?? [];
              if (danhSachKhoa.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 40,
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa có chuyên khoa nào trên Firebase',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: danhSachKhoa.map((k) {
                  final tenKhoa = (k['tenKhoa'] ?? 'Khoa Khám').toString();
                  final moTa = (k['moTaPhong'] ?? '').toString();
                  final bool isSelected = FirebaseServiceC1.laCungKhoa(tenKhoa, _tenKhoaHienTai);

                  final model = KhoaKhamModelC1(
                    tenKhoa: tenKhoa,
                    moTaPhong: moTa.isNotEmpty ? moTa : 'Phòng khám tiêu chuẩn',
                    soLuongDon: 'Duyệt đơn',
                    icon: Icons.local_hospital_rounded,
                    laKhoaDangChon: isSelected,
                  );

                  return CskhDepartmentCardC1(
                    khoa: model,
                    onTap: () => _onSelectKhoa(model),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildNutBaoCaoLoi(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        DuLieuProfileMauC1.thongTinHienTai.tenBenhVien.isNotEmpty
                            ? DuLieuProfileMauC1.thongTinHienTai.tenBenhVien
                            : 'Bệnh viện BV502',
                        style: const TextStyle(
                          color: Color(0xFF0284C7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Xin chào, Chuyên viên CSKH',
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currentBottomNavIndex == 3
                      ? 'Hồ Sơ CSKH'
                      : (_currentBottomNavIndex == 2
                          ? 'Tin Nhắn Hỗ Trợ'
                          : 'Duyệt Đơn Theo Khoa'),
                  style: TextStyle(
                    color: textCol,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => AppDesignSystemC1.batTatCheDoSangToi(),
                tooltip: isDark ? 'Chuyển giao diện Sáng' : 'Chuyển giao diện Tối',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? Colors.amber : const Color(0xFF475569),
                  size: 22,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => CskhThongBaoBottomSheetC1.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            size: 19,
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Thông báo',
                        style: TextStyle(
                          color: textCol,
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
        ],
      ),
    );
  }

  Widget _buildBannerTongDon() {
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseServiceC1.streamDanhSachKhoa(bvid),
      builder: (context, snapshot) {
        final soLuongKhoa = snapshot.hasData ? snapshot.data!.length : 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TỔNG ĐƠN KHÁM HÔM NAY',
                      style: TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Theo thời gian thực',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$soLuongKhoa Khoa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNutBaoCaoLoi(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _moBaoCaoLoi,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bug_report_outlined,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Báo Cáo Sự Cố Hệ Thống',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gửi phản hồi trực tiếp đến Ban Quản Trị Admin',
                        style: TextStyle(
                          color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
