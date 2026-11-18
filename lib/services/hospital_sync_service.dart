import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import 'auth_service.dart';

/// Dịch vụ quản lý đồng bộ 2 chiều trạng thái giữa [BenhVien] và [YeuCauHopTac],
/// đồng thời chuẩn hóa dữ liệu cần thiết (bhyt, co_so, chuyen_khoa_ids).
class HospitalSyncService {
  static bool _isSyncing = false;

  /// Xây dựng đầy đủ các trường trạng thái đồng bộ cho cả BenhVien và YeuCauHopTac:
  /// - trang_thai_hop_tac_id: 1, 9, 10
  /// - trangThai: "CHO_DUYET", "HUY_HOP_TAC", "HOP_TAC"
  /// - trang_thai: "cho_duyet", "huy_hop_tac", "hop_tac"
  /// - da_gui_don, da_bi_tu_choi, da_xac_thuc
  static Map<String, dynamic> buildStatusFields(dynamic rawStatus) {
    final int statusId = rawStatus is int
        ? rawStatus
        : int.tryParse(rawStatus?.toString() ?? '') ?? TrangThaiId.choDuyet;

    final String trangThaiUpper;
    final String trangThaiLower;
    final bool daGuiDon;
    final bool daBiTuChoi;
    final bool daXacThuc;

    switch (statusId) {
      case TrangThaiId.hopTac: // 10
        trangThaiUpper = 'HOP_TAC';
        trangThaiLower = 'hop_tac';
        daGuiDon = true;
        daBiTuChoi = false;
        daXacThuc = true;
        break;
      case TrangThaiId.huyHopTac: // 9
        trangThaiUpper = 'HUY_HOP_TAC';
        trangThaiLower = 'huy_hop_tac';
        daGuiDon = false;
        daBiTuChoi = true;
        daXacThuc = false;
        break;
      case TrangThaiId.choDuyet: // 1
      default:
        trangThaiUpper = 'CHO_DUYET';
        trangThaiLower = 'cho_duyet';
        daGuiDon = true;
        daBiTuChoi = false;
        daXacThuc = false;
        break;
    }

    return {
      'trang_thai_hop_tac_id': statusId,
      'trangThai': trangThaiUpper,
      'trang_thai': trangThaiLower,
      'da_gui_don': daGuiDon,
      'da_bi_tu_choi': daBiTuChoi,
      'da_xac_thuc': daXacThuc,
    };
  }

  /// Đồng bộ dữ liệu trạng thái từ YeuCauHopTac sang BenhVien
  /// TUYỆT ĐỐI KHÔNG BAO GIỜ hạ trạng thái 10 (Hợp tác) xuống 1 hoặc 9!
  static Future<void> dongBoSangBenhVien(
    String bvid,
    int newStatus, [
    Map<String, dynamic>? sourceData,
  ]) async {
    if (_isSyncing || bvid.isEmpty) return;
    try {
      _isSyncing = true;
      final bvRef = FirebaseFirestore.instance.collection('BenhVien').doc(bvid);
      final bvSnap = await bvRef.get();
      if (!bvSnap.exists) return;
      final currentBvData = bvSnap.data();

      final currentBvRawStatus = currentBvData?['trang_thai_hop_tac_id'];
      final currentBvStatus = currentBvRawStatus is int
          ? currentBvRawStatus
          : int.tryParse(currentBvRawStatus?.toString() ?? '');

      // 🛡️ CHẶN TUYỆT ĐỐI: Nếu BenhVien đã được duyệt là 10 (hoặc da_xac_thuc == true),
      // thì KHÔNG BAO GIỜ bị hạ xuống 1 hoặc 9!
      if (currentBvStatus == TrangThaiId.hopTac || currentBvData?['da_xac_thuc'] == true) {
        if (newStatus != TrangThaiId.hopTac) {
          debugPrint('🛡️ [SYNC AN TOÀN] Chặn hạ trạng thái BenhVien/$bvid từ 10 xuống $newStatus');
          return;
        }
      }

      // Chỉ đồng bộ khi newStatus là 10 (được phê duyệt)
      if (newStatus == TrangThaiId.hopTac) {
        final statusFields = buildStatusFields(TrangThaiId.hopTac);
        if (currentBvStatus != TrangThaiId.hopTac ||
            currentBvData?['trangThai'] != statusFields['trangThai'] ||
            currentBvData?['trang_thai'] != statusFields['trang_thai']) {
          debugPrint('🔄 [SYNC 2 CHIỀU] Đồng bộ phê duyệt YeuCauHopTac (10) -> BenhVien/$bvid');
          await bvRef.set(statusFields, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Lỗi đồng bộ sang BenhVien: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Đồng bộ dữ liệu trạng thái từ BenhVien sang YeuCauHopTac
  /// TUYỆT ĐỐI KHÔNG BAO GIỜ hạ trạng thái 10 (Hợp tác) xuống 1 hoặc 9!
  static Future<void> dongBoSangYeuCauHopTac(
    String bvid,
    int newStatus, [
    Map<String, dynamic>? sourceData,
  ]) async {
    if (_isSyncing || bvid.isEmpty || !bvid.startsWith('BV')) return;
    try {
      _isSyncing = true;
      final ycRef = FirebaseFirestore.instance.collection('YeuCauHopTac').doc(bvid);
      final ycSnap = await ycRef.get();
      if (!ycSnap.exists) return; // Nếu chưa từng gửi đơn thì không tự ý tạo mới

      final currentYcData = ycSnap.data();
      final currentYcRawStatus = currentYcData?['trang_thai_hop_tac_id'];
      final currentYcStatus = currentYcRawStatus is int
          ? currentYcRawStatus
          : int.tryParse(currentYcRawStatus?.toString() ?? '');

      // 🛡️ CHẶN TUYỆT ĐỐI: Nếu YeuCauHopTac đã là 10, không bao giờ bị hạ xuống 1 hoặc 9!
      if (currentYcStatus == TrangThaiId.hopTac) {
        if (newStatus != TrangThaiId.hopTac) {
          debugPrint('🛡️ [SYNC AN TOÀN] Chặn hạ trạng thái YeuCauHopTac/$bvid từ 10 xuống $newStatus');
          return;
        }
      }

      // Chỉ đồng bộ khi newStatus là 10 (được phê duyệt)
      if (newStatus == TrangThaiId.hopTac) {
        final statusFields = buildStatusFields(TrangThaiId.hopTac);
        if (currentYcStatus != TrangThaiId.hopTac ||
            currentYcData?['trangThai'] != statusFields['trangThai'] ||
            currentYcData?['trang_thai'] != statusFields['trang_thai']) {
          debugPrint('🔄 [SYNC 2 CHIỀU] Đồng bộ phê duyệt BenhVien (10) -> YeuCauHopTac/$bvid');
          await ycRef.set(statusFields, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SYNC] Lỗi đồng bộ sang YeuCauHopTac: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Quét và chuẩn hóa toàn bộ collection YeuCauHopTac:
  /// - Chuyển tất cả các document có ID là Auth UID (như BITsNfHi8..., PO3Fm6k...)
  ///   thành Document ID chuẩn theo ID Bệnh Viện (BV502, BV503,...)
  /// - Bổ sung đầy đủ ma_benh_vien, benh_vien_id, id, uid, auth_uid
  /// - Xóa sạch các document ID rác/Auth UID trong cả YeuCauHopTac và BenhVien
  static Future<void> chuanHoaVaDonDepYeuCauHopTac() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapYeuCau = await firestore.collection('YeuCauHopTac').get();

      for (final doc in snapYeuCau.docs) {
        final docId = doc.id;
        final data = doc.data();

        // Nếu ID đã chuẩn BVxxx rồi thì chỉ đảm bảo có đủ trường id và ma_benh_vien
        if (docId.startsWith('BV')) {
          final int? idNum = data['id'] is int
              ? data['id']
              : int.tryParse(docId.replaceAll(RegExp(r'[^0-9]'), ''));
          final updates = <String, dynamic>{};
          if (data['ma_benh_vien'] == null) updates['ma_benh_vien'] = docId;
          if (data['benh_vien_id'] == null) updates['benh_vien_id'] = docId;
          if (data['id'] == null && idNum != null) updates['id'] = idNum;
          if (data['uid'] == null) updates['uid'] = docId;
          if (updates.isNotEmpty) {
            await doc.reference.set(updates, SetOptions(merge: true));
          }
          continue;
        }

        // Tài liệu có ID tự sinh / Auth UID (ví dụ: BITs..., PO3F...)
        debugPrint('🧹 [MIGRATE] Phát hiện YeuCauHopTac với Auth UID: $docId, tiến hành di chuyển sang BVxxx...');

        String? targetBvId;
        int? targetIdNum;

        // 1. Kiểm tra xem trong data có ma_benh_vien hoặc benh_vien_id hợp lệ không
        final mbv = data['ma_benh_vien']?.toString() ?? data['benh_vien_id']?.toString();
        if (mbv != null && mbv.startsWith('BV')) {
          targetBvId = mbv;
        }

        // 2. Tìm trong BenhVien theo auth_uid == docId hoặc email
        if (targetBvId == null) {
          final qAuth = await firestore
              .collection('BenhVien')
              .where('auth_uid', isEqualTo: docId)
              .limit(1)
              .get();
          if (qAuth.docs.isNotEmpty && qAuth.docs.first.id.startsWith('BV')) {
            targetBvId = qAuth.docs.first.id;
          }
        }

        if (targetBvId == null && data['email'] != null && data['email'].toString().isNotEmpty) {
          final qEmail = await firestore
              .collection('BenhVien')
              .where('email', isEqualTo: data['email'])
              .limit(1)
              .get();
          for (final bDoc in qEmail.docs) {
            if (bDoc.id.startsWith('BV')) {
              targetBvId = bDoc.id;
              break;
            }
          }
        }

        // 3. Nếu vẫn không tìm thấy bệnh viện khớp trong BenhVien, sinh mã BV mới
        if (targetBvId == null) {
          final gen = await AuthService().generateHospitalId();
          targetBvId = gen['ma_benh_vien'] as String;
          targetIdNum = gen['id'] as int;
        } else {
          targetIdNum = int.tryParse(targetBvId.replaceAll(RegExp(r'[^0-9]'), ''));
        }

        // Chuẩn hóa dữ liệu mới
        final migratedData = Map<String, dynamic>.from(data);
        migratedData['id'] = targetIdNum;
        migratedData['ma_benh_vien'] = targetBvId;
        migratedData['benh_vien_id'] = targetBvId;
        migratedData['uid'] = targetBvId;
        migratedData['auth_uid'] = docId;

        // Lưu vào YeuCauHopTac với ID chuẩn BVxxx
        await firestore
            .collection('YeuCauHopTac')
            .doc(targetBvId)
            .set(migratedData, SetOptions(merge: true));

        // Đồng thời đảm bảo BenhVien/{targetBvId} cũng có đủ dữ liệu
        await firestore
            .collection('BenhVien')
            .doc(targetBvId)
            .set(migratedData, SetOptions(merge: true));

        // Xóa document cũ với ID Auth UID
        await doc.reference.delete();
        debugPrint('✅ [MIGRATE] Đã di chuyển YeuCauHopTac $docId -> $targetBvId và xóa bản ghi cũ');

        // Xóa document ID tự sinh tương ứng trong BenhVien nếu có
        try {
          await firestore.collection('BenhVien').doc(docId).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [MIGRATE] Lỗi chuẩn hóa YeuCauHopTac: $e');
    }
  }

  /// Quét định kỳ / khi khởi chạy để đồng bộ 2 chiều và chuẩn hóa dữ liệu
  static Future<void> quetVaChuanHoaBenhVienDaGuiDon() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 0. Quét dọn và di chuyển tất cả các document Auth UID trong YeuCauHopTac về dạng chuẩn BVxxx
      await chuanHoaVaDonDepYeuCauHopTac();

      // 1. Nếu một trong hai bên đã được phê duyệt là 10 (Hợp tác), đồng bộ nâng bên kia lên 10
      // 🛡️ TUYỆT ĐỐI KHÔNG BAO GIỜ hạ 10 xuống 1 hoặc 9!
      final snapYeuCau = await firestore.collection('YeuCauHopTac').get();
      for (final doc in snapYeuCau.docs) {
        if (!doc.id.startsWith('BV')) continue;
        final ycData = doc.data();
        final ycStatus = ycData['trang_thai_hop_tac_id'];
        final int? ycStatusId = ycStatus is int ? ycStatus : int.tryParse(ycStatus?.toString() ?? '');

        final targetId = doc.id;
        final bvDocRef = firestore.collection('BenhVien').doc(targetId);
        final bvSnap = await bvDocRef.get();
        if (bvSnap.exists) {
          final bvData = bvSnap.data();
          final bvStatus = bvData?['trang_thai_hop_tac_id'];
          final int? bvStatusId = bvStatus is int ? bvStatus : int.tryParse(bvStatus?.toString() ?? '');

          // Nếu 1 trong 2 bên là 10 -> Cả 2 cùng phải là 10!
          if (bvStatusId == TrangThaiId.hopTac || ycStatusId == TrangThaiId.hopTac) {
            final expected10 = buildStatusFields(TrangThaiId.hopTac);
            if (bvStatusId != TrangThaiId.hopTac) {
              await bvDocRef.set(expected10, SetOptions(merge: true));
            }
            if (ycStatusId != TrangThaiId.hopTac) {
              await doc.reference.set(expected10, SetOptions(merge: true));
            }
          }
        }
      }

      // 3. Chuẩn hóa co_so, bhyt, chuyen_khoa_ids
      final snapBv = await firestore
          .collection('BenhVien')
          .where('da_gui_don', isEqualTo: true)
          .get();
      for (final doc in snapBv.docs) {
        if (doc.id.startsWith('BV')) {
          chuanHoaDuLieuFirebaseNeuThieu(doc);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [HospitalSyncService] Lỗi quét chuẩn hóa dữ liệu: $e');
    }
  }

  /// Bổ sung co_so, bhyt, chuyen_khoa_ids nếu còn thiếu
  static void chuanHoaDuLieuFirebaseNeuThieu(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.id.startsWith('BV')) return;
    final data = doc.data();
    if (data == null) return;
    final bool canCapNhat = data['bhyt'] == null ||
        data['co_so'] == null ||
        data['chuyen_khoa_ids'] == null;
    if (canCapNhat) {
      final updates = <String, dynamic>{};
      if (data['bhyt'] == null) {
        final coBhyt = data['co_bhyt'];
        updates['bhyt'] = (coBhyt == false) ? 'Khong_BHYT' : 'Co_BHYT';
      }
      if (data['co_so'] == null) {
        final loaiHinh = (data['loai_hinh'] ?? '').toString().toLowerCase();
        updates['co_so'] =
            (loaiHinh.contains('công') || loaiHinh.contains('cong'))
                ? 'Cong_lap'
                : 'Tu_nhan';
      }
      if (data['chuyen_khoa_ids'] == null) {
        updates['chuyen_khoa_ids'] = <String>[];
      }
      doc.reference.update(updates).catchError((_) {});
      try {
        FirebaseFirestore.instance
            .collection('YeuCauHopTac')
            .doc(doc.id)
            .get()
            .then((ycSnap) {
              if (ycSnap.exists) {
                ycSnap.reference.set(updates, SetOptions(merge: true)).catchError((_) {});
              }
            })
            .catchError((_) {});
      } catch (_) {}
    }
  }
}
