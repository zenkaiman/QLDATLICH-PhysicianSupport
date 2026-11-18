import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class FirebaseAdminAuthService {
  static final instance = FirebaseAdminAuthService._();
  FirebaseAdminAuthService._();

  Future<Object?> _call(String action, {String? uid, String? email}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return null;
    final project = Firebase.app().options.projectId;
    final response = await http.post(
      Uri.https('us-central1-$project.cloudfunctions.net', '/manageAuthUser'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'data': {'action': action, 'uid': uid, 'email': email}}),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return (jsonDecode(response.body) as Map<String, dynamic>)['result'];
  }

  Future<String?> getUidByEmail(String email) async =>
      (await _call('lookup', email: email)) as String?;

  Future<bool> disableAndRevokeUser({required String uid, String? email}) async =>
      await _call('disable', uid: uid, email: email) == true;

  Future<bool> enableUser({required String uid, String? email}) async =>
      await _call('enable', uid: uid, email: email) == true;

  Future<bool> deleteUser({required String uid, String? email}) async =>
      await _call('delete', uid: uid, email: email) == true;
}
