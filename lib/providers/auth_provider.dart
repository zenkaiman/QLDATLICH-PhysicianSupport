import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  Role? _selectedRole;
  bool _isLoading = false;

  UserModel? get user => _user;
  Role? get selectedRole => _selectedRole;
  bool get isLoading => _isLoading;

  void setSelectedRole(Role role) {
    _selectedRole = role;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required UserModel user,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    _user = null;
    _selectedRole = null;
    notifyListeners();
  }
}
