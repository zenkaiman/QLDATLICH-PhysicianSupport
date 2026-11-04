import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'letan_baocao_thanhcong_screen_c1.dart';
import 'letan_baocaoloi_screen_c1.dart';
import 'letan_lichhen_screen_c1.dart';
import 'letan_profile_tab_c1.dart';
import 'letan_quet_qr_camera_screen_c1.dart';
import 'widgets/cskh_thong_bao_bottom_sheet_c1.dart';
import 'widgets/department_picker_modal_c1.dart';
import 'widgets/letan_bottom_nav_c1.dart';
import 'widgets/letan_patient_card_c1.dart';
import 'widgets/letan_qr_banner_c1.dart';
import 'widgets/letan_quick_actions_c1.dart';
import 'widgets/letan_stats_widget_c1.dart';

class LeTanHomeScreenC1 extends StatefulWidget {
  final String tenKhoa;

  const LeTanHomeScreenC1({
    super.key,
    this.tenKhoa = '',
  });

  @override
  State<LeTanHomeScreenC1> createState() => _LeTanHomeScreenC1State();
}

class _LeTanHomeScreenC1State extends State<LeTanHomeScreenC1> {
  int _currentIndex = 0; // 0: Trang chu, 1: Quet QR, 2: Lich hen, 3: Profile
  late String _tenKhoaHienTai;
  DateTime _ngayChon = DateTime.now();
  StreamSubscription? _subLoiDaSua;
  StreamSubscription? _subDonKhamMoi;

  @override
  void initState() {
    super.initState();
    final profileKhoa = DuLieuProfileMauC1.thongTinHienTai.khoa.trim();
    _tenKhoaHienTai = widget.tenKhoa.trim().isNotEmpty
        ? widget.tenKhoa.trim()
        : (profileKhoa.isNotEmpty ? profileKhoa : 'Toàn viện');
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
        AppDesignSystemC1.hapticLight();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch hẹn khám mới phát sinh!',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '$hoTen - $tenKhoa • Còn $soDonChuaDuyet đơn chưa duyệt',
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
              label: 'XEM',
              textColor: const Color(0xFF38BDF8),
              onPressed: () {
                setState(() => _currentIndex = 2);
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

  Future<void> _chonNgayLichHen() async {
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
      setState(() => _ngayChon = picked);
    }
  }

  void _moManHinhQuetQr() {
    setState(() => _currentIndex = 1);
  }

  void _moModalChonKhoaFirebase() {
    DepartmentPickerModalC1.show(
      context: context,
      tenKhoaHienTai: _tenKhoaHienTai,
      tieuDe: 'Chọn Khoa Tiếp Nhận',
      moTaPhu: 'Chọn chuyên khoa để lọc danh sách bệnh nhân tiếp đón tại quầy',
      onKhoaSelected: (tenKhoa, khoaId) {
        setState(() => _tenKhoaHienTai = tenKhoa);
      },
    );
  }

  void _showDialogBaoCaoLoi() {
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
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
            }
          },
          child: Scaffold(
            backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF2F2F7),
            body: SafeArea(
              child: _buildCurrentBody(),
            ),
            bottomNavigationBar: LetanBottomNavC1(
              currentIndex: _currentIndex,
              onTabSelected: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentBody() {
    if (_currentIndex == 1) {
      return const LetanQuetQrCameraScreenC1();
    }

    if (_currentIndex == 2) {
      return LetanLichhenScreenC1(
        tenKhoa: _tenKhoaHienTai,
        ngayChonBanDau: _ngayChon,
      );
    }

    if (_currentIndex == 3) {
      return LetanProfileTabC1(
        tenKhoaHienTai: _tenKhoaHienTai,
        onDangXuat: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
          }
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          LetanQrBannerC1(onTap: _moManHinhQuetQr),
          const SizedBox(height: 16),
          LetanStatsWidgetC1(
            tenKhoaHienTai: _tenKhoaHienTai,
            ngayChon: _ngayChon,
            onSelectDate: _chonNgayLichHen,
          ),
          const SizedBox(height: 16),
          _buildDanhSachCho(),
          const SizedBox(height: 16),
          LetanQuickActionsC1(
            onOpenQr: _moManHinhQuetQr,
            onOpenLichHen: () => setState(() => _currentIndex = 2),
            onOpenBaoCaoLoi: _showDialogBaoCaoLoi,
            onOpenProfile: () => setState(() => _currentIndex = 3),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final textCol = isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E);
    final subTextCol = isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: InkWell(
            onTap: _moModalChonKhoaFirebase,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          DuLieuProfileMauC1.thongTinHienTai.tenBenhVien.isNotEmpty
                              ? DuLieuProfileMauC1.thongTinHienTai.tenBenhVien
                              : 'Bệnh viện BV502',
                          style: const TextStyle(
                            color: Color(0xFFFF9500),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Xin chào, Lễ tân $_tenKhoaHienTai',
                          style: TextStyle(
                            color: subTextCol,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: subTextCol),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trang chủ Lễ tân',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
                size: 24,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => CskhThongBaoBottomSheetC1.show(
                context,
                vaiTro: 'letan',
                tieuDe: 'Thông Báo Lễ Tân',
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF007AFF),
                          size: 20,
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
                    const SizedBox(width: 6),
                    Text(
                      'Thông báo',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDanhSachCho() {
    final isDark = AppDesignSystemC1.laCheDoToi;
    final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseServiceC1.streamDanhSachLichHen(
        tenKhoa: _tenKhoaHienTai,
        boLocTrangThai: 'Đang chờ',
        ngayChon: _ngayChon,
        benhVienId: bvid,
      ),
      builder: (context, snapshot) {
        final danhSach = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách đang chờ',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1C1C1E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${danhSach.length} bệnh nhân',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (danhSach.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE5E5EA)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Hiện chưa có bệnh nhân nào chờ khám',
                  style: TextStyle(
                    color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF8E8E93),
                    fontSize: 13,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: danhSach.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return LetanPatientCardC1(item: danhSach[index]);
                },
              ),
          ],
        );
      },
    );
  }
}
