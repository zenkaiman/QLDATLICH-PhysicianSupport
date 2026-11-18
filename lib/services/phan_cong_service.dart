import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/nhan_vien_model.dart';
import '../models/phan_cong_model.dart';

class PhanCongService {
  final FirebaseFirestore _firestore;

  PhanCongService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Tạo mã vai trò cho phân công trực: ví dụ LT001, LT002, BS001,...
  /// ID collection chuẩn: tg_tenkhoa_vaitro (ví dụ: 2026-11-18_DL001_LT001)
  static String taoMaVaiTro(
    NhanVienModel nv, [
    List<Map<String, dynamic>> dangTrucTrongPhong = const [],
  ]) {
    String prefix = 'NV';
    final maNvUpper = nv.maNv.toUpperCase();
    final vaiTroLower = nv.vaiTro.toLowerCase();

    if (maNvUpper.contains('_LT_') ||
        vaiTroLower.contains('lễ tân') ||
        vaiTroLower.contains('le tan') ||
        vaiTroLower.contains('reception')) {
      prefix = 'LT';
    } else if (maNvUpper.contains('_BS_') ||
        vaiTroLower.contains('bác sĩ') ||
        vaiTroLower.contains('bac si') ||
        vaiTroLower.contains('doctor') ||
        vaiTroLower.contains('support')) {
      prefix = 'BS';
    } else if (maNvUpper.contains('_DD_') ||
        vaiTroLower.contains('điều dưỡng') ||
        vaiTroLower.contains('dieu duong') ||
        vaiTroLower.contains('nurse')) {
      prefix = 'DD';
    } else if (maNvUpper.contains('_DS_') ||
        vaiTroLower.contains('dược sĩ') ||
        vaiTroLower.contains('duoc si') ||
        vaiTroLower.contains('pharmacist')) {
      prefix = 'DS';
    } else if (maNvUpper.contains('_CSKH_') ||
        vaiTroLower.contains('cskh') ||
        vaiTroLower.contains('chăm sóc')) {
      prefix = 'CSKH';
    } else if (maNvUpper.contains('_KT_') ||
        vaiTroLower.contains('kỹ thuật') ||
        vaiTroLower.contains('ky thuat')) {
      prefix = 'KT';
    }

    final usedIndices = <int>{};
    for (final pc in dangTrucTrongPhong) {
      final code = (pc['vai_tro_code'] ?? '').toString().toUpperCase();
      if (code.startsWith(prefix)) {
        final numPart = code.substring(prefix.length);
        final val = int.tryParse(numPart);
        if (val != null) {
          usedIndices.add(val);
        }
      }
    }

    int nextIndex = 1;
    while (usedIndices.contains(nextIndex)) {
      nextIndex++;
    }

    return '$prefix${nextIndex.toString().padLeft(3, '0')}';
  }

  /// Xác nhận phân công một nhân viên vào phòng trực
  Future<String> xacNhanPhanCong({
    required String benhVienId,
    required String ngayStr,
    required PhongItemPhanCong phong,
    required String khoaId,
    required String tenKhoa,
    required String prefixKhoa,
    required NhanVienModel nv,
    required List<Map<String, dynamic>> dangTrucTrongPhong,
  }) async {
    final roleCode = taoMaVaiTro(nv, dangTrucTrongPhong);
    final docId = '${ngayStr}_${phong.tenPhong}_$roleCode';
    final batch = _firestore.batch();

    // 1. Cập nhật nhân viên được phân công vào NhanVien/{bvid}/danh_sach/{maNv}
    // Trạng thái: id = 16, ten_trang_thai = "đã phân công" (khớp collection TrangThai doc 16)
    final nvDocId = nv.id.isNotEmpty ? nv.id : nv.maNv;
    final nvRef = _firestore
        .collection('NhanVien')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(nvDocId);

    batch.set(nvRef, {
      'trang_thai_id': 16,
      'trang_thai': 'đã phân công',
      'trang_thai_phan_cong': FieldValue.delete(),
      'trang_thai_phan_cong_id': FieldValue.delete(),
      'ngay_phan_cong': ngayStr,
      'phong_phan_cong': phong.tenPhong,
      'khoa_phan_cong': tenKhoa,
      'vai_tro_code': roleCode,
      'lich_phan_cong': {
        ngayStr: {
          'trang_thai_id': 16,
          'trang_thai': 'đã phân công',
          'phong': phong.tenPhong,
          'khoa': tenKhoa,
          'vai_tro_code': roleCode,
          'doc_id': docId,
          'ngay': ngayStr,
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));

    // 2. Lưu vào collection chuẩn PhanCong/{benhVienId}/danh_sach/{docId}
    final pcRef = _firestore
        .collection('PhanCong')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(docId);

    batch.set(pcRef, {
      'id': docId,
      'ngay': ngayStr,
      'benh_vien_id': benhVienId,
      'khoa_id': khoaId,
      'ten_khoa': tenKhoa,
      'prefix_khoa': prefixKhoa,
      'phong_id': phong.tenPhong,
      'ten_phong': phong.tenPhong,
      'vai_tro_code': roleCode,
      'nhan_vien_id': nv.maNv,
      'ma_nhan_vien': nv.maNv,
      'ten_nhan_vien': nv.hoTen,
      'vai_tro': nv.vaiTro,
      'trang_thai_id': 16,
      'trang_thai': 'đã phân công',
      'ngay_cap_nhat': FieldValue.serverTimestamp(),
    });

    // 3. Cập nhật subcollection Khoa/.../phongKham
    final subPkRef = _firestore
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(khoaId)
        .collection('phongKham')
        .doc(phong.tenPhong);

    batch.set(subPkRef, {
      'nhan_vien_id': nv.maNv,
      'nhanVienId': nv.maNv,
      'ten_nhan_vien': nv.hoTen,
      'vai_tro_nhan_vien': nv.vaiTro,
    }, SetOptions(merge: true));

    // 4. Cập nhật root collection PhongKham
    final pkDocId = '${benhVienId}_${khoaId}_${phong.tenPhong}';
    final rootPkRef = _firestore.collection('PhongKham').doc(pkDocId);

    batch.set(rootPkRef, {
      'nhan_vien_id': nv.maNv,
      'nhanVienId': nv.maNv,
    }, SetOptions(merge: true));

    await batch.commit();
    return roleCode;
  }

  /// Hủy phân công một nhân viên / vai trò cụ thể
  Future<void> huyPhanCongMotNhanVien({
    required String benhVienId,
    required String ngayStr,
    required PhongItemPhanCong phong,
    required String khoaId,
    required Map<String, dynamic> pcData,
    required int soLuongDangTruc,
  }) async {
    final docId = (pcData['id'] ??
            pcData['_docId'] ??
            '${ngayStr}_${phong.tenPhong}_${pcData['vai_tro_code']}')
        .toString();
    final maNv =
        (pcData['nhan_vien_id'] ?? pcData['ma_nhan_vien'] ?? '').toString();

    final batch = _firestore.batch();

    // Cập nhật nhân viên về trạng thái 15 ("chờ")
    if (maNv.isNotEmpty) {
      final nvRef = _firestore
          .collection('NhanVien')
          .doc(benhVienId)
          .collection('danh_sach')
          .doc(maNv);

      batch.set(nvRef, {
        'trang_thai_id': 15,
        'trang_thai': 'chờ',
        'trang_thai_phan_cong': FieldValue.delete(),
        'trang_thai_phan_cong_id': FieldValue.delete(),
        'ngay_phan_cong': null,
        'phong_phan_cong': null,
        'khoa_phan_cong': null,
        'vai_tro_code': null,
        'lich_phan_cong': {
          ngayStr: {
            'trang_thai_id': 15,
            'trang_thai': 'chờ',
            'ngay': ngayStr,
            'ngay_cap_nhat': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
    }

    // Xóa document phân công tương ứng trong PhanCong/{benhVienId}/danh_sach
    final pcRef = _firestore
        .collection('PhanCong')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(docId);
    batch.delete(pcRef);

    // Nếu chỉ còn 1 người trực và đang bị hủy, xóa gán nhân viên ở phòng khám
    if (soLuongDangTruc <= 1) {
      final subPkRef = _firestore
          .collection('Khoa')
          .doc(benhVienId)
          .collection('danh_sach')
          .doc(khoaId)
          .collection('phongKham')
          .doc(phong.tenPhong);
      batch.set(subPkRef, {
        'nhan_vien_id': null,
        'nhanVienId': null,
        'ten_nhan_vien': null,
        'vai_tro_nhan_vien': null,
      }, SetOptions(merge: true));

      final pkDocId = '${benhVienId}_${khoaId}_${phong.tenPhong}';
      final rootPkRef = _firestore.collection('PhongKham').doc(pkDocId);
      batch.set(rootPkRef, {
        'nhan_vien_id': null,
        'nhanVienId': null,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Hủy phân công toàn bộ vai trò phòng này
  Future<void> huyToanBoPhanCongPhong({
    required String benhVienId,
    required String ngayStr,
    required PhongItemPhanCong phong,
    required String khoaId,
    required List<Map<String, dynamic>> danhSachDangTruc,
  }) async {
    final batch = _firestore.batch();

    for (final pc in danhSachDangTruc) {
      final docId = (pc['id'] ??
              pc['_docId'] ??
              '${ngayStr}_${phong.tenPhong}_${pc['vai_tro_code']}')
          .toString();
      final maNv =
          (pc['nhan_vien_id'] ?? pc['ma_nhan_vien'] ?? '').toString();

      if (maNv.isNotEmpty) {
        final nvRef = _firestore
            .collection('NhanVien')
            .doc(benhVienId)
            .collection('danh_sach')
            .doc(maNv);

        batch.set(nvRef, {
          'trang_thai_id': 15,
          'trang_thai': 'chờ',
          'trang_thai_phan_cong': FieldValue.delete(),
          'trang_thai_phan_cong_id': FieldValue.delete(),
          'ngay_phan_cong': null,
          'phong_phan_cong': null,
          'khoa_phan_cong': null,
          'vai_tro_code': null,
          'lich_phan_cong': {
            ngayStr: {
              'trang_thai_id': 15,
              'trang_thai': 'chờ',
              'ngay': ngayStr,
              'ngay_cap_nhat': FieldValue.serverTimestamp(),
            },
          },
        }, SetOptions(merge: true));
      }

      final pcRef = _firestore
          .collection('PhanCong')
          .doc(benhVienId)
          .collection('danh_sach')
          .doc(docId);
      batch.delete(pcRef);
    }

    final subPkRef = _firestore
        .collection('Khoa')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(khoaId)
        .collection('phongKham')
        .doc(phong.tenPhong);
    batch.set(subPkRef, {
      'nhan_vien_id': null,
      'nhanVienId': null,
      'ten_nhan_vien': null,
      'vai_tro_nhan_vien': null,
    }, SetOptions(merge: true));

    final pkDocId = '${benhVienId}_${khoaId}_${phong.tenPhong}';
    final rootPkRef = _firestore.collection('PhongKham').doc(pkDocId);
    batch.set(rootPkRef, {
      'nhan_vien_id': null,
      'nhanVienId': null,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
