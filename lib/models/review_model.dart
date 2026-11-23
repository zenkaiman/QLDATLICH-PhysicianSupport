import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String benhNhanId;
  final String benhVienId;
  final String khoaId;
  final String lichHenId;
  final int diemDanhGia;
  final String nhanXet;
  final bool anDanh;
  final DateTime ngayTao;
  final DateTime? ngayDanhGia;
  final String tenBenhVien;
  final String tenKhoa;

  final String tenBenhNhan;

  ReviewModel({
    required this.id,
    required this.benhNhanId,
    required this.benhVienId,
    required this.khoaId,
    required this.lichHenId,
    required this.diemDanhGia,
    required this.nhanXet,
    required this.anDanh,
    required this.ngayTao,
    this.ngayDanhGia,
    required this.tenBenhVien,
    required this.tenKhoa,
    required this.tenBenhNhan,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json, String docId) {
    return ReviewModel(
      id: json['id'] ?? docId,
      benhNhanId: json['benh_nhan_id']?.toString() ?? '',
      benhVienId: json['benh_vien_id']?.toString() ?? '',
      khoaId: json['khoa_id']?.toString() ?? '',
      lichHenId: json['lich_hen_id']?.toString() ?? '',
      diemDanhGia: (json['diem_danh_gia'] as num?)?.toInt() ?? 0,
      nhanXet: json['nhan_xet']?.toString() ?? '',
      anDanh: json['an_danh'] == 1 || json['an_danh'] == true,
      ngayTao: (json['ngay_tao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ngayDanhGia: (json['ngay_danh_gia'] as Timestamp?)?.toDate(),
      tenBenhVien: json['ten_benh_vien']?.toString() ?? '',
      tenKhoa: json['ten_khoa']?.toString() ?? '',
      tenBenhNhan: json['ten_benh_nhan']?.toString() ?? 'Bệnh nhân',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'benh_nhan_id': benhNhanId,
      'benh_vien_id': benhVienId,
      'khoa_id': khoaId,
      'lich_hen_id': lichHenId,
      'diem_danh_gia': diemDanhGia,
      'nhan_xet': nhanXet,
      'an_danh': anDanh ? 1 : 0,
      'ngay_tao': Timestamp.fromDate(ngayTao),
      if (ngayDanhGia != null)
        'ngay_danh_gia': Timestamp.fromDate(ngayDanhGia!),
      'ten_benh_vien': tenBenhVien,
      'ten_khoa': tenKhoa,
      'ten_benh_nhan': tenBenhNhan,
    };
  }

  String get displayName {
    if (anDanh) return 'Người dùng ẩn danh';
    return tenBenhNhan.isEmpty ? 'Bệnh nhân' : tenBenhNhan;
  }
}
