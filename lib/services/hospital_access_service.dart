import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_routes.dart';
import '../config/app_session.dart';
import '../providers/auth_provider.dart';
import 'letan_c1/letan_firebase_service_c1.dart';

/// Kết quả kiểm tra tư cách hợp tác của bệnh viện gắn với tài khoản.
enum HospitalAccessStatus { hopLe, khongTonTai, ngungHopTac, loiKiemTra }

class HospitalAccessResult {
  const HospitalAccessResult(this.status, {this.giaTri});

  final HospitalAccessStatus status;

  /// Giá trị thô của `trang_thai_hop_tac_id` (dùng trong câu thông báo).
  final Object? giaTri;

  bool get hopLe => status == HospitalAccessStatus.hopLe;

  String get thongBao => switch (status) {
    HospitalAccessStatus.hopLe => '',
    HospitalAccessStatus.khongTonTai =>
      'Bệnh viện không tồn tại hoặc tài khoản không thuộc bệnh viện nào.',
    HospitalAccessStatus.ngungHopTac =>
      'Bệnh viện đã ngừng hợp tác '
          '(trạng thái ${giaTri ?? 'không xác định'}). '
          'Vui lòng liên hệ quản trị.',
    HospitalAccessStatus.loiKiemTra =>
      'Không kiểm tra được thông tin bệnh viện. Vui lòng thử lại.',
  };
}

/// Kiểm tra `trang_thai_hop_tac_id` của document `BenhVien/{benhVienId}`.
///
/// Chỉ trạng thái `10` được phép đăng nhập. Các trường hợp còn lại
/// (không có document, thiếu trường, giá trị khác 10, lỗi đọc) đều bị
/// chặn: hiện thông báo rồi **tự động đăng xuất** tài khoản.
class HospitalAccessService {
  HospitalAccessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Mã trạng thái bệnh viện đang hợp tác.
  static const int trangThaiHopTacHoatDong = 10;

  static const String hospitalsCollection = 'BenhVien';

  /// Chấp nhận vài biến thể tên trường hay gặp trong dữ liệu cũ.
  static const List<String> trangThaiFields = <String>[
    'trang_thai_hop_tac_id',
    'trangThaiHopTacId',
    'trang_thai_hop_tac',
    'trangThaiHopTac',
  ];

  /// `true` (mặc định, fail-closed): thiếu trường trạng thái cũng coi như
  /// bệnh viện không tồn tại. Đặt `false` nếu dữ liệu cũ chưa có trường
  /// này và bạn muốn cho đăng nhập tạm thời.
  static bool coiThieuTruongLaKhongHopLe = true;

  /// Thông báo cần hiện TRÊN MÀN HÌNH ĐĂNG NHẬP sau khi tự động out.
  /// Lưu tạm ở đây vì Scaffold của màn hình cũ bị huỷ lúc điều hướng.
  static String? thongBaoSauDangXuat;

  final FirebaseFirestore _firestore;

  Future<HospitalAccessResult> kiemTra(String hospitalId) async {
    final id = hospitalId.trim();
    if (id.isEmpty) {
      return const HospitalAccessResult(HospitalAccessStatus.khongTonTai);
    }
    try {
      final snapshot = await _firestore
          .collection(hospitalsCollection)
          .doc(id)
          .get();
      if (!snapshot.exists) {
        return const HospitalAccessResult(HospitalAccessStatus.khongTonTai);
      }
      return _danhGia(snapshot.data() ?? <String, dynamic>{});
    } catch (_) {
      // Mất mạng / không có quyền đọc: KHÔNG cho vào (fail-closed).
      return const HospitalAccessResult(HospitalAccessStatus.loiKiemTra);
    }
  }

  HospitalAccessResult _danhGia(Map<String, dynamic> data) {
    for (final field in trangThaiFields) {
      if (!data.containsKey(field)) continue;
      final raw = data[field];
      final value = raw is int
          ? raw
          : int.tryParse(raw?.toString().trim() ?? '');
      if (value == trangThaiHopTacHoatDong) {
        return const HospitalAccessResult(HospitalAccessStatus.hopLe);
      }
      return HospitalAccessResult(
        HospitalAccessStatus.ngungHopTac,
        giaTri: raw ?? 'không có',
      );
    }
    return coiThieuTruongLaKhongHopLe
        ? const HospitalAccessResult(HospitalAccessStatus.khongTonTai)
        : const HospitalAccessResult(HospitalAccessStatus.hopLe);
  }

  /// Hiện thông báo rồi TỰ ĐỘNG out: xoá phiên "ghi nhớ đăng nhập",
  /// signOut FirebaseAuth, xoá định danh bệnh nhân, đẩy về màn `/login`.
  Future<void> tuDongDangXuat(
    BuildContext context,
    HospitalAccessResult result,
  ) async {
    final auth = context.read<AuthProvider>();
    thongBaoSauDangXuat = result.thongBao;
    await FirebaseServiceC1.xoaPhienDangNhap();
    await auth.logout();
    AppSession.xoaDinhDanhBenhNhan();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}
