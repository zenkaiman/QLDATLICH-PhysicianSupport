import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_session.dart';

class BenhVienService {
  static final Map<String, String> _cache = {};

  /// _chuanHoa: chuẩn hóa tên field (chữ thường, bỏ dấu gạch dưới và khoảng trắng) để so khớp.
  static String _chuanHoa(String k) =>
      k.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  /// _timTen: tìm tên bệnh viện trong document, chấp nhận nhiều kiểu đặt tên field (ten_benh_vien, tenBenhVien, ten, name...).
  static String _timTen(Map<String, dynamic> data) {
    const uuTien = ['tenbenhvien', 'tenbv', 'ten', 'name', 'hospitalname'];
    final chuan = {for (final e in data.entries) _chuanHoa(e.key): e.value};
    for (final k in uuTien) {
      final v = chuan[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    for (final e in data.entries) {
      final v = e.value;
      if (_chuanHoa(e.key).startsWith('ten') &&
          v is String &&
          v.trim().isNotEmpty) {
        return v.trim();
      }
    }
    return '';
  }

  /// layTen: lấy tên bệnh viện theo ID (có cache); trả về chuỗi rỗng nếu không tìm thấy, ném lỗi nếu Firestore từ chối.
  /// Có AppSession.benhVienPath thì đọc thẳng document đó, không thì tìm trong 'BenhVien' rồi quét collection group 'danh_sach' (bỏ nhánh Khoa/).
  static Future<String> layTen(String benhVienId) async {
    if (_cache.containsKey(benhVienId)) return _cache[benhVienId]!;
    final db = FirebaseFirestore.instance;

    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      final path = AppSession.benhVienPath;

      if (path != null) {
        doc = await db.doc(path).get();
        if (!doc.exists) doc = null;
      } else {
        // 1. Kiểm tra trực tiếp trong collection BenhVien/{benhVienId}
        final docDirect = await db.collection('BenhVien').doc(benhVienId).get();
        if (docDirect.exists) {
          doc = docDirect;
        } else {
          // 2. Dự phòng: quét collectionGroup danh_sach
          final all = await db.collectionGroup('danh_sach').get();
          for (final d in all.docs) {
            if (d.id == benhVienId && !d.reference.path.startsWith('Khoa/')) {
              doc = d;
              break;
            }
          }
          if (doc == null) {
            debugPrint(
              '[BenhVienService] Đã quét ${all.docs.length} document '
              'trong danh_sach nhưng không có ID "$benhVienId".',
            );
          }
        }
      }

      if (doc == null) return '';

      final data = doc.data() ?? {};
      debugPrint('[BenhVienService] Tìm thấy: ${doc.reference.path}');
      debugPrint('[BenhVienService] Các field: ${data.keys.toList()}');

      final ten = _timTen(data);
      if (ten.isEmpty) {
        debugPrint('[BenhVienService] Document có nhưng không thấy field tên.');
        return '';
      }
      _cache[benhVienId] = ten;
      return ten;
    } catch (e) {
      debugPrint('[BenhVienService] Lỗi đọc tên bệnh viện: $e');
      rethrow;
    }
  }

  // ---------- Thống kê bệnh nhân theo ngày từ Lịch Hẹn Firebase ----------
  /// homNay: trả về ngày hôm nay dạng "yyyy-MM-dd" (id document thống kê).
  static String homNay() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Stream thống kê số lượt khám bệnh nhân trực tiếp từ collection `LichHen` trên Firebase
  /// Phản ánh realtime: số lượt khám hôm nay, đang khám, đã khám, chờ khám, và tổng lượt đặt
  static Stream<Map<String, int>> thongKeLichHenHomNay(String benhVienId) {
    late StreamController<Map<String, int>> controller;
    StreamSubscription? subLichHen;
    StreamSubscription? subLichHenGroup;

    final Map<String, Map<String, dynamic>> allDocs = {};

    void recompute() {
      if (controller.isClosed) return;
      final now = DateTime.now();
      final dCode =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
      final d1 =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final d2 =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int tongHomNay = 0;
      int dangKham = 0;
      int daKham = 0;
      int choKham = 0;
      int tongTatCa = 0;

      final targetId = benhVienId.trim();

      for (final entry in allDocs.entries) {
        final docId = entry.key;
        final data = entry.value;

        // 1. Kiểm tra tài khoản bệnh viện (benh_vien_id, docId bắt đầu bằng BV...)
        final docBvId = (data['benh_vien_id'] ??
                data['ma_benh_vien'] ??
                data['benhVienId'] ??
                '')
            .toString()
            .trim();

        bool khopBv = false;
        if (targetId.isNotEmpty) {
          if (docBvId.toLowerCase() == targetId.toLowerCase() ||
              docId.startsWith('${targetId}_') ||
              docId.startsWith(targetId)) {
            khopBv = true;
          }
        }
        if (!khopBv && AppSession.benhVienId.isNotEmpty) {
          final sId = AppSession.benhVienId.trim();
          if (docBvId.toLowerCase() == sId.toLowerCase() ||
              docId.startsWith('${sId}_') ||
              docId.startsWith(sId)) {
            khopBv = true;
          }
        }
        if (targetId.isEmpty && AppSession.benhVienId.isEmpty) {
          khopBv = true;
        }

        if (!khopBv) continue;

        tongTatCa++;

        // 2. Kiểm tra ngày hôm nay (hỗ trợ Timestamp ngay_dat, ngay_tao, String ngày hoặc mã ngày trong docId)
        bool khopHomNay = false;
        if (data['ngay_dat'] is Timestamp) {
          final dt = (data['ngay_dat'] as Timestamp).toDate();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            khopHomNay = true;
          }
        }
        if (!khopHomNay && data['ngay_tao'] is Timestamp) {
          final dt = (data['ngay_tao'] as Timestamp).toDate();
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            khopHomNay = true;
          }
        }
        if (!khopHomNay) {
          final s = (data['ngay_dat'] ??
                  data['ngay_hen'] ??
                  data['ngay_kham'] ??
                  '')
              .toString();
          final sTao = (data['ngay_tao'] ?? '').toString();
          if (s.contains(d1) ||
              s.contains(d2) ||
              sTao.contains(d1) ||
              sTao.contains(d2)) {
            khopHomNay = true;
          }
        }
        if (!khopHomNay && docId.contains(dCode)) {
          khopHomNay = true;
        }

        if (khopHomNay) {
          final rawTrangThaiId =
              (data['trang_thai_id'] ?? '1').toString().trim();
          final rawTrangThaiStr =
              (data['trang_thai'] ?? '').toString().toLowerCase();

          // 4: Đã hủy -> Không tính vào lượt khám hợp lệ hôm nay
          if (rawTrangThaiId == '4' || rawTrangThaiStr.contains('huy')) {
            continue;
          }

          tongHomNay++;

          if (rawTrangThaiId == '3' || rawTrangThaiStr.contains('dang_kham')) {
            dangKham++;
          } else if (rawTrangThaiId == '5' ||
              rawTrangThaiStr.contains('da_kham') ||
              rawTrangThaiStr.contains('hoan_thanh')) {
            daKham++;
          } else {
            choKham++;
          }
        }
      }

      controller.add({
        'tongHomNay': tongHomNay,
        'dangKham': dangKham,
        'daKham': daKham,
        'choKham': choKham,
        'tongTatCa': tongTatCa,
      });
    }

    controller = StreamController<Map<String, int>>(
      onListen: () {
        // Lắng nghe collection 'LichHen' gốc (theo đúng Firebase Console của ứng dụng)
        subLichHen = FirebaseFirestore.instance
            .collection('LichHen')
            .snapshots()
            .listen(
          (snap) {
            for (final doc in snap.docs) {
              allDocs[doc.id] = doc.data();
            }
            recompute();
          },
          onError: (e) {
            debugPrint('⚠️ [LichHen] Lỗi stream LichHen: $e');
          },
        );

        // Lắng nghe collectionGroup 'lich_hen' nếu có cấu trúc phân cấp lồng
        subLichHenGroup = FirebaseFirestore.instance
            .collectionGroup('lich_hen')
            .snapshots()
            .listen(
          (snap) {
            for (final doc in snap.docs) {
              allDocs[doc.id] = doc.data();
            }
            recompute();
          },
          onError: (e) {
            debugPrint('⚠️ [LichHen] Lỗi stream collectionGroup lich_hen: $e');
          },
        );
      },
      onCancel: () {
        subLichHen?.cancel();
        subLichHenGroup?.cancel();
      },
    );

    return controller.stream;
  }

  static final Map<String, String> _patientNameCache = {};

  /// Tra cứu tên bệnh nhân theo mã tài khoản / auth uid
  static Future<String> layTenBenhNhan(String benhNhanId) async {
    if (benhNhanId.isEmpty) return 'Bệnh nhân';
    if (_patientNameCache.containsKey(benhNhanId)) {
      return _patientNameCache[benhNhanId]!;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(benhNhanId)
          .get();
      if (userDoc.exists) {
        final uData = userDoc.data();
        final name = (uData?['ho_ten'] ??
                uData?['name'] ??
                uData?['displayName'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty) {
          _patientNameCache[benhNhanId] = name;
          return name;
        }
      }

      final bnDoc = await FirebaseFirestore.instance
          .collection('BenhNhan')
          .doc(benhNhanId)
          .get();
      if (bnDoc.exists) {
        final bnData = bnDoc.data();
        final name =
            (bnData?['ho_ten'] ?? bnData?['ten'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _patientNameCache[benhNhanId] = name;
          return name;
        }
      }
    } catch (_) {}

    return 'Bệnh nhân';
  }

  /// Stream danh sách chi tiết các bệnh nhân khám hôm nay của bệnh viện từ collection `LichHen`
  static Stream<List<Map<String, dynamic>>> streamDanhSachBenhNhanHomNay(
    String benhVienId, {
    DateTime? ngay,
  }) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? subLichHen;
    StreamSubscription? subLichHenGroup;

    final Map<String, Map<String, dynamic>> allDocs = {};

    void recompute() {
      if (controller.isClosed) return;
      final targetDate = ngay ?? DateTime.now();
      final dCode =
          '${targetDate.day.toString().padLeft(2, '0')}${targetDate.month.toString().padLeft(2, '0')}${targetDate.year}';
      final d1 =
          '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';
      final d2 =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final List<Map<String, dynamic>> resultList = [];
      final targetId = benhVienId.trim();

      for (final entry in allDocs.entries) {
        final docId = entry.key;
        final data = entry.value;

        // 1. Kiểm tra tài khoản bệnh viện
        final docBvId = (data['benh_vien_id'] ??
                data['ma_benh_vien'] ??
                data['benhVienId'] ??
                '')
            .toString()
            .trim();

        bool khopBv = false;
        if (targetId.isNotEmpty) {
          if (docBvId.toLowerCase() == targetId.toLowerCase() ||
              docId.startsWith('${targetId}_') ||
              docId.startsWith(targetId)) {
            khopBv = true;
          }
        }
        if (!khopBv && AppSession.benhVienId.isNotEmpty) {
          final sId = AppSession.benhVienId.trim();
          if (docBvId.toLowerCase() == sId.toLowerCase() ||
              docId.startsWith('${sId}_') ||
              docId.startsWith(sId)) {
            khopBv = true;
          }
        }
        if (targetId.isEmpty && AppSession.benhVienId.isEmpty) {
          khopBv = true;
        }

        if (!khopBv) continue;

        // 2. Kiểm tra ngày khám
        bool khopNgay = false;
        if (data['ngay_dat'] is Timestamp) {
          final dt = (data['ngay_dat'] as Timestamp).toDate();
          if (dt.year == targetDate.year &&
              dt.month == targetDate.month &&
              dt.day == targetDate.day) {
            khopNgay = true;
          }
        }
        if (!khopNgay && data['ngay_tao'] is Timestamp) {
          final dt = (data['ngay_tao'] as Timestamp).toDate();
          if (dt.year == targetDate.year &&
              dt.month == targetDate.month &&
              dt.day == targetDate.day) {
            khopNgay = true;
          }
        }
        if (!khopNgay) {
          final s = (data['ngay_dat'] ??
                  data['ngay_hen'] ??
                  data['ngay_kham'] ??
                  '')
              .toString();
          final sTao = (data['ngay_tao'] ?? '').toString();
          if (s.contains(d1) ||
              s.contains(d2) ||
              sTao.contains(d1) ||
              sTao.contains(d2)) {
            khopNgay = true;
          }
        }
        if (!khopNgay && docId.contains(dCode)) {
          khopNgay = true;
        }

        if (!khopNgay) continue;

        // 3. Trạng thái
        final rawTrangThaiId =
            (data['trang_thai_id'] ?? '1').toString().trim();
        final rawTrangThaiStr =
            (data['trang_thai'] ?? '').toString().toLowerCase();

        String trangThaiHienThi = 'Chờ khám';
        if (rawTrangThaiId == '2' ||
            rawTrangThaiStr.contains('tiep_nhan') ||
            rawTrangThaiStr.contains('duyet')) {
          trangThaiHienThi = 'Đã tiếp nhận';
        } else if (rawTrangThaiId == '3' ||
            rawTrangThaiStr.contains('dang_kham')) {
          trangThaiHienThi = 'Đang khám';
        } else if (rawTrangThaiId == '5' ||
            rawTrangThaiStr.contains('da_kham') ||
            rawTrangThaiStr.contains('hoan_thanh')) {
          trangThaiHienThi = 'Đã khám';
        } else if (rawTrangThaiId == '4' || rawTrangThaiStr.contains('huy')) {
          trangThaiHienThi = 'Đã hủy';
        }

        // Tên bệnh nhân
        final hoTen = (data['ho_ten'] ??
                data['ten_benh_nhan'] ??
                data['hoTen'] ??
                data['patient_name'] ??
                '')
            .toString()
            .trim();

        // Ca khám
        final caId = (data['ca_id'] ?? '').toString().trim();
        String caKhamHienThi = caId;
        if (caId == 'ca_sang') {
          caKhamHienThi = 'Ca sáng (07:00 - 11:30)';
        } else if (caId == 'ca_chieu') {
          caKhamHienThi = 'Ca chiều (13:00 - 17:00)';
        }

        resultList.add({
          'id': docId,
          'benh_nhan_id': (data['benh_nhan_id'] ?? '').toString(),
          'ho_ten': hoTen.isNotEmpty ? hoTen : 'Bệnh nhân',
          'sdt': (data['so_dien_thoai'] ?? data['sdt'] ?? data['phone'] ?? '').toString(),
          'ca_id': caId,
          'ca_kham': caKhamHienThi,
          'gio_du_kien': (data['gio_du_kien'] ?? data['gio_kham'] ?? '').toString(),
          'khoa_id': (data['khoa_id'] ?? '').toString(),
          'ten_khoa': (data['ten_khoa'] ?? data['khoa'] ?? '').toString(),
          'phong_kham_id': (data['phong_kham_id'] ?? '').toString(),
          'ten_phong_kham': (data['ten_phong_kham'] ?? '').toString(),
          'trang_thai_id': rawTrangThaiId,
          'trang_thai': trangThaiHienThi,
          'so_thu_tu': ((data['so_thu_tu'] ?? data['stt'] ?? 0) as num).toInt(),
          'quan_he': (data['quan_he'] ?? 'Chính tôi').toString(),
          'profile_id': (data['profile_id'] ?? '').toString(),
          'ngay_dat': data['ngay_dat'],
          'ngay_tao': data['ngay_tao'],
          'raw_data': data,
        });
      }

      // Sắp xếp: theo số thứ tự hoặc id
      resultList.sort((a, b) {
        final sttA = (a['so_thu_tu'] as int?) ?? 0;
        final sttB = (b['so_thu_tu'] as int?) ?? 0;
        if (sttA != 0 && sttB != 0) {
          return sttA.compareTo(sttB);
        }
        return (a['id'] as String).compareTo(b['id'] as String);
      });

      controller.add(resultList);
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        subLichHen = FirebaseFirestore.instance
            .collection('LichHen')
            .snapshots()
            .listen(
          (snap) {
            for (final doc in snap.docs) {
              allDocs[doc.id] = doc.data();
            }
            recompute();
          },
          onError: (e) {
            debugPrint('⚠️ [LichHen] Lỗi streamDanhSachBenhNhan: $e');
          },
        );

        subLichHenGroup = FirebaseFirestore.instance
            .collectionGroup('lich_hen')
            .snapshots()
            .listen(
          (snap) {
            for (final doc in snap.docs) {
              allDocs[doc.id] = doc.data();
            }
            recompute();
          },
          onError: (e) {
            debugPrint('⚠️ [LichHen] Lỗi streamDanhSachBenhNhan group: $e');
          },
        );
      },
      onCancel: () {
        subLichHen?.cancel();
        subLichHenGroup?.cancel();
      },
    );

    return controller.stream;
  }

  /// thongKeHomNay: lắng nghe thống kê hôm nay (tongBenhNhan, dangKham) tại ThongKe/{benhVienId}/danh_sach/{yyyy-MM-dd}.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> thongKeHomNay(
    String benhVienId,
  ) => FirebaseFirestore.instance
      .collection('ThongKe')
      .doc(benhVienId)
      .collection('danh_sach')
      .doc(homNay())
      .snapshots();

  /// tangBenhNhan: cộng dồn số bệnh nhân hôm nay khi có người đăng ký hoặc bắt đầu khám (tự tạo document nếu chưa có).
  static Future<void> tangBenhNhan(
    String benhVienId, {
    int tong = 1,
    int dangKham = 0,
  }) {
    return FirebaseFirestore.instance
        .collection('ThongKe')
        .doc(benhVienId)
        .collection('danh_sach')
        .doc(homNay())
        .set({
          'tongBenhNhan': FieldValue.increment(tong),
          'dangKham': FieldValue.increment(dangKham),
        }, SetOptions(merge: true));
  }
}