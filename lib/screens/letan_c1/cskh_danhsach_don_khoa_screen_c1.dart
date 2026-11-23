import 'package:flutter/material.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_profile_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'cskh_duyetdon_khoa_screen_c1.dart';
import 'widgets/cskh_appointment_card_c1.dart';
import 'widgets/cskh_banner_tien_do_c1.dart';
import 'widgets/cskh_bulk_action_bar_c1.dart';
import 'widgets/cskh_reject_reason_bottom_sheet_c1.dart';
import 'widgets/letan_khoa_ca_truc_widget_c1.dart';

/// MÀN HÌNH DANH SÁCH ĐƠN KHÁM CẦN DUYỆT (KHOA HOẶC TỔNG THỂ TOÀN VIỆN)
/// Kết nối thời gian thực với Firestore, hỗ trợ duyệt/từ chối lưu trực tiếp lên database.
class CskhDanhsachDonKhoaScreenC1 extends StatefulWidget {
  final String tenKhoa;
  final String phongKham;
  final String caKham;
  final int tongDon;
  final DateTime? ngayChonBanDau;
  final String? tabBanDau;

  const CskhDanhsachDonKhoaScreenC1({
    super.key,
    this.tenKhoa = 'Khoa Tim Mạch',
    this.phongKham = 'Phòng 201',
    this.caKham = 'Ca sáng',
    this.tongDon = 25,
    this.ngayChonBanDau,
    this.tabBanDau,
  });

  @override
  State<CskhDanhsachDonKhoaScreenC1> createState() => _CskhDanhsachDonKhoaScreenC1State();
}

class _CskhDanhsachDonKhoaScreenC1State extends State<CskhDanhsachDonKhoaScreenC1> {
  late DateTime _ngayChon;
  late String _phongHienTai;
  String _tabBoLocHienTai = 'Tất cả'; // 'Tất cả', 'Chờ duyệt', 'Đã duyệt', 'Đã hủy'
  final List<String> _danhSachTabs = ['Tất cả', 'Chờ duyệt', 'Đã duyệt', 'Đã hủy'];

  // Bộ nhớ đệm giữ chỗ STT theo thời gian thực (Local Memory Lock) chống trễ mạng
  // Map: id lịch hẹn -> STT vừa cấp trong phiên
  final Map<String, int> _sttVuaCapTrongPhien = {};

  @override
  void initState() {
    super.initState();
    _phongHienTai = widget.phongKham;
    _ngayChon = widget.ngayChonBanDau ?? DateTime.now();
    if (widget.tabBanDau != null && _danhSachTabs.contains(widget.tabBanDau)) {
      _tabBoLocHienTai = widget.tabBanDau!;
    }
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
      setState(() {
        _ngayChon = picked;
        _sttVuaCapTrongPhien.clear();
      });
    }
  }

  // Duyệt 1 đơn khám với Optimistic UI update
  void _duyetDon(Map<String, dynamic> don, [List<Map<String, dynamic>>? danhSachHienCo]) async {
    AppDesignSystemC1.hapticLight();
    final appointmentId = don['id'];
    final docPath = don['docPath'];

    // 1. Quét kết hợp giữa danh sách trên màn hình VÀ bộ nhớ đệm giữ chỗ (_sttVuaCapTrongPhien):
    // Đảm bảo dù bạn có bấm duyệt 10 người liên tục trong 1 giây cũng KHÔNG BAO GIỜ bị trùng số!
    final Set<int> usedNumbers = {};

    // Gom các số từ danh sách snapshot
    if (danhSachHienCo != null && danhSachHienCo.isNotEmpty) {
      for (var item in danhSachHienCo) {
        if (item['id'] == appointmentId) continue;

        final rawId = (item['trangThaiId'] ?? '').toString();
        final rawStr = (item['rawTrangThai'] ?? '').toString().toLowerCase();
        final tt = (item['trangThai'] ?? '').toString();

        final bool daDuyet = rawId == '2' || rawId == '5' || rawStr.contains('duyet') || rawStr.contains('xac_nhan') || tt == 'Đã duyệt' || tt == 'Đã khám';
        if (!daDuyet) continue;

        final sttVal = item['so_thu_tu'] ?? item['stt'];
        if (sttVal != null) {
          final p = int.tryParse(sttVal.toString());
          if (p != null && p > 0) {
            usedNumbers.add(p);
          }
        }
      }
    }

    // Gom thêm các số vừa mới cấp trong phiên (chưa kịp snapshot từ Firestore)
    _sttVuaCapTrongPhien.forEach((id, stt) {
      if (id != appointmentId && stt > 0) {
        usedNumbers.add(stt);
      }
    });

    // Tìm số nhỏ nhất từ 1 trở đi chưa có trong usedNumbers để lấp lỗ trống
    int candidate = 1;
    while (usedNumbers.contains(candidate)) {
      candidate++;
    }
    final int sttChiDinh = candidate;

    // Khóa ngay lập tức số này trong bộ nhớ để đơn kế tiếp không lấy trùng
    if (appointmentId != null) {
      _sttVuaCapTrongPhien[appointmentId.toString()] = sttChiDinh;
    }

    // Optimistic UI: Phản hồi ngay lập tức để người dùng không phải chờ đợi mạng
    AppDesignSystemC1.showCustomSnackBar(
      context,
      message: '✓ Đang phê duyệt đơn của ${don['hoTen']} - Cấp STT: #$sttChiDinh...',
      isSuccess: true,
      icon: Icons.hourglass_top_rounded,
    );

    int? soThuTuMoi;
    try {
      if (appointmentId != null) {
        soThuTuMoi = await FirebaseServiceC1.capNhatTrangThaiLichHen(
          appointmentId: appointmentId,
          docPath: docPath,
          trangThaiMoi: 'da_duyet',
          soThuTuChiDinh: sttChiDinh,
          khoaId: widget.tenKhoa,
          phongKhamId: don['phong_kham_id'] ?? _phongHienTai,
          ngayChon: _ngayChon,
        );
      }
      AppDesignSystemC1.hapticSuccess();
      if (mounted && soThuTuMoi != null) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✓ Đã duyệt thành công: ${don['hoTen']} - STT: #$soThuTuMoi',
          isSuccess: true,
          icon: Icons.verified_rounded,
        );
      }
    } catch (e) {
      if (appointmentId != null) {
        _sttVuaCapTrongPhien.remove(appointmentId.toString());
      }
      AppDesignSystemC1.hapticError();
      if (mounted) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✕ Không thể duyệt đơn của ${don['hoTen']}: Vui lòng thử lại!',
          isSuccess: false,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  // Mở Popup chọn lý do từ chối đơn khám
  void _moPopupTuChoiDon(Map<String, dynamic> don) {
    final appointmentId = don['id']?.toString();
    CskhRejectReasonBottomSheetC1.show(
      context: context,
      don: don,
      onRejected: () {
        // Khi hủy đơn: giải phóng số thứ tự khỏi bộ nhớ đệm phiên
        if (appointmentId != null) {
          _sttVuaCapTrongPhien.remove(appointmentId);
        }
      },
    );
  }

  // Duyệt hết toàn bộ đơn đang chờ trên Firestore với Optimistic UI
  void _duyetHetTatCa(List<Map<String, dynamic>> danhSach) async {
    AppDesignSystemC1.hapticLight();
    AppDesignSystemC1.showCustomSnackBar(
      context,
      message: '⏳ Đang duyệt ${danhSach.length} đơn khám...',
      isSuccess: true,
      icon: Icons.hourglass_top_rounded,
    );
    try {
      await FirebaseServiceC1.duyetTatCaLichHen(
        danhSachDon: danhSach,
        khoaId: widget.tenKhoa,
        phongKhamId: _phongHienTai,
        ngayChon: _ngayChon,
      );
      AppDesignSystemC1.hapticSuccess();
      if (mounted) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✓ Đã xác nhận tất cả các đơn khám theo thứ tự thời gian đặt!',
          isSuccess: true,
          icon: Icons.done_all_rounded,
        );
      }
    } catch (_) {
      AppDesignSystemC1.hapticError();
      if (mounted) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✕ Xảy ra lỗi khi duyệt hàng loạt đơn!',
          isSuccess: false,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  // Từ chối toàn bộ các đơn đang chờ trên Firestore với Optimistic UI
  void _tuChoiHetTatCa(List<Map<String, dynamic>> danhSach) async {
    AppDesignSystemC1.hapticLight();
    AppDesignSystemC1.showCustomSnackBar(
      context,
      message: '⏳ Đang từ chối các đơn chờ duyệt...',
      isSuccess: false,
      icon: Icons.hourglass_top_rounded,
    );
    try {
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
      AppDesignSystemC1.hapticSuccess();
      if (mounted) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✕ Đã cập nhật không duyệt hết các đơn chờ!',
          isSuccess: false,
          icon: Icons.block_rounded,
        );
      }
    } catch (_) {
      AppDesignSystemC1.hapticError();
      if (mounted) {
        AppDesignSystemC1.showCustomSnackBar(
          context,
          message: '✕ Lỗi kết nối khi cập nhật đơn!',
          isSuccess: false,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PhanCongCaTrucModelC1>(
      stream: FirebaseServiceC1.streamPhanCongCaTruc(ngayChon: _ngayChon),
      builder: (context, phanCongSnap) {
        final phanCong = phanCongSnap.data ?? PhanCongCaTrucModelC1.chuaPhanCong();

        return ValueListenableBuilder<bool>(
          valueListenable: AppDesignSystemC1.isDarkMode,
          builder: (context, isDark, child) {
            final bvid = DuLieuProfileMauC1.thongTinHienTai.benhVienId;
            final khoaHienTaiProfile = DuLieuProfileMauC1.thongTinHienTai.khoa;

            // KIỂM TRA PHÂN CÔNG CA TRỰC: Bắt buộc trang_thai_id == 16 mới được vào duyệt đơn
            if (!phanCong.duocPhanCong) {
              return Scaffold(
                backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
                appBar: AppBar(
                  title: const Text('Ca trực tạm khóa'),
                  backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                ),
                body: LetanKhoaCaTrucWidgetC1(
                  phanCong: phanCong,
                  onChuyenProfile: () => Navigator.pop(context),
                  tenChucNangBiKhoa: 'Duyệt đơn theo khoa',
                ),
              );
            }

            // KIỂM TRA PHÂN QUYỀN CHẶN DUYỆT CHÉO KHOA:
        // Nhân viên thuộc khoa nào chỉ được phép xem & duyệt đúng khoa đó
        final bool laKhoaHopLe = FirebaseServiceC1.laCheDoTong(khoaHienTaiProfile) ||
            FirebaseServiceC1.laCungKhoa(widget.tenKhoa, khoaHienTaiProfile);

        if (!laKhoaHopLe) {
          return Scaffold(
            backgroundColor: isDark ? AppDesignSystemC1.darkBackground : const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Truy cập bị từ chối'),
              backgroundColor: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black87,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gpp_bad_rounded, size: 64, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      'Không có quyền truy cập khoa này!',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tài khoản của bạn được phân công tại "$khoaHienTaiProfile". Bạn không được phép xem hoặc duyệt đơn của "${widget.tenKhoa}".',
                      style: TextStyle(
                        color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                        fontSize: 13.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Quay lại'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystemC1.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseServiceC1.streamDanhSachLichHen(
            tenKhoa: widget.tenKhoa,
            phongKham: _phongHienTai,
            ngayChon: _ngayChon,
            benhVienId: bvid,
            choPhepChoDuyet: true,
          ),
          builder: (context, snapshot) {
            final danhSach = snapshot.data ?? [];
            final soDonChoDuyet = danhSach.where((e) {
              final rawId = (e['trangThaiId'] ?? '').toString();
              final rawStr = (e['rawTrangThai'] ?? '').toString().toLowerCase();
              final tt = (e['trangThai'] ?? '').toString();
              return rawId == '1' || rawStr.contains('cho_duyet') || rawStr.contains('pending') || tt == 'Chờ duyệt' || tt == 'Đang chờ';
            }).length;
            final tong = danhSach.length;

            // Lọc danh sách theo tab được chọn: Tất cả / Chờ duyệt / Đã duyệt / Đã hủy
            final danhSachHienThi = danhSach.where((e) {
              if (_tabBoLocHienTai == 'Tất cả') return true;
              final rawId = (e['trangThaiId'] ?? '').toString();
              final rawStr = (e['rawTrangThai'] ?? '').toString().toLowerCase();
              final tt = (e['trangThai'] ?? '').toString();

              final bool laChoDuyet = rawId == '1' || rawStr.contains('cho_duyet') || rawStr.contains('pending') || tt == 'Chờ duyệt' || tt == 'Đang chờ';
              final bool laDaDuyet = rawId == '2' || rawId == '5' || rawStr.contains('duyet') || rawStr.contains('xac_nhan') || tt == 'Đã duyệt' || tt == 'Đã khám';
              final bool laDaHuy = rawId == '4' || rawStr.contains('tu_choi') || rawStr.contains('huy') || rawStr.contains('cancel') || tt == 'Không duyệt';

              if (_tabBoLocHienTai == 'Chờ duyệt') return laChoDuyet;
              if (_tabBoLocHienTai == 'Đã duyệt') return laDaDuyet;
              if (_tabBoLocHienTai == 'Đã hủy') return laDaHuy;
              return true;
            }).toList();

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

                    // Thanh nút chuyển tab chuyển qua lại: Tất cả | Chờ duyệt | Đã duyệt | Đã hủy
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                          borderRadius: AppDesignSystemC1.borderRadMedium,
                        ),
                        child: Row(
                          children: _danhSachTabs.map((tab) {
                            final bool isSelected = _tabBoLocHienTai == tab;
                            int count = 0;
                            if (tab == 'Tất cả') {
                              count = tong;
                            } else if (tab == 'Chờ duyệt') {
                              count = soDonChoDuyet;
                            } else if (tab == 'Đã duyệt') {
                              count = danhSach.where((e) {
                                final rawId = (e['trangThaiId'] ?? '').toString();
                                final rawStr = (e['rawTrangThai'] ?? '').toString().toLowerCase();
                                final tt = (e['trangThai'] ?? '').toString();
                                return rawId == '2' || rawId == '5' || rawStr.contains('duyet') || rawStr.contains('xac_nhan') || tt == 'Đã duyệt' || tt == 'Đã khám';
                              }).length;
                            } else if (tab == 'Đã hủy') {
                              count = danhSach.where((e) {
                                final rawId = (e['trangThaiId'] ?? '').toString();
                                final rawStr = (e['rawTrangThai'] ?? '').toString().toLowerCase();
                                final tt = (e['trangThai'] ?? '').toString();
                                return rawId == '4' || rawStr.contains('tu_choi') || rawStr.contains('huy') || rawStr.contains('cancel') || tt == 'Không duyệt';
                              }).length;
                            }

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  AppDesignSystemC1.hapticLight();
                                  setState(() {
                                    _tabBoLocHienTai = tab;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tab,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? (isDark ? Colors.white : AppDesignSystemC1.primary)
                                                  : (isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B)),
                                              fontSize: 12.5,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDark ? const Color(0xFF0284C7) : const Color(0xFFE0F2FE))
                                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? (isDark ? Colors.white : const Color(0xFF0284C7))
                                                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
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

                    Expanded(
                      child: danhSachHienThi.isEmpty
                          ? Center(
                              child: Text(
                                'Không có đơn khám nào trong mục "$_tabBoLocHienTai"',
                                style: TextStyle(
                                  color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: danhSachHienThi.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = danhSachHienThi[index];
                                return CskhAppointmentCardC1(
                                  item: item,
                                  onApprove: () => _duyetDon(item, danhSach),
                                  onReject: () => _moPopupTuChoiDon(item),
                                );
                              },
                            ),
                    ),
                    if (soDonChoDuyet > 0)
                      CskhBulkActionBarC1(
                        totalCount: soDonChoDuyet,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.tenKhoa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextPrimary : const Color(0xFF0F172A),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_phongHienTai • ${widget.caKham}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppDesignSystemC1.darkTextSecondary : const Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0C2444) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
          ),
        ],
      ),
    );
  }
}
