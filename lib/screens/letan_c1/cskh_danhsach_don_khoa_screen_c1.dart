import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_duyetdon_khoa_screen_c1.dart';
import 'widgets/cskh_appointment_card_c1.dart';
import 'widgets/cskh_banner_tien_do_c1.dart';
import 'widgets/cskh_bulk_action_bar_c1.dart';
import 'widgets/cskh_reject_reason_bottom_sheet_c1.dart';

/// MÀN HÌNH DANH SÁCH ĐƠN KHÁM CẦN DUYỆT (KHOA HOẶC TỔNG THỂ TOÀN VIỆN)
/// Kết nối thời gian thực với Firestore, hỗ trợ duyệt/từ chối lưu trực tiếp lên database.
class CskhDanhsachDonKhoaScreenC1 extends StatefulWidget {
  final String tenKhoa;
  final String phongKham;
  final String caKham;
  final int tongDon;

  const CskhDanhsachDonKhoaScreenC1({
    super.key,
    this.tenKhoa = 'Khoa Tim Mạch',
    this.phongKham = 'Phòng 201',
    this.caKham = 'Ca sáng',
    this.tongDon = 25,
  });

  @override
  State<CskhDanhsachDonKhoaScreenC1> createState() => _CskhDanhsachDonKhoaScreenC1State();
}

class _CskhDanhsachDonKhoaScreenC1State extends State<CskhDanhsachDonKhoaScreenC1> {
  DateTime _ngayChon = DateTime.now();
  late String _phongHienTai;

  @override
  void initState() {
    super.initState();
    _phongHienTai = widget.phongKham;
  }

  Future<void> _chonNgayLichHen() async {
    AppDesignSystemC1.hapticLight();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayChon,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY DUYỆT ĐƠN KHÁM',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
    );
    if (picked != null && picked != _ngayChon) {
      setState(() => _ngayChon = picked);
    }
  }

  // Duyệt 1 đơn khám và cập nhật Firestore
  void _duyetDon(Map<String, dynamic> don) async {
    AppDesignSystemC1.hapticLight();
    final appointmentId = don['id'];
    final docPath = don['docPath'];
    int? soThuTuMoi;

    if (appointmentId != null) {
      soThuTuMoi = await FirebaseServiceC1.capNhatTrangThaiLichHen(
        appointmentId: appointmentId,
        docPath: docPath,
        trangThaiMoi: 'da_duyet',
        phongKhamId: don['phong_kham_id'] ?? _phongHienTai,
        ngayChon: _ngayChon,
      );
    }
    if (mounted) {
      final sttHienThi = soThuTuMoi ?? don['stt'] ?? 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Đã xác nhận đơn của ${don['hoTen']} - Cấp STT: #$sttHienThi'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Mở Popup chọn lý do từ chối đơn khám
  void _moPopupTuChoiDon(Map<String, dynamic> don) {
    CskhRejectReasonBottomSheetC1.show(
      context: context,
      don: don,
    );
  }

  // Duyệt hết toàn bộ đơn đang chờ trên Firestore
  void _duyetHetTatCa(List<Map<String, dynamic>> danhSach) async {
    AppDesignSystemC1.hapticLight();
    for (var don in danhSach) {
      final trangThai = (don['rawTrangThai'] ?? '').toString();
      if (trangThai != 'da_duyet' && trangThai != 'da_kham') {
        final id = don['id'];
        final docPath = don['docPath'];
        if (id != null) {
          await FirebaseServiceC1.capNhatTrangThaiLichHen(
            appointmentId: id,
            docPath: docPath,
            trangThaiMoi: 'da_duyet',
            phongKhamId: don['phong_kham_id'] ?? _phongHienTai,
            ngayChon: _ngayChon,
          );
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đã xác nhận tất cả các đơn khám theo thứ tự thời gian đặt!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Từ chối toàn bộ các đơn đang chờ trên Firestore
  void _tuChoiHetTatCa(List<Map<String, dynamic>> danhSach) async {
    AppDesignSystemC1.hapticLight();
    for (var don in danhSach) {
      final trangThai = (don['rawTrangThai'] ?? '').toString();
      if (trangThai != 'da_duyet' && trangThai != 'da_kham') {
        final id = don['id'];
        final docPath = don['docPath'];
        if (id != null) {
          await FirebaseServiceC1.capNhatTrangThaiLichHen(
            appointmentId: id,
            docPath: docPath,
            trangThaiMoi: 'tu_choi',
            lyDoTuChoi: 'Phòng khám đã đủ số lượng tiếp nhận tối đa',
          );
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✕ Đã cập nhật không duyệt hết các đơn chờ!'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppDesignSystemC1.isDarkMode,
      builder: (context, isDark, child) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseServiceC1.streamDanhSachLichHen(
            tenKhoa: widget.tenKhoa,
            phongKham: _phongHienTai,
            ngayChon: _ngayChon,
          ),
          builder: (context, snapshot) {
            final danhSach = snapshot.data ?? [];
            final soDonChoDuyet = danhSach.where((e) => e['rawTrangThai'] == 'dang_cho' || e['rawTrangThai'] == 'cho_duyet' || e['trangThai'] == 'Đang chờ').length;
            final tong = danhSach.length;

            return Scaffold(
              backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(isDark, tong),
                    CskhBannerTienDoC1(
                      ngayChon: _ngayChon,
                      choDuyet: soDonChoDuyet,
                      tong: tong,
                      onSelectDate: _chonNgayLichHen,
                    ),
                    Expanded(
                      child: danhSach.isEmpty
                          ? Center(
                              child: Text(
                                'Chưa có đơn khám nào cần duyệt',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: danhSach.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = danhSach[index];
                                return CskhAppointmentCardC1(
                                  item: item,
                                  onApprove: () => _duyetDon(item),
                                  onReject: () => _moPopupTuChoiDon(item),
                                );
                              },
                            ),
                    ),
                    CskhBulkActionBarC1(
                      totalCount: danhSach.length,
                      onRejectAll: () => _tuChoiHetTatCa(danhSach),
                      onApproveAll: () => _duyetHetTatCa(danhSach),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Header màn hình duyệt đơn khoa
  Widget _buildHeader(bool isDark, [int? tongSoReal]) {
    final int hienThiTong = tongSoReal ?? widget.tongDon;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CskhDuyetdonKhoaScreenC1()),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF1E293B),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.tenKhoa,
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_phongHienTai • ${widget.caKham}',
                style: TextStyle(
                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$hienThiTong Đơn',
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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
