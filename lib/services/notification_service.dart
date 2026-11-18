import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';


class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  static const String _colThongBao = 'ThongBao';
  static const String _colDanhSach = 'danh_sach';

  static const String _fieldDaDoc = 'da_doc';

  CollectionReference<Map<String, dynamic>> _list(String benhNhanId) =>
      _firestore
          .collection(_colThongBao)
          .doc(benhNhanId)
          .collection(_colDanhSach);


  List<NotificationModel> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs
        .map((d) => NotificationModel.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }


  Stream<List<NotificationModel>> watchNotifications(String benhNhanId) {
    return _list(benhNhanId).snapshots().map(_parse);
  }


  Future<List<NotificationModel>> getNotifications(String benhNhanId) async {
    try {
      final snap = await _list(benhNhanId).get();
      return _parse(snap);
    } on FirebaseException catch (e) {
      debugPrint('Lỗi Firestore khi tải thông báo [${e.code}]: ${e.message}');
      throw Exception(errorMessage(e));
    }
  }


  Future<void> markAsRead(String benhNhanId, String notificationId) async {
    await _list(benhNhanId).doc(notificationId).set({
      _fieldDaDoc: true,
      'ngay_doc': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  Future<void> markAllAsRead(
    String benhNhanId,
    Iterable<String> notificationIds,
  ) async {
    final ids = notificationIds.toList();
    for (var i = 0; i < ids.length; i += 450) {
      final batch = _firestore.batch();
      for (final id in ids.skip(i).take(450)) {
        batch.set(_list(benhNhanId).doc(id), {
          _fieldDaDoc: true,
          'ngay_doc': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Nội dung lỗi tiếng Việt từ lỗi Firestore.
  static String errorMessage(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Không có quyền đọc thông báo (kiểm tra Firestore Rules).';
        case 'unavailable':
          return 'Mất kết nối mạng. Vui lòng thử lại.';
      }
    }
    return 'Không thể tải thông báo. Vui lòng thử lại.';
  }
}