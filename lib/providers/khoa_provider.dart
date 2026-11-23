import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/khoa_service.dart';

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

  /// startListeningPhong: lắng nghe trạng thái thời gian thực của một phòng khám (cùng phòng thì không đăng ký lại).
  void startListeningPhong({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) {
    final key = '$benhVienId|$khoaId|$phongKhamId';
    if (_phongKey == key && _phongSubscription != null) return;

    _phongSubscription?.cancel();
    _phongKey = key;
    _phongTrangThai = PhongKhamTrangThai.macDinh;
    _phongLoaded = false;
    _phongError = null;
    notifyListeners();

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

  /// capNhatTrangThaiPhong: đổi trạng thái phòng khám (phía nhân viên).
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

  @override
  void dispose() {
    _phongSubscription?.cancel();
    super.dispose();
  }
}