import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nhan_vien_model.dart';
import '../models/thong_bao_model.dart';

/// Service quản lý và lắng nghe Thông báo hệ thống bệnh viện
class ThongBaoService {
  final FirebaseFirestore _firestore;

  // Cache danh sách ID thông báo đã đọc để phản hồi tức thì trên UI
  final Map<String, Set<String>> _readIdsCache = {};
  final StreamController<Map<String, Set<String>>> _readController =
      StreamController<Map<String, Set<String>>>.broadcast();

  ThongBaoService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final ThongBaoService instance = ThongBaoService();

  String _getPrefKey(String benhVienId) => 'thong_bao_da_doc_$benhVienId';

  /// Lấy tập hợp các ID thông báo đã đọc từ SharedPreferences
  Future<Set<String>> layDanhSachDaDoc(String benhVienId) async {
    if (_readIdsCache.containsKey(benhVienId)) {
      return _readIdsCache[benhVienId]!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_getPrefKey(benhVienId)) ?? [];
      final set = list.toSet();
      _readIdsCache[benhVienId] = set;
      return set;
    } catch (e) {
      debugPrint('⚠️ [ThongBaoService] Lỗi đọc SharedPreferences: $e');
      return _readIdsCache[benhVienId] ?? <String>{};
    }
  }

  /// Đánh dấu 1 thông báo là đã đọc
  Future<void> danhDauDaDoc(String benhVienId, String thongBaoId) async {
    final set = await layDanhSachDaDoc(benhVienId);
    if (!set.contains(thongBaoId)) {
      set.add(thongBaoId);
      _readIdsCache[benhVienId] = set;
      _readController.add(Map.from(_readIdsCache));

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_getPrefKey(benhVienId), set.toList());
      } catch (e) {
        debugPrint('⚠️ [ThongBaoService] Lỗi lưu trạng thái đã đọc: $e');
      }
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> danhDauTatCaDaDoc(
      String benhVienId, List<String> danhSachId) async {
    final set = await layDanhSachDaDoc(benhVienId);
    set.addAll(danhSachId);
    _readIdsCache[benhVienId] = set;
    _readController.add(Map.from(_readIdsCache));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_getPrefKey(benhVienId), set.toList());
    } catch (e) {
      debugPrint('⚠️ [ThongBaoService] Lỗi lưu tất cả đã đọc: $e');
    }
  }

  /// Lắng nghe realtime danh sách thông báo của Bệnh viện
  /// Bao gồm:
  /// 1. Nhân viên đã kích hoạt tài khoản từ Firestore: NhanVien/{benhVienId}/danh_sach
  /// 2. Danh sách phân công trực từ PhanCong/{benhVienId}/danh_sach để cập nhật trạng thái đã phân công
  /// 3. Các thông báo hệ thống / quản trị khác (nếu có trong collection ThongBao)
  Stream<List<ThongBaoModel>> streamThongBao(String benhVienId) {
    if (benhVienId.isEmpty) {
      return Stream.value([]);
    }

    // Stream nhân sự đã kích hoạt từ NhanVien/{benhVienId}/danh_sach
    final nhanVienStream = _firestore
        .collection('NhanVien')
        .doc(benhVienId)
        .collection('danh_sach')
        .snapshots();

    // Stream danh sách phân công trực để đồng bộ trạng thái "chờ" (15) <-> "đã phân công" (16) realtime
    final phanCongStream = _firestore
        .collection('PhanCong')
        .doc(benhVienId)
        .collection('danh_sach')
        .snapshots()
        .handleError((e) {
      debugPrint('ℹ️ [ThongBaoService] PhanCong stream not available: $e');
    });

    // Stream thông báo bổ sung (nếu có trong ThongBao/{benhVienId}/danh_sach)
    final extraThongBaoStream = _firestore
        .collection('ThongBao')
        .doc(benhVienId)
        .collection('danh_sach')
        .snapshots()
        .handleError((e) {
      // Nếu collection chưa tồn tại thì bỏ qua lỗi
      debugPrint('ℹ️ [ThongBaoService] Extra notifications not available: $e');
    });

    return Stream.multi((controller) {
      StreamSubscription? nvSub;
      StreamSubscription? pcSub;
      StreamSubscription? extraSub;
      StreamSubscription? readSub;

      List<NhanVienModel> currentNvList = [];
      Map<String, DateTime?> tgKichHoatMap = {};
      Map<String, Map<String, dynamic>> phanCongMap = {};
      List<ThongBaoModel> currentExtraList = [];
      Set<String> currentReadSet = {};

      void emitCombined() {
        final Map<String, ThongBaoModel> map = {};

        // 1. Thêm thông báo kích hoạt nhân sự với trạng thái phân công chính xác nhất
        for (final nv in currentNvList) {
          final isRead = currentReadSet.contains('tb_kich_hoat_${nv.maNv}');

          // Tra cứu phân công trực từ PhanCong collection hoặc thông tin trong NhanVien document
          final pc = phanCongMap[nv.maNv] ??
              phanCongMap[nv.id] ??
              (nv.maNv.isNotEmpty ? phanCongMap[nv.maNv.toUpperCase()] : null);

          final bool daPhanCong = pc != null || nv.daPhanCong;
          final String? phongPhanCong = pc?['ten_phong']?.toString() ??
              pc?['phong_id']?.toString() ??
              nv.phongPhanCong;
          final String? ngayPhanCong =
              pc?['ngay']?.toString() ?? nv.ngayPhanCong;

          final item = ThongBaoModel.fromNhanVienKichHoat(
            nv: nv,
            daDoc: isRead,
            thoiGianKichHoat: tgKichHoatMap[nv.maNv],
            daPhanCong: daPhanCong,
            trangThaiId: daPhanCong ? 16 : 15,
            phongPhanCong: phongPhanCong,
            ngayPhanCong: ngayPhanCong,
          );

          map[item.id] = item;
        }

        // 2. Thêm thông báo hệ thống khác
        for (final item in currentExtraList) {
          final isRead = currentReadSet.contains(item.id) || item.daDoc;
          // Cập nhật trạng thái phân công nếu thông báo có maNhanVien
          if (item.maNhanVien != null && item.maNhanVien!.isNotEmpty) {
            final pc = phanCongMap[item.maNhanVien!];
            if (pc != null) {
              map[item.id] = item.copyWith(
                daDoc: isRead,
                daPhanCong: true,
                trangThaiId: 16,
                phongPhanCong: pc['ten_phong']?.toString() ??
                    pc['phong_id']?.toString() ??
                    item.phongPhanCong,
                ngayPhanCong: pc['ngay']?.toString() ?? item.ngayPhanCong,
              );
              continue;
            }
          }
          map[item.id] = item.copyWith(daDoc: isRead);
        }

        // 3. Sắp xếp theo thời gian mới nhất lên đầu
        final sortedList = map.values.toList()
          ..sort((a, b) => b.thoiGian.compareTo(a.thoiGian));

        if (!controller.isClosed) {
          controller.add(sortedList);
        }
      }

      // Khởi tạo đọc cache ban đầu
      layDanhSachDaDoc(benhVienId).then((initialReadSet) {
        currentReadSet = _readIdsCache[benhVienId] ?? initialReadSet;

        // Lắng nghe realtime các bản ghi phân công trực
        pcSub = phanCongStream.listen((snap) {
          final Map<String, Map<String, dynamic>> pcMap = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final ma1 = (data['ma_nhan_vien'] ?? '').toString();
            final ma2 = (data['nhan_vien_id'] ?? '').toString();
            if (ma1.isNotEmpty) pcMap[ma1] = data;
            if (ma2.isNotEmpty) pcMap[ma2] = data;
          }
          phanCongMap = pcMap;
          emitCombined();
        }, onError: (e) {
          debugPrint('⚠️ [ThongBaoService] Lỗi stream PhanCong: $e');
        });

        // Lắng nghe thay đổi nhân sự
        nvSub = nhanVienStream.listen((snap) {
          final List<NhanVienModel> list = [];
          final Map<String, DateTime?> tgMap = {};

          for (final doc in snap.docs) {
            final data = doc.data();

            // Kiểm tra trạng thái kích hoạt tài khoản
            final bool daKichHoat;
            if (data.containsKey('da_kich_hoat')) {
              daKichHoat = data['da_kich_hoat'] == true;
            } else if (data['ngay_kich_hoat'] != null) {
              daKichHoat = true;
            } else {
              final tt = (data['trang_thai'] ?? '').toString();
              daKichHoat = (tt == 'dang_hoat_dong' ||
                      tt == 'đã phân công' ||
                      tt == 'chờ') &&
                  tt != 'doi_kich_hoat' &&
                  tt != 'chua_kich_hoat';
            }

            if (daKichHoat) {
              final nv = NhanVienModel.fromDoc(doc);

              // Lấy thời gian kích hoạt chính xác nếu có
              DateTime? tgKichHoat;
              final rawNgayKh = data['ngay_kich_hoat'] ??
                  data['ngay_cap_nhat'] ??
                  data['ngay_tao'];
              if (rawNgayKh is Timestamp) {
                tgKichHoat = rawNgayKh.toDate();
              }

              list.add(nv);
              tgMap[nv.maNv] = tgKichHoat;
            }
          }

          currentNvList = list;
          tgKichHoatMap = tgMap;
          emitCombined();
        }, onError: (e) {
          debugPrint('⚠️ [ThongBaoService] Lỗi stream NhanVien: $e');
        });

        // Lắng nghe collection ThongBao phụ nếu có
        extraSub = extraThongBaoStream.listen((snap) {
          final List<ThongBaoModel> list = [];
          for (final doc in snap.docs) {
            final isRead = currentReadSet.contains(doc.id);
            list.add(ThongBaoModel.fromDoc(doc, daDoc: isRead));
          }
          currentExtraList = list;
          emitCombined();
        }, onError: (_) {});

        // Lắng nghe thay đổi trạng thái đã đọc
        readSub = _readController.stream.listen((map) {
          currentReadSet = map[benhVienId] ?? <String>{};
          emitCombined();
        });
      });

      controller.onCancel = () {
        nvSub?.cancel();
        pcSub?.cancel();
        extraSub?.cancel();
        readSub?.cancel();
      };
    });
  }

  /// Stream số lượng thông báo chưa đọc (dùng cho badge trên chuông thông báo)
  Stream<int> streamSoLuongChuaDoc(String benhVienId) {
    return streamThongBao(benhVienId).map((list) {
      return list.where((tb) => !tb.daDoc).length;
    });
  }
}
