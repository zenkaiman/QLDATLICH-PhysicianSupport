import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/khoa_service.dart';

/// KhoaProvider: quản lý trạng thái phòng khám (tạm dừng, đang khám, đóng cửa) lấy trực tiếp từ Firestore.
class KhoaProvider extends ChangeNotifier {
  final KhoaService _service = KhoaService();

  StreamSubscription<PhongKhamTrangThai>? _phongSubscription;
  String? _phongKey;
  PhongKhamTrangThai _phongTrangThai = PhongKhamTrangThai.macDinh;
  bool _phongLoaded = false;
  String? _phongError;

  PhongKhamTrangThai get phongTrangThai => _phongTrangThai;
  TrangThaiPhong get trangThaiPhong => _phongTrangThai.trangThai;
  bool get phongLoaded => _phongLoaded;
  String? get phongError => _phongError;

  @override
  void dispose() {
    _phongSubscription?.cancel();
    super.dispose();
  }

  /// startListeningPhong: bắt đầu lắng nghe trạng thái của một phòng khám (cùng phòng thì không đăng ký lại).
  void startListeningPhong({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) {
    // Bước 1: bỏ qua nếu đang lắng nghe đúng phòng này.
    final key = '$benhVienId|$khoaId|$phongKhamId';
    if (_phongKey == key && _phongSubscription != null) return;

    // Bước 2: hủy đăng ký cũ và đặt lại trạng thái.
    _phongSubscription?.cancel();
    _phongKey = key;
    _phongTrangThai = PhongKhamTrangThai.macDinh;
    _phongLoaded = false;
    _phongError = null;
    notifyListeners();

    // Bước 3: đăng ký stream mới, mỗi lần Firestore thay đổi thì cập nhật và báo giao diện.
    _phongSubscription = _service
        .theoDoiTrangThaiPhong(
          benhVienId: benhVienId,
          khoaId: khoaId,
          phongKhamId: phongKhamId,
        )
        .listen(
          (trangThai) {
            _phongTrangThai = trangThai;
            _phongLoaded = true;
            _phongError = null;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Lỗi khi lắng nghe trạng thái phòng khám: $e');
            _phongError = 'Không tải được trạng thái phòng khám.';
            notifyListeners();
          },
        );
  }

  /// stopListeningPhong: ngừng lắng nghe trạng thái phòng khám và đặt lại dữ liệu.
  void stopListeningPhong() {
    _phongSubscription?.cancel();
    _phongSubscription = null;
    _phongKey = null;
    _phongTrangThai = PhongKhamTrangThai.macDinh;
    _phongLoaded = false;
    _phongError = null;
    notifyListeners();
  }

  /// capNhatTrangThaiPhong: đổi trạng thái phòng khám (dùng ở phía nhân viên).
  Future<void> capNhatTrangThaiPhong({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required TrangThaiPhong trangThaiMoi,
  }) {
    return _service.capNhatTrangThaiPhong(
      benhVienId: benhVienId,
      khoaId: khoaId,
      phongKhamId: phongKhamId,
      trangThaiMoi: trangThaiMoi,
    );
  }
}