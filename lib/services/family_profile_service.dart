import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';
import '../models/family_profile_model.dart';
import '../models/patient_model.dart';

class FamilyProfileService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _fs
      .collection(AppConstants.patientsCollection)
      .doc(uid)
      .collection('profiles');

  /// Đảm bảo luôn có hồ sơ chính chủ, và đồng bộ dữ liệu từ PatientModel
  /// (để khi người dùng sửa "Hồ sơ cá nhân" thì hồ sơ chính chủ không bị cũ).
  Future<void> ensureSelf(String uid, PatientModel p) async {
    final ref = _col(uid).doc(FamilyProfileModel.selfId);
    final snap = await ref.get();

    final synced = <String, dynamic>{
      if ((p.hoTen ?? '').isNotEmpty) 'ho_ten': p.hoTen,
      if (p.ngaySinh != null) 'ngay_sinh': Timestamp.fromDate(p.ngaySinh!),
      if ((p.gioiTinh ?? '').isNotEmpty) 'gioi_tinh': p.gioiTinh,
      if ((p.cccd ?? '').isNotEmpty) 'so_cccd': p.cccd,
      if ((p.soDienThoai ?? '').isNotEmpty) 'so_dien_thoai': p.soDienThoai,
    };

    if (!snap.exists) {
      await ref.set({
        'ho_ten': p.hoTen ?? '',
        'gioi_tinh': p.gioiTinh ?? '',
        'so_cccd': p.cccd ?? '',
        'so_dien_thoai': p.soDienThoai ?? '',
        'quan_he': FamilyProfileModel.quanHeBanThan,
        'anh_dai_dien': '',
        'is_default': true,
        'created_at': FieldValue.serverTimestamp(),
        ...synced,
      });
    } else if (synced.isNotEmpty) {
      await ref.set(synced, SetOptions(merge: true));
    }
  }

  Future<List<FamilyProfileModel>> fetch(String uid) async {
    final snap = await _col(uid).get();
    final list = snap.docs
        .map((d) => FamilyProfileModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) {
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1; // chính chủ lên đầu
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return list;
  }

  Future<String> add(String uid, FamilyProfileModel p) async {
    final ref = _col(uid).doc(); // id tự sinh
    await ref.set({
      ...p.toMap(),
      'is_default': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String uid, FamilyProfileModel p) async {
    final data = p.toMap()..remove('is_default'); // không đổi cờ mặc định ở đây
    await _col(uid).doc(p.id).update(data);
  }

  Future<void> delete(String uid, String profileId) async {
    if (profileId == FamilyProfileModel.selfId) {
      throw Exception('Không thể xóa hồ sơ chính chủ.');
    }
    // Không xóa lịch hẹn cũ: LichHen đã lưu sẵn ten_nguoi_kham (denormalize).
    await _col(uid).doc(profileId).delete();
  }

  Future<void> setDefault(String uid, String profileId) async {
    final all = await _col(uid).get();
    final batch = _fs.batch();
    for (final d in all.docs) {
      batch.update(d.reference, {'is_default': d.id == profileId});
    }
    await batch.commit();
  }
}