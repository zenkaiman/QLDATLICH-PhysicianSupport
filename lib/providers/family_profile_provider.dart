import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/family_profile_model.dart';
import '../models/patient_model.dart';
import '../services/family_profile_service.dart';

/// Giữ danh sách hồ sơ + hồ sơ đang được chọn (currentProfileId).
/// Các màn hình Home / Tracking / MyAppointments / QR đọc [currentId] để lọc dữ liệu.
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

  FamilyProfileModel? byId(String? id) {
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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

  void select(String? id) {
    if (id == null || id == _currentId || byId(id) == null) return;
    _currentId = id;
    notifyListeners();
  }

  Future<void> add(FamilyProfileModel p) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập.');
    await _service.add(uid, p);
    await _reload(uid);
  }

  Future<void> update(FamilyProfileModel p) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập.');
    await _service.update(uid, p);
    await _reload(uid);
  }

  Future<void> remove(String profileId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập.');
    await _service.delete(uid, profileId);
    if (_currentId == profileId) _currentId = FamilyProfileModel.selfId;
    await _reload(uid);
  }

  Future<void> setDefault(String profileId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập.');
    await _service.setDefault(uid, profileId);
    await _reload(uid);
  }

  Future<void> _reload(String uid) async {
    _profiles = await _service.fetch(uid);
    if (byId(_currentId) == null && _profiles.isNotEmpty) {
      _currentId = _profiles.first.id;
    }
    notifyListeners();
  }

  /// Gọi khi đăng xuất.
  void clear() {
    _profiles = [];
    _currentId = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}