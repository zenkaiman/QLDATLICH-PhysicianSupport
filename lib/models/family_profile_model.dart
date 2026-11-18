import 'package:cloud_firestore/cloud_firestore.dart';

/// Hồ sơ bệnh nhân: BenhNhan/{uid}/profiles/{profileId}
/// - Hồ sơ chính chủ có id cố định [selfId].
/// - `isDefault` = hồ sơ được chọn sẵn khi mở app.
class FamilyProfileModel {
  static const String selfId = 'profile_default';
  static const String quanHeBanThan = 'Chính tôi';
  static const List<String> quanHeOptions = [
    'Bố',
    'Mẹ',
    'Con',
    'Vợ',
    'Chồng',
    'Anh/Chị/Em',
    'Ông/Bà',
    'Khác',
  ];
  static const List<String> gioiTinhOptions = ['Nam', 'Nữ', 'Khác'];

  final String id;
  final String hoTen;
  final DateTime? ngaySinh;
  final String gioiTinh;
  final String soCccd;
  final String soDienThoai;
  final String quanHe;
  final String anhDaiDien;
  final bool isDefault;
  final DateTime? createdAt;

  const FamilyProfileModel({
    required this.id,
    required this.hoTen,
    this.ngaySinh,
    this.gioiTinh = '',
    this.soCccd = '',
    this.soDienThoai = '',
    this.quanHe = quanHeBanThan,
    this.anhDaiDien = '',
    this.isDefault = false,
    this.createdAt,
  });

  bool get isSelf => id == selfId;
  int? get namSinh => ngaySinh?.year;

  /// Tên ngắn hiển thị dưới avatar: "Tôi" hoặc tên (từ cuối của họ tên).
  String get shortName {
    if (isSelf) return 'Tôi';
    final w = hoTen.trim().split(RegExp(r'\s+'));
    return w.isEmpty || w.last.isEmpty ? quanHe : w.last;
  }

  String get initials {
    final w = hoTen.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) return w[0][0].toUpperCase();
    return '${w.first[0]}${w.last[0]}'.toUpperCase();
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory FamilyProfileModel.fromMap(Map<String, dynamic> m, String id) {
    return FamilyProfileModel(
      id: id,
      hoTen: (m['ho_ten'] ?? '').toString(),
      ngaySinh: _date(m['ngay_sinh']),
      gioiTinh: (m['gioi_tinh'] ?? '').toString(),
      soCccd: (m['so_cccd'] ?? '').toString(),
      soDienThoai: (m['so_dien_thoai'] ?? '').toString(),
      quanHe: (m['quan_he'] ?? quanHeBanThan).toString(),
      anhDaiDien: (m['anh_dai_dien'] ?? '').toString(),
      isDefault: m['is_default'] == true,
      createdAt: _date(m['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'ho_ten': hoTen,
        'ngay_sinh': ngaySinh == null ? null : Timestamp.fromDate(ngaySinh!),
        'gioi_tinh': gioiTinh,
        'so_cccd': soCccd,
        'so_dien_thoai': soDienThoai,
        'quan_he': quanHe,
        'anh_dai_dien': anhDaiDien,
        'is_default': isDefault,
      };

  FamilyProfileModel copyWith({
    String? hoTen,
    DateTime? ngaySinh,
    String? gioiTinh,
    String? soCccd,
    String? soDienThoai,
    String? quanHe,
    String? anhDaiDien,
    bool? isDefault,
  }) {
    return FamilyProfileModel(
      id: id,
      hoTen: hoTen ?? this.hoTen,
      ngaySinh: ngaySinh ?? this.ngaySinh,
      gioiTinh: gioiTinh ?? this.gioiTinh,
      soCccd: soCccd ?? this.soCccd,
      soDienThoai: soDienThoai ?? this.soDienThoai,
      quanHe: quanHe ?? this.quanHe,
      anhDaiDien: anhDaiDien ?? this.anhDaiDien,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
    );
  }
}