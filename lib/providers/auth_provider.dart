import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_routes.dart';
import '../config/app_session.dart';
import '../config/constants.dart';
import '../config/staff_session.dart';
import '../models/hospital_model.dart';
import '../models/patient_model.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _securityWatcherSub;

  @override
  void notifyListeners() {
    // Tránh lỗi FlutterError: setState() or markNeedsBuild() called during build
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          super.notifyListeners();
        }
      });
    } else {
      super.notifyListeners();
    }
  }

  AuthProvider() {
    _initAutoRestore();
  }

  void _initAutoRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cur = _authService.currentUser;
      if (cur != null) {
        await fetchCurrentUser(preferredRole: 'benh_vien');
        final reason = _blockReason();
        if (reason != null) {
          await forceSignOut(reason: reason);
        }
      }
    });
  }

  PatientModel? _user;
  HospitalModel? _hospital;
  Map<String, dynamic>? _admin;
  String? _selectedRole;
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String? _pendingPhone;

  PatientModel? get user => _user;
  HospitalModel? get hospital => _hospital;
  Map<String, dynamic>? get admin => _admin;
  String? get selectedRole => _selectedRole;
  List<Map<String, dynamic>> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get pendingPhone => _pendingPhone;

  Map<String, dynamic>? get currentRoleInfo {
    if (_selectedRole == null || _roles.isEmpty) return null;
    return _roles.firstWhere(
      (role) => role['ma_vai_tro'] == _selectedRole,
      orElse: () => {},
    );
  }

  Future<Map<String, dynamic>?> getAdminFromFirestore(String uid) {
    return _authService.getAdminFromFirestore(uid);
  }

  Future<void> loadRoles() async {
    if (_roles.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      _roles = await _authService.getRoles();
      if (_roles.isNotEmpty && _selectedRole == null) {
        _selectedRole = _roles.first['ma_vai_tro'];
      }
    } catch (e) {
      print('❌ Lỗi khi load roles: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedRole(String maVaiTro) {
    _selectedRole = maVaiTro;
    notifyListeners();
  }

  /// Trả về lý do nếu tài khoản hiện tại đang bị khóa / ngừng hợp tác, ngược lại trả về null.
  /// Hồ sơ bệnh viện đang "chờ duyệt" KHÔNG bị coi là bị khóa (vẫn cần đăng nhập để nộp hồ sơ).
  String? _blockReason() {
    final u = _user;
    if (u != null) {
      final blocked = u.isBlocked ||
          u.chanDangNhap ||
          u.trangThaiId == TrangThaiId.khongHoatDong;
      if (blocked) return u.lyDoKhoa ?? 'Tài khoản bệnh nhân đã bị khóa';
    }
    final h = _hospital;
    if (h != null) {
      final blocked =
          h.chanDangNhap || h.trangThaiHopTacId == TrangThaiId.huyHopTac;
      if (blocked) {
        return h.lyDoKhoa ??
            'Cơ sở y tế đã ngừng hợp tác hoặc bị chặn truy cập';
      }
    }
    return null;
  }

  Future<void> fetchCurrentUser({String? preferredRole}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      if (preferredRole == 'benh_vien') {
        var hospital = await _authService.getHospitalFromFirestore(currentUser.uid);
        hospital ??= await _authService.findHospitalByEmail(currentUser.email ?? '');

        final patient = await _authService.getPatientFromFirestore(currentUser.uid);
        if (patient != null) hospital = null;

        _hospital = hospital;
        _user = null;
        _selectedRole = hospital != null ? 'benh_vien' : null;
        if (hospital != null) {
          AppSession.benhVienId = hospital.maBenhVien ?? hospital.uid ?? currentUser.uid;
        }
      } else {
        final patientModel = await _authService.getPatientFromFirestore(currentUser.uid);
        _user = patientModel;

        if (patientModel == null) {
          _hospital = await _authService.getHospitalFromFirestore(currentUser.uid);
          _hospital ??= await _authService.findHospitalByEmail(currentUser.email ?? '');
          if (_hospital != null) {
            AppSession.benhVienId = _hospital!.uid ?? currentUser.uid;
          }
        } else {
          _hospital = null;
        }
        _selectedRole = patientModel?.role ?? _hospital?.role;
      }

      // Chỉ bật theo dõi realtime khi tài khoản chưa bị khóa
      // (nếu đã bị khóa thì nơi gọi sẽ xử lý: login ném lỗi, restore thì đăng xuất)
      if (_blockReason() == null) {
        if (_hospital != null) {
          _startSecurityWatcher(
            _hospital!.maBenhVien ?? _hospital!.uid ?? currentUser.uid,
            isHospital: true,
          );
        } else if (_user != null) {
          _startSecurityWatcher(currentUser.uid, isHospital: false);
        }
      }
    } catch (e) {
      print('❌ Lỗi khi lấy thông tin user hiện tại: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> restoreSession() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) return 'login';

    final admin = await _authService.getAdminFromFirestore(firebaseUser.uid);
    if (admin != null) {
      _admin = admin;
      _user = null;
      _hospital = null;
      _selectedRole = 'admin';
      notifyListeners();
      return 'admin';
    }

    await fetchCurrentUser();

    final reason = _blockReason();
    if (reason != null) {
      await forceSignOut(reason: reason);
      return 'login';
    }

    final hasEmail = (firebaseUser.email ?? '').isNotEmpty;
    final isEmailUnverified = hasEmail && (_user?.daXacThucEmail == false || _hospital?.daXacThucEmail == false);

    if (isEmailUnverified) {
      await _authService.signOut();
      _user = null;
      _hospital = null;
      notifyListeners();
      return 'login';
    }

    if (_user != null) {
      await FCMService().init();
      return 'patient';
    }
    if (_hospital != null) {
      await FCMService().init();
      return 'hospital';
    }
    return 'login';
  }

  Future<void> loginAdmin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final adminData = await _authService.loginAdmin(email: email, password: password);
      if (adminData == null) {
        throw Exception('Tài khoản này không có quyền quản trị viên.');
      }

      _user = null;
      _hospital = null;
      _admin = adminData;
      _selectedRole = 'admin';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    String? role,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signInWithEmailAndPassword(email: email, password: password);
      _admin = null;

      // 1. Đồng bộ trạng thái xác thực từ Firebase Auth sang Firestore
      final currentFbUser = _authService.currentUser;
      await currentFbUser?.reload();
      final freshFbUser = _authService.currentUser;
      final isAuthEmailVerified = freshFbUser?.emailVerified ?? false;

      if (freshFbUser != null && isAuthEmailVerified) {
        try {
          await _authService.updateUserVerificationStatus(freshFbUser.uid, true);
        } catch (_) {}
      }

      await fetchCurrentUser(preferredRole: role);

      // 2. Kiểm tra tài khoản bị khóa / ngừng hợp tác
      final reason = _blockReason();
      if (reason != null) {
        final isPatient = _user != null;
        await _authService.signOut();
        _user = null;
        _hospital = null;
        notifyListeners();
        throw Exception(
          isPatient ? 'ACCOUNT_BLOCKED: $reason' : 'HOSPITAL_BLOCKED: $reason',
        );
      }

      // 3. Kiểm tra xác thực email
      final isFirestoreEmailVerified = (_user?.daXacThucEmail ?? false) || (_hospital?.daXacThucEmail ?? false);
      final isVerified = isAuthEmailVerified || isFirestoreEmailVerified;

      if (!isVerified) {
        // KHÔNG gọi signOut() để giữ session cho màn hình EmailVerificationScreen
        throw Exception('EMAIL_NOT_VERIFIED');
      }

      await FCMService().init();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendOtp({
    required String phone,
    required VoidCallback onCodeSent,
    required void Function(String message) onError,
  }) async {
    _isLoading = true;
    notifyListeners();
    _pendingPhone = phone;

    await _authService.sendOtp(
      phone: phone,
      resendToken: _resendToken,
      onCodeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        _isLoading = false;
        notifyListeners();
        onCodeSent();
      },
      onError: (message) {
        _isLoading = false;
        notifyListeners();
        onError(message);
      },
    );
  }

  Future<void> loginWithPhoneOtp({required String smsCode}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_verificationId == null) throw Exception('Mã xác thực không hợp lệ');
      await _authService.verifyOtp(verificationId: _verificationId!, smsCode: smsCode);

      _admin = null;
      await fetchCurrentUser(preferredRole: 'benh_nhan');

      if (_user == null) {
        final hasAnyProfile = _hospital != null;
        _hospital = null;
        if (hasAnyProfile) {
          await _authService.signOut();
        } else {
          try {
            await _authService.currentUser?.delete();
          } catch (_) {
            await _authService.signOut();
          }
        }
        throw Exception('Số điện thoại này chưa đăng ký tài khoản bệnh nhân. Vui lòng đăng ký trước.');
      }

      final reason = _blockReason();
      if (reason != null) {
        await _authService.signOut();
        _user = null;
        notifyListeners();
        throw Exception('ACCOUNT_BLOCKED: $reason');
      }

      await FCMService().init();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required PatientModel user,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _authService.registerWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();

      final newUser = PatientModel.fromRegisterEmail(
        uid: credential.user!.uid,
        hoTen: user.hoTen!,
        email: email,
        role: user.role,
      ).copyWith(daXacThucEmail: false);

      await _authService.saveUserToFirestore(newUser);
      _user = newUser;
      _hospital = null;
      await FCMService().init();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _handleExistingEmail(email, password, user);
        return;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerHospitalWithEmail({
    required String email,
    required String password,
    required HospitalModel hospital,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _authService.registerWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();

      final idData = await _authService.generateHospitalId();
      final nextId = idData['id'] as int;
      final nextMaBv = idData['ma_benh_vien'] as String;

      final newHospital = HospitalModel.fromRegisterEmail(
        id: nextId,
        maBenhVien: nextMaBv,
        uid: nextMaBv,
        authUid: credential.user!.uid,
        tenBenhVien: hospital.tenBenhVien!,
        email: email,
        diaChi: hospital.diaChi,
        role: hospital.role,
      ).copyWith(daXacThucEmail: false);

      await _authService.saveHospitalToFirestore(newHospital);
      _hospital = newHospital;
      _user = null;
      AppSession.benhVienId = nextMaBv;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _handleExistingHospitalEmail(email, password, hospital);
        return;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtpAndRegister({
    required String smsCode,
    required PatientModel user,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_verificationId == null) throw Exception('Mã xác thực không hợp lệ');

      final credential = await _authService.verifyOtp(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      _admin = null;

      // Kiểm tra xem UID này đã có hồ sơ bệnh nhân chưa (tránh ghi đè)
      final existing = await _authService.getPatientFromFirestore(credential.user!.uid);
      if (existing != null) {
        await _authService.signOut();
        throw Exception('Số điện thoại này đã được đăng ký. Vui lòng đăng nhập bằng mã OTP.');
      }

      // Tạo và lưu hồ sơ bệnh nhân mới
      final newUser = PatientModel.fromRegisterPhone(
        uid: credential.user!.uid,
        hoTen: user.hoTen!,
        soDienThoai: _pendingPhone!,
        role: user.role,
      );

      await _authService.saveUserToFirestore(newUser);
      _user = newUser;
      _hospital = null;
      _selectedRole = newUser.role;

      await FCMService().init();
    } catch (e) {
      print('❌ Lỗi khi đăng ký bằng OTP: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) {
    return _authService.resetPassword(email);
  }

  Future<void> _handleExistingEmail(String email, String password, PatientModel user) async {
    try {
      final oldUser = await _authService.findPatientByEmail(email);

      if (oldUser != null && oldUser.daXacThucEmail == false) {
        print('⚠️ Phát hiện tài khoản BN cũ chưa xác thực: ${oldUser.uid}');

        await _signInToReplaceUnverifiedAccount(email, password);
        await _authService.deleteUnverifiedPatient(oldUser.uid);
        print('✅ Đã xóa sạch tài khoản BN cũ.');

        final newCredential = await _authService.registerWithEmailAndPassword(email: email, password: password);
        await newCredential.user?.sendEmailVerification();

        final newUser = PatientModel.fromRegisterEmail(
          uid: newCredential.user!.uid,
          hoTen: user.hoTen!,
          email: email,
          role: user.role,
        ).copyWith(daXacThucEmail: false);

        await _authService.saveUserToFirestore(newUser);
        _user = newUser;
        _hospital = null;
        print('✅ Đã tạo tài khoản BN mới thành công cho email: $email');
      } else {
        throw Exception('Email đã được sử dụng và xác thực. Vui lòng sử dụng tính năng Đăng nhập.');
      }
    } catch (e) {
      print('❌ Lỗi khi xử lý email BN tồn tại: $e');
      rethrow;
    }
  }

  Future<void> _handleExistingHospitalEmail(String email, String password, HospitalModel hospital) async {
    final oldHospital = await _authService.findHospitalByEmail(email);

    if (oldHospital == null || oldHospital.daXacThucEmail) {
      throw Exception('Email đã được sử dụng và xác thực. Vui lòng sử dụng tính năng Đăng nhập.');
    }

    try {
      await _signInToReplaceUnverifiedAccount(email, password);

      final uidToDelete = oldHospital.uid ?? oldHospital.authUid ?? '';
      await _authService.deleteUnverifiedHospital(uidToDelete);
      print('✅ Đã xóa sạch tài khoản BV cũ chưa xác thực.');

      final credential = await _authService.registerWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();

      final idData = await _authService.generateHospitalId();
      final nextId = oldHospital.id ?? (idData['id'] as int);
      final nextMaBv = oldHospital.maBenhVien ?? (idData['ma_benh_vien'] as String);

      final newHospital = HospitalModel.fromRegisterEmail(
        id: nextId,
        maBenhVien: nextMaBv,
        uid: nextMaBv,
        authUid: credential.user!.uid,
        tenBenhVien: hospital.tenBenhVien!,
        email: email,
        diaChi: hospital.diaChi,
        role: hospital.role,
      ).copyWith(daXacThucEmail: false);

      await _authService.saveHospitalToFirestore(newHospital);
      _hospital = newHospital;
      _user = null;
      AppSession.benhVienId = nextMaBv;

      print('✅ Đã tạo lại tài khoản BV mới thành công cho email: $email');
    } catch (e) {
      print('❌ Lỗi khi xử lý email BV tồn tại: $e');
      rethrow;
    }
  }

  Future<void> _signInToReplaceUnverifiedAccount(String email, String password) async {
    try {
      await _authService.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        throw Exception('Email đã có tài khoản chưa xác thực nhưng mật khẩu không khớp. Vui lòng đăng nhập hoặc đặt lại mật khẩu.');
      }
      rethrow;
    }
  }

  Future<void> markEmailAsVerified() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.updateUserVerificationStatus(user.uid, true);

        _user = await _authService.getPatientFromFirestore(user.uid);
        _hospital = _user == null ? await _authService.getHospitalFromFirestore(user.uid) : null;

        if (_hospital != null) {
          AppSession.benhVienId = _hospital!.maBenhVien ?? _hospital!.uid ?? user.uid;
        }
        notifyListeners();
      }
    } catch (e) {
      print('❌ Lỗi khi cập nhật trạng thái xác thực: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? hoTen,
    String? gioiTinh,
    DateTime? ngaySinh,
    String? diaChi,
    String? email,
    String? soDienThoai,
    String? cccd,
    String? soBhyt,
  }) async {
    if (_user == null) {
      throw Exception('Không tìm thấy thông tin người dùng để cập nhật.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateUserProfile(
        uid: _user!.uid,
        hoTen: hoTen,
        gioiTinh: gioiTinh,
        ngaySinh: ngaySinh,
        diaChi: diaChi,
        email: email,
        soDienThoai: soDienThoai,
        cccd: cccd,
        soBhyt: soBhyt,
      );

      _user = _user!.copyWith(
        hoTen: hoTen ?? _user!.hoTen,
        gioiTinh: gioiTinh ?? _user!.gioiTinh,
        ngaySinh: ngaySinh ?? _user!.ngaySinh,
        diaChi: diaChi ?? _user!.diaChi,
        email: email ?? _user!.email,
        soDienThoai: soDienThoai ?? _user!.soDienThoai,
        cccd: cccd ?? _user!.cccd,
        soBhyt: soBhyt ?? _user!.soBhyt,
      );

      if (email != null && email != _authService.currentUser?.email) {
        try {
          await _authService.currentUser?.updateEmail(email);
          print('✅ [DEBUG] Đã cập nhật email Firebase Auth.');
        } catch (e) {
          print('⚠️ [DEBUG] Không thể cập nhật email Firebase Auth (yêu cầu xác thực lại): $e');
        }
      }
    } catch (e) {
      print('❌ [DEBUG] Lỗi khi cập nhật hồ sơ: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> chuanHoaBenhVienDaDangKy([String? maBv]) async {
    try {
      await _authService.chuanHoaBenhVienDaDangKyHopTac(maBv);
    } catch (_) {}
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      _securityWatcherSub?.cancel();
      _securityWatcherSub = null;
      await _authService.signOut();
      await StaffSession.clear();
      _user = null;
      _hospital = null;
      _admin = null;
      _selectedRole = null;
      _verificationId = null;
      _resendToken = null;
      _pendingPhone = null;
    } catch (e) {
      print('❌ Lỗi khi đăng xuất: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // BẢO MẬT THỜI GIAN THỰC (REALTIME SECURITY WATCHER)
  // Tự động kiểm tra và ĐÁ VĂNG (Kick out) người dùng ngay lập tức khi bị Admin khóa
  // docId: với bệnh nhân là Auth UID, với bệnh viện là mã BV (VD: BV502)
  // =========================================================================
  void _startSecurityWatcher(String docId, {required bool isHospital}) {
    _securityWatcherSub?.cancel();
    final collection = isHospital
        ? AppConstants.hospitalsCollection
        : AppConstants.patientsCollection;

    _securityWatcherSub = FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        // Chỉ đá bệnh nhân khi hồ sơ bị xóa (hồ sơ bệnh viện có thể lưu theo id khác)
        if (!isHospital) {
          await forceSignOut(reason: 'Tài khoản của bạn đã bị xóa khỏi hệ thống.');
        }
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      bool shouldKick = false;
      String kickReason = '';

      if (isHospital) {
        final statusId = (data['trang_thai_hop_tac_id'] as num?)?.toInt() ?? TrangThaiId.choDuyet;
        final chanDangNhap = data['chan_dang_nhap'] == true || data['is_blocked'] == true;
        final isHuy = statusId == TrangThaiId.huyHopTac ||
            data['trang_thai'] == 'huy_hop_tac' ||
            data['trangThai'] == 'HUY_HOP_TAC';
        if (chanDangNhap || isHuy) {
          shouldKick = true;
          kickReason = data['ly_do_huy']?.toString() ??
              data['ly_do_khoa']?.toString() ??
              'Cơ sở y tế đã bị ngừng hợp tác hoặc khóa truy cập bởi Quản trị viên.';
        }
      } else {
        // Bệnh nhân
        final rawStatus = data['trang_thai_id'];
        int statusId = TrangThaiId.hoatDong;
        if (rawStatus is int) {
          statusId = rawStatus;
        } else if (rawStatus is num) {
          statusId = rawStatus.toInt();
        } else if (rawStatus is String) {
          statusId = int.tryParse(rawStatus) ?? TrangThaiId.hoatDong;
        }
        final chanDangNhap = data['chan_dang_nhap'] == true || data['is_blocked'] == true;
        final trangThaiStr = data['trang_thai']?.toString().toLowerCase() ?? '';
        final isKhoa = statusId == TrangThaiId.khongHoatDong ||
            trangThaiStr == 'khoa' ||
            trangThaiStr == 'chan_dang_nhap';
        if (chanDangNhap || isKhoa) {
          shouldKick = true;
          kickReason = data['ly_do_khoa']?.toString() ??
              data['ly_do_chan']?.toString() ??
              'Tài khoản của bạn đã bị quản trị viên khóa.';
        }
      }

      if (shouldKick) {
        await forceSignOut(reason: kickReason);
      }
    });
  }

  /// Buộc đăng xuất ngay lập tức, chuyển về màn hình đăng nhập và cảnh báo
  Future<void> forceSignOut({String? reason}) async {
    _securityWatcherSub?.cancel();
    _securityWatcherSub = null;
    try {
      await _authService.signOut();
    } catch (_) {}
    try {
      await StaffSession.clear();
    } catch (_) {}

    _user = null;
    _hospital = null;
    _admin = null;
    _selectedRole = null;
    notifyListeners();

    // Chuyển hướng người dùng về màn hình đăng nhập
    final nav = AppRoutes.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
    }

    // Hiển thị hộp thoại cảnh báo tài khoản bị khóa
    final ctx = AppRoutes.navigatorKey.currentContext;
    if (ctx != null) {
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_person_rounded, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'Tài khoản bị khóa',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            reason ?? 'Tài khoản của bạn đã bị khóa hoặc ngừng hợp tác bởi Quản trị viên. Phiên làm việc đã bị kết thúc.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _securityWatcherSub?.cancel();
    super.dispose();
  }
}