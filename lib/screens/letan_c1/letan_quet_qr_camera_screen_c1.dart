import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/letan_c1/letan_design_system_c1.dart';
import '../../models/letan_c1/letan_qr_model_c1.dart';
import '../../services/letan_c1/letan_firebase_service_c1.dart';
import 'widgets/letan_qr_quick_view_bottom_sheet_c1.dart';

/// MÀN HÌNH QUÉT MÃ QR TIẾP ĐÓN BỆNH NHÂN
/// - Quét trực tiếp camera phần cứng (MobileScanner), tích hợp bật/tắt đèn Flash và đổi camera
class LetanQuetQrCameraScreenC1 extends StatefulWidget {
  const LetanQuetQrCameraScreenC1({super.key});

  @override
  State<LetanQuetQrCameraScreenC1> createState() => _LetanQuetQrCameraScreenC1State();
}

class _LetanQuetQrCameraScreenC1State extends State<LetanQuetQrCameraScreenC1> {
  late final MobileScannerController _scannerController;
  bool _batDenFlash = false;
  bool _dangXuLyMa = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // Khi camera nhận diện được mã QR thực tế
  Future<void> _xuLyKhiQuetDuocMa(BarcodeCapture capture) async {
    if (_dangXuLyMa) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    // Kiểm tra phân công ca trực (trang_thai_id == 16)
    final caTruc = await FirebaseServiceC1.kiemTraPhanCongCaTruc();
    if (!mounted) return;
    if (!caTruc.duocPhanCong) {
      AppDesignSystemC1.hapticError();
      AppDesignSystemC1.showCustomSnackBar(
        context,
        message: '✕ Quét mã bị khóa: Ca trực chưa được Bệnh viện phân công!',
        isSuccess: false,
        icon: Icons.lock_clock_rounded,
      );
      return;
    }

    setState(() => _dangXuLyMa = true);

    try {
      // 1. Phân tích mã QR từ FirebaseServiceC1
      final res = await FirebaseServiceC1.xuLyMaQrTiepNhan(rawValue);
      final bool isSuccess = res['thanh_cong'] == true;

      if (isSuccess) {
        AppDesignSystemC1.hapticSuccess();
      } else {
        AppDesignSystemC1.hapticError();
      }

      final ketQua = KetQuaQuetQrC1(
        thanhCong: res['thanh_cong'] == true,
        thongBao: (res['thong_bao'] ?? 'Xác thực QR').toString(),
        chiTietLoi: (res['chi_tiet_loi'] ?? '').toString(),
        trangThaiNgayKham: res['trang_thai_ngay_kham'] as TrangThaiNgayKhamC1? ??
            (res['thanh_cong'] == true ? TrangThaiNgayKhamC1.dungNgay : TrangThaiNgayKhamC1.khongXacDinh),
        soThuTu: res['so_thu_tu'] as int?,
        gioKhamDuKien: res['gio_kham']?.toString(),
        ngayKham: res['ngay_kham']?.toString(),
        hoTen: res['ho_ten']?.toString(),
        maLichHen: res['ma_lich_hen']?.toString() ?? res['ma_benh_nhan']?.toString(),
        maBenhNhan: res['ma_benh_nhan']?.toString(),
        namSinhGioiTinh: res['nam_sinh']?.toString(),
        cccd: res['cccd']?.toString(),
        bhyt: res['bhyt']?.toString(),
        khoaKham: res['khoa']?.toString(),
        phongKham: res['phong']?.toString(),
        caKham: res['ca_kham']?.toString(),
      );

      if (!mounted) return;
      _moManHinhKetQua(ketQua);
    } finally {
      // Cho phép quét tiếp sau 1.5 giây
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _dangXuLyMa = false);
      });
    }
  }

  void _moManHinhKetQua(KetQuaQuetQrC1 ketQua) {
    // Phương án 1 + 3: Bật Modal BottomSheet xem nhanh tại chỗ thay vì chuyển màn hình
    LetanQrQuickViewBottomSheetC1.show(
      context: context,
      ketQua: ketQua,
      onQuetTiep: () {
        if (mounted) setState(() => _dangXuLyMa = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Quét Mã QR Bệnh Nhân',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          // Nút đổi camera trước / sau
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Đổi camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
          // Nút bật/tắt đèn Flash
          IconButton(
            icon: Icon(
              _batDenFlash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _batDenFlash ? Colors.amber : Colors.white,
            ),
            tooltip: 'Đèn Flash',
            onPressed: () {
              setState(() => _batDenFlash = !_batDenFlash);
              _scannerController.toggleTorch();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Hướng camera điện thoại về phía mã QR trên app bệnh nhân',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // KHUNG CAMERA QUÉT THẬT TÍCH HỢP MOBILE_SCANNER
            Expanded(
              child: Center(
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF0284C7), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Viewfinder Camera thật từ thiết bị
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _xuLyKhiQuetDuocMa,
                          errorBuilder: (context, error) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off_rounded, color: Color(0xFFEF4444), size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Không mở được camera (${error.errorCode.name})',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Khung tia quét trang trí & loading
                        if (_dangXuLyMa)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 3),
                                  SizedBox(height: 10),
                                  Text('Đang xác thực thông tin...', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        else
                          // Tia quét laser trang trí
                          Positioned(
                            top: 130,
                            child: Container(
                              width: 240,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // THANH HƯỚNG DẪN TIẾP ĐÓN CHUYÊN NGHIỆP
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đặt mã QR của bệnh nhân vào giữa khung ngắm để hệ thống tự động nhận diện và tiếp đón.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
