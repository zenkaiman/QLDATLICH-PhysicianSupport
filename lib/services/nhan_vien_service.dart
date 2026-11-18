import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_session.dart';
import '../models/nhan_vien_model.dart';

class NhanVienService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _nhanVienCol =>
      _db.collection('NhanVien');

  /// Chuẩn hóa ID bệnh viện: ưu tiên mã chuẩn như `BV001`
  Future<String> _chuanHoaBenhVienId(String benhVienId) async {
    final trimmed = benhVienId.trim();
    if (trimmed.startsWith('BV')) return trimmed;

    if (AppSession.benhVienId.isNotEmpty && AppSession.benhVienId.startsWith('BV')) {
      return AppSession.benhVienId;
    }

    try {
      final doc = await _db.collection('BenhVien').doc(trimmed).get();
      if (doc.exists) {
        final ma = (doc.data()?['ma_benh_vien'] ??
                doc.data()?['maBenhVien'] ??
                doc.data()?['uid'])
            ?.toString();
        if (ma != null && ma.isNotEmpty && ma.startsWith('BV')) return ma;
      }

      final query = await _db
          .collection('BenhVien')
          .where('auth_uid', isEqualTo: trimmed)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final ma = (query.docs.first.data()['ma_benh_vien'] ??
                query.docs.first.id)
            .toString();
        if (ma.isNotEmpty && ma.startsWith('BV')) return ma;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null && user!.email!.isNotEmpty) {
        final emailQ = await _db
            .collection('BenhVien')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (emailQ.docs.isNotEmpty) {
          final ma = (emailQ.docs.first.data()['ma_benh_vien'] ??
                  emailQ.docs.first.id)
              .toString();
          if (ma.isNotEmpty && ma.startsWith('BV')) return ma;
        }

        final ychtQ = await _db
            .collection('YeuCauHopTac')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (ychtQ.docs.isNotEmpty) {
          final ma = (ychtQ.docs.first.data()['uid'] ??
                  ychtQ.docs.first.data()['ma_benh_vien'] ??
                  ychtQ.docs.first.id)
              .toString();
          if (ma.isNotEmpty && ma.startsWith('BV')) return ma;
        }
      }
    } catch (_) {}

    return trimmed;
  }

  /// Lấy tên bệnh viện từ Firestore để lưu vào Document cha `NhanVien/{benhVienId}`
  Future<String> _layTenBenhVien(String bvid) async {
    try {
      final bvDoc = await _db.collection('BenhVien').doc(bvid).get();
      if (bvDoc.exists) {
        final ten = (bvDoc.data()?['ten_benh_vien'] ??
                bvDoc.data()?['tenBenhVien'] ??
                bvDoc.data()?['name'] ??
                '')
            .toString()
            .trim();
        if (ten.isNotEmpty) return ten;
      }
    } catch (_) {}

    try {
      final nvDoc = await _db.collection('NhanVien').doc(bvid).get();
      if (nvDoc.exists) {
        final ten = (nvDoc.data()?['ten_benh_vien'] ?? '').toString().trim();
        if (ten.isNotEmpty) return ten;
      }
    } catch (_) {}

    try {
      final q = await _db
          .collection('BenhVien')
          .where('ma_benh_vien', isEqualTo: bvid)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final ten = (q.docs.first.data()['ten_benh_vien'] ??
                q.docs.first.data()['tenBenhVien'] ??
                '')
            .toString()
            .trim();
        if (ten.isNotEmpty) return ten;
      }
    } catch (_) {}

    return 'Bệnh viện Quân y 17';
  }

  /// Stream danh sách nhân viên theo thời gian thực (đọc từ NhanVien/{bvid}/danh_sach)
  Stream<List<NhanVienModel>> streamNhanVien({
    String? benhVienId,
    bool chiLayDaKichHoat = true,
  }) async* {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));

    final bvid = await _chuanHoaBenhVienId(rawId);

    if (bvid.isNotEmpty) {
      yield* _db
          .collection('NhanVien')
          .doc(bvid)
          .collection('danh_sach')
          .snapshots()
          .asyncMap((snap) async {
        if (snap.docs.isNotEmpty) {
          final list = snap.docs
              .map((d) => NhanVienModel.fromDoc(d))
              .where((nv) => !chiLayDaKichHoat || nv.daKichHoat)
              .toList();
          list.sort((a, b) {
            if (a.ngayTao == null && b.ngayTao == null) return 0;
            if (a.ngayTao == null) return 1;
            if (b.ngayTao == null) return -1;
            return b.ngayTao!.compareTo(a.ngayTao!);
          });
          return list;
        }

        // Fallback: nếu subcollection danh_sach trống, thử đọc từ root NhanVien
        try {
          final snapRoot = await _nhanVienCol
              .where('benh_vien_id', isEqualTo: bvid)
              .get();
          if (snapRoot.docs.isNotEmpty) {
            final list = snapRoot.docs
                .map((d) => NhanVienModel.fromDoc(d))
                .where((nv) => !chiLayDaKichHoat || nv.daKichHoat)
                .toList();
            list.sort((a, b) {
              if (a.ngayTao == null && b.ngayTao == null) return 0;
              if (a.ngayTao == null) return 1;
              if (b.ngayTao == null) return -1;
              return b.ngayTao!.compareTo(a.ngayTao!);
            });
            return list;
          }
        } catch (_) {}

        return <NhanVienModel>[];
      });
    } else {
      yield <NhanVienModel>[];
    }
  }

  /// Lấy danh sách tên các khoa đã được tạo thực tế trong Firestore (hoàn toàn không hardcode)
  Future<List<String>> layDanhSachKhoaDaTao([String? benhVienId]) async {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));

    final bvid = await _chuanHoaBenhVienId(rawId);
    final Set<String> names = {};

    // 1. Đọc từ đường dẫn chuẩn của bệnh viện: Khoa/{benhVienId}/danh_sach
    if (bvid.isNotEmpty) {
      try {
        final snap = await _db
            .collection('Khoa')
            .doc(bvid)
            .collection('danh_sach')
            .get();
        for (final doc in snap.docs) {
          final ten = (doc.data()['tenKhoa'] ?? doc.data()['ten_khoa'] ?? '')
              .toString()
              .trim();
          if (ten.isNotEmpty) names.add(ten);
        }
      } catch (_) {}
    }

    // 2. Nếu chưa có hoặc dùng ID khác, thử quét collectionGroup 'danh_sach'
    if (names.isEmpty) {
      try {
        final groupSnap = await _db.collectionGroup('danh_sach').get();
        for (final doc in groupSnap.docs) {
          final data = doc.data();
          if (data.containsKey('tenKhoa') || data.containsKey('ten_khoa')) {
            final ten = (data['tenKhoa'] ?? data['ten_khoa'] ?? '')
                .toString()
                .trim();
            if (ten.isNotEmpty) names.add(ten);
          }
        }
      } catch (_) {}
    }

    // 3. Quét collection 'Khoa' cấp cao nhất nếu có tài liệu lưu trực tiếp
    if (names.isEmpty) {
      try {
        final snapTop = await _db.collection('Khoa').get();
        for (final doc in snapTop.docs) {
          final data = doc.data();
          final ten = (data['tenKhoa'] ?? data['ten_khoa'] ?? '')
              .toString()
              .trim();
          if (ten.isNotEmpty) names.add(ten);
        }
      } catch (_) {}
    }

    final sorted = names.toList()..sort();
    return sorted;
  }

  /// Lấy danh sách tài khoản vừa tạo đang ở trạng thái đợi kích hoạt (chỉ của bệnh viện này)
  Future<List<TaiKhoanItem>> layDanhSachTaiKhoanChuaKichHoat([String? benhVienId]) async {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));

    final bvid = await _chuanHoaBenhVienId(rawId);
    final list = <TaiKhoanItem>[];

    // 1. Quét từ NhanVien/{bvid}/danh_sach
    if (bvid.isNotEmpty) {
      try {
        final snap = await _db
            .collection('NhanVien')
            .doc(bvid)
            .collection('danh_sach')
            .get();

        for (final d in snap.docs) {
          final data = d.data();
          final daKichHoat = data['da_kich_hoat'] ?? false;
          final trangThaiRaw = (data['trang_thai'] ?? '').toString();

          if (daKichHoat == true ||
              trangThaiRaw == 'dang_hoat_dong' ||
              trangThaiRaw == 'da_khoa') {
            continue;
          }

          final maTk = (data['ma_nhan_vien'] ??
                  data['ma_tai_khoan'] ??
                  d.id)
              .toString();
          final matKhau = (data['mat_khau'] ?? '123456').toString();

          list.add(TaiKhoanItem(
            id: d.id,
            benhVienId: bvid,
            maTk: maTk,
            matKhau: matKhau,
            trangThai: 'Đợi kích hoạt',
          ));
        }
      } catch (_) {}
    }

    // 2. Fallback nếu danh_sach trống: quét collection NhanVien root
    if (list.isEmpty) {
      try {
        Query<Map<String, dynamic>> query = _nhanVienCol;
        if (bvid.isNotEmpty) {
          query = query.where('benh_vien_id', isEqualTo: bvid);
        }
        final snap = await query.get();
        for (final d in snap.docs) {
          final data = d.data();
          final daKichHoat = data['da_kich_hoat'] ?? false;
          final trangThaiRaw = (data['trang_thai'] ?? '').toString();

          if (daKichHoat == true ||
              trangThaiRaw == 'dang_hoat_dong' ||
              trangThaiRaw == 'da_khoa') {
            continue;
          }

          final maTk = (data['ma_nhan_vien'] ??
                  data['ma_tai_khoan'] ??
                  d.id)
              .toString();
          final matKhau = (data['mat_khau'] ?? '123456').toString();

          list.add(TaiKhoanItem(
            id: d.id,
            benhVienId: (data['benh_vien_id'] ?? bvid).toString(),
            maTk: maTk,
            matKhau: matKhau,
            trangThai: 'Đợi kích hoạt',
          ));
        }
      } catch (_) {}
    }

    return list;
  }

  /// Tương thích ngược: Lấy danh sách tài khoản đợi kích hoạt
  Future<List<TaiKhoanItem>> layDanhSachTaiKhoan([String? benhVienId]) =>
      layDanhSachTaiKhoanChuaKichHoat(benhVienId);

  /// Chuẩn hóa các tài khoản nhân viên cũ sang định dạng mới:
  /// idBV_vaitro_khoa_maso (Ví dụ: LT_HH_01 -> BV502_LT_HH_01)
  Future<void> chuanHoaDinhDangMaNhanVien([String? benhVienId]) async {
    try {
      final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
          ? benhVienId.trim()
          : (AppSession.benhVienId.isNotEmpty
              ? AppSession.benhVienId
              : (FirebaseAuth.instance.currentUser?.uid ?? ''));

      final bvid = await _chuanHoaBenhVienId(rawId);
      if (bvid.isEmpty) return;

      final snap = await _db
          .collection('NhanVien')
          .doc(bvid)
          .collection('danh_sach')
          .get();

      for (final doc in snap.docs) {
        final oldId = doc.id;
        // Nếu đã có tiền tố bvid_ thì đã đúng chuẩn mới
        if (oldId.toUpperCase().startsWith('${bvid.toUpperCase()}_')) continue;

        // Nếu là định dạng cũ chưa có mã bệnh viện (VD: LT_HH_01, CSKH_01, BS_NH_01...)
        final newId = '${bvid}_$oldId';
        final oldData = Map<String, dynamic>.from(doc.data());

        oldData['id'] = newId;
        oldData['ma_nhan_vien'] = newId;
        oldData['ma_tai_khoan'] = newId;
        oldData['ma_benh_vien'] = bvid;
        oldData['benh_vien_id'] = bvid;
        if (oldData['email'] != null && oldData['email'].toString().isNotEmpty) {
          oldData['email'] = '${newId.toLowerCase()}@benhvien.vn';
        }

        // Tạo doc mới với ID mới idBV_vaitro_khoa_maso
        await _db
            .collection('NhanVien')
            .doc(bvid)
            .collection('danh_sach')
            .doc(newId)
            .set(oldData, SetOptions(merge: true));

        // Xóa doc cũ
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  /// Cấp mới danh sách tài khoản nhân viên theo chuẩn cấu trúc Firebase:
  /// - Document cha: `NhanVien/{benhVienId}` gồm `ma_benh_vien` và `ten_benh_vien`
  /// - Subcollection: `danh_sach`
  /// - ID tài liệu trong `danh_sach` chính là mã nhân viên (ví dụ `CSKH_01`, `LT_TM_01`...)
  /// - Không dùng ID ngẫu nhiên tự sinh hash. Mỗi lần tạo thêm sẽ tự động cộng thêm 1 (_01, _02, _03...)
  Future<DotCapTaiKhoan> taoVaLuuNhanVien({
    String? benhVienId,
    required String tenKhoa,
    required String deptCode,
    required String vaiTro,
    required String rolePrefix,
    required String roleCode,
    required int soLuong,
    String matKhau = '123456',
  }) async {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));

    final bvid = await _chuanHoaBenhVienId(rawId);
    final tenBenhVien = await _layTenBenhVien(bvid);

    // 1. Đảm bảo Document cha NhanVien/{bvid} tồn tại đúng chuẩn Firebase:
    // ma_benh_vien: "BV001"
    // ten_benh_vien: "Bệnh viện Quân y 17"
    if (bvid.isNotEmpty) {
      await _db.collection('NhanVien').doc(bvid).set({
        'ma_benh_vien': bvid,
        'ten_benh_vien': tenBenhVien,
      }, SetOptions(merge: true));
    }

    // 2. Xác định tiền tố (prefix) tài khoản nhân viên theo chuẩn:
    // Định dạng: idBV_vaitro_khoa_maso (Ví dụ: BV504_LT_CC_01)
    final String cleanBv = bvid.trim().isNotEmpty ? bvid.trim().toUpperCase() : 'BV';
    final String cleanRole = rolePrefix.trim().toUpperCase();
    final String cleanDept = deptCode.trim().toUpperCase();

    final String prefix;
    if (cleanRole == 'CSKH' || roleCode == 'customerSupport') {
      if (cleanDept.isNotEmpty) {
        prefix = '${cleanBv}_CSKH_${cleanDept}_';
      } else {
        prefix = '${cleanBv}_CSKH_';
      }
    } else if (cleanDept.isNotEmpty) {
      prefix = '${cleanBv}_${cleanRole}_${cleanDept}_';
    } else {
      prefix = '${cleanBv}_${cleanRole}_';
    }

    // 3. Quét các mã tài khoản đã có trong subcollection danh_sach để tìm số thứ tự lớn nhất
    // Tự động cộng thêm 1 cho mỗi tài khoản mới: _01, _02, _03...
    int maxNum = 0;
    final Set<String> existingCodes = {};

    try {
      final snap = await _db
          .collection('NhanVien')
          .doc(bvid)
          .collection('danh_sach')
          .get();

      final regex = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
      for (final doc in snap.docs) {
        existingCodes.add(doc.id);
        final match = regex.firstMatch(doc.id);
        if (match != null) {
          final n = int.tryParse(match.group(1) ?? '') ?? 0;
          // Chỉ xét các số thứ tự tuần tự <= 9999 (bỏ qua mã random cũ 6 chữ số nếu có)
          if (n > 0 && n < 10000 && n > maxNum) {
            maxNum = n;
          }
        }
      }
    } catch (_) {}

    // Quét thêm nếu có tài khoản cùng prefix ở root (phòng ngừa trùng lặp)
    try {
      final rootSnap = await _nhanVienCol.get();
      final regex = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
      for (final doc in rootSnap.docs) {
        final ma = (doc.data()['ma_nhan_vien'] ??
                doc.data()['ma_tai_khoan'] ??
                doc.id)
            .toString();
        existingCodes.add(ma);
        final match = regex.firstMatch(ma);
        if (match != null) {
          final n = int.tryParse(match.group(1) ?? '') ?? 0;
          if (n > 0 && n < 10000 && n > maxNum) {
            maxNum = n;
          }
        }
      }
    } catch (_) {}

    final List<TaiKhoanItem> danhSach = [];
    final batch = _db.batch();

    final String commonPassword =
        matKhau.trim().isNotEmpty ? matKhau.trim() : '123456';

    int currentCounter = maxNum;

    for (int i = 0; i < soLuong; i++) {
      String maTk;
      do {
        currentCounter++;
        final suffix = currentCounter.toString().padLeft(2, '0');
        maTk = '$prefix$suffix';
      } while (existingCodes.contains(maTk));

      existingCodes.add(maTk);

      // Lưu document trực tiếp tại NhanVien/{bvid}/danh_sach/{maTk} (ID chính là maTk)
      final docRef = _db
          .collection('NhanVien')
          .doc(bvid)
          .collection('danh_sach')
          .doc(maTk);

      danhSach.add(TaiKhoanItem(
        id: maTk,
        benhVienId: bvid,
        maTk: maTk,
        matKhau: commonPassword,
        trangThai: 'Đợi kích hoạt',
      ));

      final staffData = {
        'id': maTk,
        'ma_benh_vien': bvid,
        'benh_vien_id': bvid,
        'ten_benh_vien': tenBenhVien,
        'ma_nhan_vien': maTk,
        'ma_tai_khoan': maTk,
        'mat_khau': commonPassword,
        'role': roleCode,
        'vai_tro': vaiTro,
        'khoa': tenKhoa,
        'da_kich_hoat': false,
        'trang_thai': 'doi_kich_hoat',
        'ngay_tao': FieldValue.serverTimestamp(),
        'ho_ten': '$vaiTro ${maTk.split('_').last}',
        'so_dien_thoai': '',
        'email': '${maTk.toLowerCase()}@benhvien.vn',
      };

      batch.set(docRef, staffData);
    }

    // Ghi đồng loạt lên Firebase Firestore
    await batch.commit();

    return DotCapTaiKhoan(
      tenKhoa: tenKhoa,
      vaiTro: vaiTro,
      soLuong: soLuong,
      danhSachTaiKhoan: danhSach,
    );
  }

  /// Kích hoạt tài khoản nhân viên
  Future<void> kichHoatTaiKhoan(String nhanVienId, [String? benhVienId]) async {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));
    final bvid = await _chuanHoaBenhVienId(rawId);

    // 1. Cập nhật trong NhanVien/{bvid}/danh_sach/{nhanVienId}
    if (bvid.isNotEmpty) {
      try {
        final docRef = _db
            .collection('NhanVien')
            .doc(bvid)
            .collection('danh_sach')
            .doc(nhanVienId);
        final snap = await docRef.get();
        if (snap.exists) {
          await docRef.update({
            'da_kich_hoat': true,
            'trang_thai': 'dang_hoat_dong',
          });
        }
      } catch (_) {}
    }

    // 2. Tìm trong collectionGroup('danh_sach') nếu chưa tìm thấy
    try {
      final cg = await _db
          .collectionGroup('danh_sach')
          .where('ma_nhan_vien', isEqualTo: nhanVienId)
          .limit(1)
          .get();
      for (final d in cg.docs) {
        await d.reference.update({
          'da_kich_hoat': true,
          'trang_thai': 'dang_hoat_dong',
        });
      }
    } catch (_) {}

    // 3. Fallback cập nhật ở root NhanVien nếu có tài liệu cũ
    try {
      final rootRef = _nhanVienCol.doc(nhanVienId);
      final rootSnap = await rootRef.get();
      if (rootSnap.exists) {
        await rootRef.update({
          'da_kich_hoat': true,
          'trang_thai': 'dang_hoat_dong',
        });
      }
    } catch (_) {}
  }

  /// Cập nhật trạng thái khóa / mở khóa tài khoản
  Future<void> capNhatTrangThai({
    required String nhanVienId,
    required bool dangHoatDong,
    String? benhVienId,
  }) async {
    final statusStr = dangHoatDong ? 'dang_hoat_dong' : 'da_khoa';
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));
    final bvid = await _chuanHoaBenhVienId(rawId);

    if (bvid.isNotEmpty) {
      try {
        final docRef = _db
            .collection('NhanVien')
            .doc(bvid)
            .collection('danh_sach')
            .doc(nhanVienId);
        final snap = await docRef.get();
        if (snap.exists) {
          await docRef.update({
            'trang_thai': statusStr,
            'da_kich_hoat': true,
          });
        }
      } catch (_) {}
    }

    try {
      final cg = await _db
          .collectionGroup('danh_sach')
          .where('ma_nhan_vien', isEqualTo: nhanVienId)
          .limit(1)
          .get();
      for (final d in cg.docs) {
        await d.reference.update({
          'trang_thai': statusStr,
          'da_kich_hoat': true,
        });
      }
    } catch (_) {}

    try {
      final rootRef = _nhanVienCol.doc(nhanVienId);
      final rootSnap = await rootRef.get();
      if (rootSnap.exists) {
        await rootRef.update({
          'trang_thai': statusStr,
          'da_kich_hoat': true,
        });
      }
    } catch (_) {}
  }

  /// Xóa tài khoản nhân viên (xóa cả trên NhanVien/{bvid}/danh_sach và collection NhanVien root nếu có)
  Future<void> xoaNhanVien(String nhanVienId, [String? benhVienId]) async {
    final rawId = (benhVienId != null && benhVienId.trim().isNotEmpty)
        ? benhVienId.trim()
        : (AppSession.benhVienId.isNotEmpty
            ? AppSession.benhVienId
            : (FirebaseAuth.instance.currentUser?.uid ?? ''));
    final bvid = await _chuanHoaBenhVienId(rawId);

    // 1. Xóa trong NhanVien/{bvid}/danh_sach/{nhanVienId}
    if (bvid.isNotEmpty) {
      try {
        await _db
            .collection('NhanVien')
            .doc(bvid)
            .collection('danh_sach')
            .doc(nhanVienId)
            .delete();
      } catch (_) {}
    }

    // 2. Tìm và xóa trong collectionGroup('danh_sach')
    try {
      final cg = await _db
          .collectionGroup('danh_sach')
          .where('ma_nhan_vien', isEqualTo: nhanVienId)
          .get();
      for (final d in cg.docs) {
        await d.reference.delete();
      }
    } catch (_) {}

    // 3. Fallback xóa ở root NhanVien nếu tồn tại bản ghi cũ
    try {
      final rootRef = _nhanVienCol.doc(nhanVienId);
      final rootSnap = await rootRef.get();
      if (rootSnap.exists) {
        await rootRef.delete();
      }
      final rootQ = await _nhanVienCol
          .where('ma_nhan_vien', isEqualTo: nhanVienId)
          .get();
      for (final d in rootQ.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }
}
