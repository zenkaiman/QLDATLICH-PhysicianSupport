import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/lichhen_model.dart';
import '../models/family_profile_model.dart';

/// LichHenService: truy cập Firestore cho đặt lịch, hủy lịch, xóa lịch và theo dõi hàng chờ.
class LichHenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _colLichHen = 'LichHen';
  static const String _colPhongKham = 'PhongKham';

  static const String trangThaiDaHuy = '3';

  static const Set<String> _trangThaiKhongTheHuy = {'4', '5', '6'};

  static const List<Map<String, String>> _caMacDinh = [
    {
      'id': 'ca_sang',
      'ten_ca': 'Ca sáng',
      'gio_bat_dau': '07:30',
      'gio_ket_thuc': '11:30',
    },
    {
      'id': 'ca_chieu',
      'ten_ca': 'Ca chiều',
      'gio_bat_dau': '13:30',
      'gio_ket_thuc': '17:00',
    },
  ];

  final Map<String, int> _tongSoCache = {};

  static const List<Object> _trangThaiChiemCho = [2, '2'];

  static const Duration _vnOffset = Duration(hours: 7);

  /// _toInt: đọc số nguyên từ Firestore (chấp nhận số hoặc chuỗi).
  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  /// ngayId: định dạng ngày thành chuỗi "yyyy-MM-dd".
  static String ngayId(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// _layTongSoTuPhongKham: lấy số bệnh nhân tối đa của phòng khám (có cache).
  Future<int?> _layTongSoTuPhongKham({
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) async {
    final cacheKey = '$benhVienId|$khoaId|$phongKhamId';
    final cached = _tongSoCache[cacheKey];
    if (cached != null) return cached;

    try {
      final doc = await _firestore
          .collection(_colPhongKham)
          .doc(phongKhamId)
          .get();

      if (!doc.exists) {
        debugPrint('Document $phongKhamId không tồn tại');
        return null;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final docHospitalId = data['hospitalId']?.toString();
      final docKhoaId = data['khoaId']?.toString();

      if (docHospitalId != benhVienId || docKhoaId != khoaId) {
        debugPrint(
          'Document $phongKhamId không khớp: '
          'hospitalId=$docHospitalId (cần $benhVienId), '
          'khoaId=$docKhoaId (cần $khoaId)',
        );
        return null;
      }

      final v = _toInt(data['soBenhNhanToiDa']);
      if (v != null) {
        _tongSoCache[cacheKey] = v;
      } else {
        debugPrint('PhongKham/$phongKhamId không có field soBenhNhanToiDa');
      }
      return v;
    } catch (e) {
      debugPrint('Lỗi khi đọc PhongKham/$phongKhamId: $e');
      return null;
    }
  }

  /// _khoangNgayVN: trả về khoảng [00:00, 24:00) của một ngày theo giờ Việt Nam, đổi sang UTC.
  ({Timestamp start, Timestamp end}) _khoangNgayVN(DateTime ngay) {
    final startUtc = DateTime.utc(
      ngay.year,
      ngay.month,
      ngay.day,
    ).subtract(_vnOffset);
    final endUtc = startUtc.add(const Duration(days: 1));
    return (
      start: Timestamp.fromDate(startUtc),
      end: Timestamp.fromDate(endUtc),
    );
  }

  /// demLichDaDat: đếm số lịch hẹn đã chiếm chỗ của một ca trong một ngày.
  Future<int> demLichDaDat({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required String caId,
  }) async {
    final range = _khoangNgayVN(ngay);
    final snapshot = await _firestore
        .collection(_colLichHen)
        .where('benh_vien_id', isEqualTo: benhVienId)
        .where('khoa_id', isEqualTo: khoaId)
        .where('phong_kham_id', isEqualTo: phongKhamId)
        .where('ca_id', isEqualTo: caId)
        .where('trang_thai_id', whereIn: _trangThaiChiemCho)
        .where('ngay_dat', isGreaterThanOrEqualTo: range.start)
        .where('ngay_dat', isLessThan: range.end)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// soChoConLai: tính số chỗ còn lại của một ca (tổng số chỗ trừ số lịch đã đặt, không âm).
  Future<int> soChoConLai({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required String caId,
    int soBenhNhanToiDa = 0,
  }) async {
    final tongSo =
        await _layTongSoTuPhongKham(
          benhVienId: benhVienId,
          khoaId: khoaId,
          phongKhamId: phongKhamId,
        ) ??
        soBenhNhanToiDa;
    final daDat = await demLichDaDat(
      ngay: ngay,
      benhVienId: benhVienId,
      khoaId: khoaId,
      phongKhamId: phongKhamId,
      caId: caId,
    );
    final conLai = tongSo - daDat;
    return conLai < 0 ? 0 : conLai;
  }

  /// getCaSlotsTheoPhong: lấy tình trạng các ca (tổng chỗ, đã đặt) của một phòng khám trong một ngày.
  Future<List<CaSlotModel>> getCaSlotsTheoPhong({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    int soBenhNhanToiDa = 0,
  }) async {
    final caSnapshot = await _firestore.collection('Ca').get();
    final caList = caSnapshot.docs.isNotEmpty
        ? caSnapshot.docs.map((d) => MapEntry(d.id, d.data())).toList()
        : _caMacDinh
              .map((c) => MapEntry(c['id']!, <String, dynamic>{...c}))
              .toList();
    final macDinhTheoId = {for (final c in _caMacDinh) c['id']!: c};

    final tongSo =
        await _layTongSoTuPhongKham(
          benhVienId: benhVienId,
          khoaId: khoaId,
          phongKhamId: phongKhamId,
        ) ??
        soBenhNhanToiDa;

    final results = await Future.wait<CaSlotModel>(
      caList.map((entry) async {
        final caId = entry.key;
        final caData = entry.value;
        final macDinh = macDinhTheoId[caId];

        String caField(String key, String fallback) {
          final v = caData[key]?.toString() ?? '';
          return v.isNotEmpty ? v : (macDinh?[key] ?? fallback);
        }

        final daDat = await demLichDaDat(
          ngay: ngay,
          benhVienId: benhVienId,
          khoaId: khoaId,
          phongKhamId: phongKhamId,
          caId: caId,
        );

        return CaSlotModel(
          caId: caId,
          tenCa: caField('ten_ca', caId),
          gioBatDau: caField('gio_bat_dau', ''),
          gioKetThuc: caField('gio_ket_thuc', ''),
          tongSo: tongSo,
          daDat: daDat < 0 ? 0 : daDat,
        );
      }),
    );

    return results..sort((a, b) => a.gioBatDau.compareTo(b.gioBatDau));
  }

  /// generateLichHenId: tạo mã lịch hẹn dạng BV_KHOA_LH_DDMMYYYY_NNNNN theo số lịch đã có trong ngày.
  Future<String> generateLichHenId({
    required DateTime ngayDat,
    required String benhVienId,
    required String khoaId,
  }) async {
    final dateStr =
        '${ngayDat.day.toString().padLeft(2, '0')}'
        '${ngayDat.month.toString().padLeft(2, '0')}'
        '${ngayDat.year}';

    final dayStart = Timestamp.fromDate(
      DateTime(ngayDat.year, ngayDat.month, ngayDat.day),
    );
    final dayEnd = Timestamp.fromDate(
      DateTime(ngayDat.year, ngayDat.month, ngayDat.day, 23, 59, 59),
    );

    final snapshot = await _firestore
        .collection(_colLichHen)
        .where('benh_vien_id', isEqualTo: benhVienId)
        .where('khoa_id', isEqualTo: khoaId)
        .where('ngay_dat', isGreaterThanOrEqualTo: dayStart)
        .where('ngay_dat', isLessThanOrEqualTo: dayEnd)
        .count()
        .get();

    final nextNumber = (snapshot.count ?? 0) + 1;
    final numberStr = nextNumber.toString().padLeft(5, '0');

    return '${benhVienId}_${khoaId}_LH_${dateStr}_$numberStr';
  }

  /// checkExistingBooking: kiểm tra người khám đã có lịch (chưa hủy) cùng bệnh viện, khoa và ngày chưa.
  Future<bool> checkExistingBooking({
    required String benhNhanId,
    required String benhVienId,
    required String khoaId,
    required DateTime ngayDat,
    String? profileId,
  }) async {
    final start = DateTime(ngayDat.year, ngayDat.month, ngayDat.day);
    final end = start.add(const Duration(days: 1));
    try {
      final snapshot = await _firestore
          .collection(_colLichHen)
          .where('benh_nhan_id', isEqualTo: benhNhanId)
          .where('benh_vien_id', isEqualTo: benhVienId)
          .where('khoa_id', isEqualTo: khoaId)
          .where('ngay_dat', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('ngay_dat', isLessThan: Timestamp.fromDate(end))
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['trang_thai_id']?.toString();
        if (status == '3' || status == '4') continue;
        final docProfile = (data['profile_id'] ?? FamilyProfileModel.selfId)
            .toString();
        if (profileId == null || docProfile == profileId) return true;
      }
      return false;
    } catch (e) {
      debugPrint('Lỗi khi kiểm tra trùng lịch: $e');
      return false;
    }
  }

  /// saveBooking: lưu lịch hẹn mới vào collection LichHen.
  Future<void> saveBooking({
    required String trangThaiId,
    required DateTime ngayDat,
    required String caId,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required String benhNhanId,
    String? lichHenId,
    String? tenBenhVien,
    String? tenKhoa,
    String? tenPhongKham,
    String? profileId,
    String? tenNguoiKham,
    String? quanHe,
    String? tenNguoiDat,
  }) async {
    final finalLichHenId =
        lichHenId ??
        await generateLichHenId(
          ngayDat: ngayDat,
          benhVienId: benhVienId,
          khoaId: khoaId,
        );

    final docRef = _firestore.collection(_colLichHen).doc(finalLichHenId);

    await docRef.set({
      'id': finalLichHenId,
      'trang_thai_id': trangThaiId,
      'ngay_dat': Timestamp.fromDate(ngayDat),
      'ca_id': caId,
      'benh_vien_id': benhVienId,
      'khoa_id': khoaId,
      'phong_kham_id': phongKhamId,
      'benh_nhan_id': benhNhanId,
      if (tenBenhVien != null) 'ten_benh_vien': tenBenhVien,
      if (tenKhoa != null) 'ten_khoa': tenKhoa,
      if (tenPhongKham != null) 'ten_phong_kham': tenPhongKham,
      if (profileId != null) 'profile_id': profileId,
      if (tenNguoiKham != null) 'ten_nguoi_kham': tenNguoiKham,
      if (quanHe != null) 'quan_he': quanHe,
      if (tenNguoiDat != null) 'ten_nguoi_dat': tenNguoiDat,
      'ma_qr': null,
      'ngay_tao': FieldValue.serverTimestamp(),
    });
  }

  /// _tenPhong: đọc tên phòng khám từ dữ liệu Firestore theo nhiều tên field có thể có.
  static String? _tenPhong(Map<String, dynamic>? d) {
    if (d == null) return null;
    for (final k in ['tenPhongKham', 'ten_phong_kham', 'tenPhong', 'ten']) {
      final v = d[k]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// getLichHenCuaBenhNhan: lấy tất cả lịch hẹn của bệnh nhân, bổ sung tên ca, giờ ca, tên khoa, tên phòng và sắp xếp mới nhất trước.
  Future<List<LichHenModel>> getLichHenCuaBenhNhan(String benhNhanId) async {
    try {
      final snapshot = await _firestore
          .collection('LichHen')
          .where('benh_nhan_id', isEqualTo: benhNhanId)
          .get();

      final bookings = snapshot.docs
          .map((doc) => LichHenModel.fromJson(doc.data(), id: doc.id))
          .toList();
      if (bookings.isEmpty) return bookings;

      final caIds = bookings
          .where((b) => b.tenCa == null || b.gioBatDau == null)
          .map((b) => b.caId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final caEntries = await Future.wait(
        caIds.map((id) async {
          final doc = await _firestore.collection('Ca').doc(id).get();
          return MapEntry(id, doc.data());
        }),
      );
      final caMap = {for (final e in caEntries) e.key: e.value};

      final phongIds = bookings
          .where((b) => b.tenPhongKham == null && b.phongKhamId.isNotEmpty)
          .map((b) => b.phongKhamId)
          .toSet();
      final phongEntries = await Future.wait(
        phongIds.map((id) async {
          final doc = await _firestore.collection(_colPhongKham).doc(id).get();
          return MapEntry(id, doc.data());
        }),
      );
      final phongMap = {for (final e in phongEntries) e.key: e.value};

      final khoaKeys = bookings
          .where(
            (b) =>
                b.tenKhoa == null &&
                b.benhVienId.isNotEmpty &&
                b.khoaId.isNotEmpty,
          )
          .map((b) => '${b.benhVienId}|${b.khoaId}')
          .toSet();
      final khoaEntries = await Future.wait(
        khoaKeys.map((key) async {
          final parts = key.split('|');
          final doc = await _firestore
              .collection('Khoa')
              .doc(parts[0])
              .collection('danh_sach')
              .doc(parts[1])
              .get();
          return MapEntry(key, doc.data());
        }),
      );
      final khoaMap = {for (final e in khoaEntries) e.key: e.value};

      final result = bookings.map((b) {
        final ca = caMap[b.caId];
        final khoa = khoaMap['${b.benhVienId}|${b.khoaId}'];
        return b.copyWith(
          tenCa: ca?['ten_ca']?.toString(),
          gioBatDau: ca?['gio_bat_dau']?.toString(),
          gioKetThuc: ca?['gio_ket_thuc']?.toString(),
          tenKhoa: khoa?['ten_khoa']?.toString(),
          tenPhongKham: _tenPhong(phongMap[b.phongKhamId]),
        );
      }).toList();

      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      result.sort((a, b) {
        final ta = a.ngayTao ?? a.ngayDat ?? epoch;
        final tb = b.ngayTao ?? b.ngayDat ?? epoch;
        return tb.compareTo(ta);
      });
      return result;
    } on FirebaseException catch (e) {
      debugPrint('Lỗi Firestore khi tải lịch hẹn [${e.code}]: ${e.message}');
      switch (e.code) {
        case 'failed-precondition':
          throw Exception(
            'Cần tạo chỉ mục (index) Firestore cho lịch hẹn. '
            'Xem Debug Console để lấy liên kết tạo.',
          );
        case 'permission-denied':
          throw Exception(
            'Không có quyền đọc lịch hẹn (kiểm tra Security Rules).',
          );
        default:
          throw Exception('Không thể tải lịch hẹn. Vui lòng thử lại.');
      }
    }
  }

  /// getBookingDetail: lấy dữ liệu chi tiết của một lịch hẹn theo mã.
  Future<Map<String, dynamic>?> getBookingDetail({
    required String trangThaiId,
    required String ngayId,
    required String caId,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    required String benhNhanId,
    required String lichHenId,
  }) async {
    try {
      final doc = await _firestore.collection(_colLichHen).doc(lichHenId).get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Lỗi khi lấy chi tiết lịch hẹn: $e');
      return null;
    }
  }

  /// getDanhSachLichHen: lấy danh sách lịch hẹn của một phòng khám trong một ngày (caId null là tất cả các ca).
  Future<List<LichHenModel>> getDanhSachLichHen({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
    String? caId,
  }) async {
    List<String> caIds;

    if (caId != null) {
      caIds = [caId];
    } else {
      final snapshot = await _firestore
          .collection('LichHen')
          .where('ngay_hen', isEqualTo: Timestamp.fromDate(ngay))
          .where('benh_vien_id', isEqualTo: benhVienId)
          .where('khoa_id', isEqualTo: khoaId)
          .where('phong_kham_id', isEqualTo: phongKhamId)
          .get();

      caIds = snapshot.docs
          .map((doc) => doc.data()['ca_id'] as String)
          .toSet()
          .toList();
    }

    final perCa = await Future.wait<List<LichHenModel>>(
      caIds.map((id) async {
        final phongRef = _firestore.collection(_colLichHen).doc(phongKhamId);

        final benhNhanSnapshot = await phongRef.collection('BenhNhan').get();
        final lichHenSnapshots = await Future.wait(
          benhNhanSnapshot.docs.map(
            (bn) => bn.reference.collection('LichHen').get(),
          ),
        );

        return [
          for (final snap in lichHenSnapshots)
            for (final doc in snap.docs)
              LichHenModel.fromJson(doc.data(), id: doc.id),
        ];
      }),
    );

    return perCa.expand((list) => list).toList()..sort((a, b) {
      final byCa = a.caId.compareTo(b.caId);
      return byCa != 0 ? byCa : a.soThuTu.compareTo(b.soThuTu);
    });
  }

  /// huyLichHenTheoId: hủy lịch hẹn của bệnh nhân (chuyển sang trạng thái 3) sau khi kiểm tra quyền và trạng thái.
  Future<void> huyLichHenTheoId({
    required String benhNhanId,
    required String lichHenId,
    String? lyDoHuy,
  }) async {
    final id = lichHenId.replaceFirst('#', '').trim();
    final ref = _firestore.collection(_colLichHen).doc(id);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Không tìm thấy lịch hẹn cần hủy.');

        final data = snap.data()!;
        if (data['benh_nhan_id'] != benhNhanId) {
          throw Exception('Bạn không có quyền hủy lịch hẹn này.');
        }

        final cu = data['trang_thai_id'].toString();
        if (cu == trangThaiDaHuy) {
          throw Exception('Lịch hẹn này đã được hủy trước đó.');
        }
        if (_trangThaiKhongTheHuy.contains(cu)) {
          throw Exception('Lịch hẹn ở trạng thái hiện tại không thể hủy.');
        }

        tx.update(ref, {
          'trang_thai_id': trangThaiDaHuy,
          'huy_boi': 'benh_nhan',
          'ly_do_huy': lyDoHuy ?? 'Bệnh nhân tự hủy qua ứng dụng',
          'ngay_cap_nhat': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Lỗi Firestore khi hủy lịch: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// xoaLichHenTheoId: xóa lịch hẹn đã hủy của bệnh nhân sau khi kiểm tra quyền và trạng thái.
  Future<void> xoaLichHenTheoId({
    required String benhNhanId,
    required String lichHenId,
  }) async {
    final id = lichHenId.replaceFirst('#', '').trim();
    final ref = _firestore.collection(_colLichHen).doc(id);
    try {
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Không tìm thấy lịch hẹn cần xóa.');
      final data = snap.data()!;
      if (data['benh_nhan_id'] != benhNhanId) {
        throw Exception('Bạn không có quyền xóa lịch hẹn này.');
      }
      if (data['trang_thai_id'].toString() != trangThaiDaHuy) {
        throw Exception('Chỉ có thể xóa lịch hẹn đã hủy.');
      }
      await ref.delete();
    } on FirebaseException catch (e) {
      debugPrint('Lỗi Firestore khi xóa lịch [${e.code}]: ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('Không có quyền xóa lịch hẹn này.');
      }
      throw Exception('Không thể xóa lịch hẹn. Vui lòng thử lại.');
    }
  }

  /// listenToQueue: lắng nghe hàng chờ thời gian thực của một phòng khám trong một ngày (trạng thái 2 và 7), sắp xếp theo số thứ tự.
  Stream<List<LichHenModel>> listenToQueue({
    required DateTime ngay,
    required String benhVienId,
    required String khoaId,
    required String phongKhamId,
  }) {
    bool cungNgay(DateTime? d) =>
        d != null &&
        d.year == ngay.year &&
        d.month == ngay.month &&
        d.day == ngay.day;

    return _firestore
        .collection(_colLichHen)
        .where('benh_vien_id', isEqualTo: benhVienId)
        .where('khoa_id', isEqualTo: khoaId)
        .where('phong_kham_id', isEqualTo: phongKhamId)
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs
                  .map((doc) => LichHenModel.fromJson(doc.data(), id: doc.id))
                  .where(
                    (b) =>
                        cungNgay(b.ngayDat) &&
                        (b.trangThaiId == '2' || b.trangThaiId == '7'),
                  )
                  .toList()
                ..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));
          return list;
        });
  }
}