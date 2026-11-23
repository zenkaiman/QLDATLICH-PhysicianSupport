import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';
import '../models/family_profile_model.dart';
import '../models/patient_model.dart';

class FamilyProfileService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// _col: tham chiếu collection hồ sơ người thân của một tài khoản.
  CollectionReference<Map<String, dynamic>> _col(String uid) => _fs
      .collection(AppConstants.patientsCollection)
      .doc(uid)
      .collection('profiles');

  /// ensureSelf: đảm bảo luôn có hồ sơ chính chủ và đồng bộ dữ liệu từ PatientModel để hồ sơ không bị cũ khi người dùng sửa thông tin cá nhân.
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

  /// fetch: lấy danh sách hồ sơ của tài khoản, hồ sơ chính chủ đứng đầu, còn lại theo thời gian tạo.
  Future<List<FamilyProfileModel>> fetch(String uid) async {
    final snap = await _col(uid).get();
    final list = snap.docs
        .map((d) => FamilyProfileModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) {
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return list;
  }

  /// add: thêm hồ sơ người thân mới (id tự sinh, không phải mặc định) và trả về id.
  Future<String> add(String uid, FamilyProfileModel p) async {
    final ref = _col(uid).doc();
    await ref.set({
      ...p.toMap(),
      'is_default': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// update: cập nhật hồ sơ, không đổi cờ mặc định.
  Future<void> update(String uid, FamilyProfileModel p) async {
    final data = p.toMap()..remove('is_default');
    await _col(uid).doc(p.id).update(data);
  }

  /// delete: xóa hồ sơ người thân (không cho xóa hồ sơ chính chủ); lịch hẹn cũ giữ nguyên vì đã lưu sẵn ten_nguoi_kham.
  Future<void> delete(String uid, String profileId) async {
    if (profileId == FamilyProfileModel.selfId) {
      throw Exception('Không thể xóa hồ sơ chính chủ.');
    }
    await _col(uid).doc(profileId).delete();
  }

  /// setDefault: đặt một hồ sơ làm mặc định và bỏ cờ mặc định của các hồ sơ còn lại.
  Future<void> setDefault(String uid, String profileId) async {
    final all = await _col(uid).get();
    final batch = _fs.batch();
    for (final d in all.docs) {
      batch.update(d.reference, {'is_default': d.id == profileId});
    }
    await batch.commit();
  }
}