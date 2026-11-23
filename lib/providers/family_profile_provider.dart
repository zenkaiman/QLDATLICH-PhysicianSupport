import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/family_profile_model.dart';
import '../models/patient_model.dart';
import '../services/family_profile_service.dart';

class FamilyProfileProvider extends ChangeNotifier {
  final FamilyProfileService _service = FamilyProfileService();

  List<FamilyProfileModel> _profiles = [];
  String? _currentId;
  bool _loading = false;
  String? _error;
  bool _selfEnsured = false;

  List<FamilyProfileModel> get profiles => _profiles;
  String? get currentId => _currentId;
  bool get isLoading => _loading;
  String? get error => _error;
  FamilyProfileModel? get current => byId(_currentId);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// byId: tìm hồ sơ theo id (null nếu không có).
  FamilyProfileModel? byId(String? id) {
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// load: tải danh sách hồ sơ, đảm bảo có hồ sơ bản thân và chọn hồ sơ mặc định nếu chưa chọn.
  Future<void> load(PatientModel? patient, {bool force = false}) async {
    final uid = _uid;
    if (uid == null) return;
    if (_loading) return;
    if (!force && _profiles.isNotEmpty && _selfEnsured) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (patient != null) {
        await _service.ensureSelf(uid, patient);
        _selfEnsured = true;
      }
      _profiles = await _service.fetch(uid);
      if (byId(_currentId) == null && _profiles.isNotEmpty) {
        _currentId = _profiles
            .firstWhere((p) => p.isDefault, orElse: () => _profiles.first)
            .id;
      }
    } catch (e) {
      debugPrint('Lỗi tải hồ sơ người thân: $e');
      _error = 'Không thể tải danh sách hồ sơ.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// select: chọn hồ sơ đang dùng.
  void select(String? id) {
    if (id == null || id == _currentId || byId(id) == null) return;
    _currentId = id;
    notifyListeners();
  }

  /// add: thêm hồ sơ mới rồi tải lại danh sách.
  Future<void> add(FamilyProfileModel p) async {
    final uid = _requireUid();
    await _service.add(uid, p);
    await _reload(uid);
  }

  /// update: cập nhật hồ sơ rồi tải lại danh sách.
  Future<void> update(FamilyProfileModel p) async {
    final uid = _requireUid();
    await _service.update(uid, p);
    await _reload(uid);
  }

  /// remove: xóa hồ sơ (nếu đang chọn thì quay về hồ sơ bản thân) rồi tải lại danh sách.
  Future<void> remove(String profileId) async {
    final uid = _requireUid();
    await _service.delete(uid, profileId);
    if (_currentId == profileId) _currentId = FamilyProfileModel.selfId;
    await _reload(uid);
  }

  /// setDefault: đặt hồ sơ mặc định rồi tải lại danh sách.
  Future<void> setDefault(String profileId) async {
    final uid = _requireUid();
    await _service.setDefault(uid, profileId);
    await _reload(uid);
  }

  /// clear: xóa dữ liệu hồ sơ khi đăng xuất.
  void clear() {
    _profiles = [];
    _currentId = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  /// _requireUid: lấy uid đang đăng nhập, ném lỗi nếu chưa đăng nhập.
  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập.');
    return uid;
  }

  /// _reload: tải lại danh sách hồ sơ và chọn hồ sơ đầu tiên nếu hồ sơ hiện tại không còn.
  Future<void> _reload(String uid) async {
    _profiles = await _service.fetch(uid);
    if (byId(_currentId) == null && _profiles.isNotEmpty) {
      _currentId = _profiles.first.id;
    }
    notifyListeners();
  }
}