import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// setDocument: cập nhật giá trị state.
  Future<void> setDocument(
    String collectionPath,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collectionPath).doc(documentId).set(data);
  }

  /// addDocument: thêm dữ liệu vào danh sách hoặc state.
  Future<void> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collectionPath).add(data);
  }

  /// getDocument: lấy dữ liệu.
  Future<Map<String, dynamic>?> getDocument(
    String collectionPath,
    String documentId,
  ) async {
    final snapshot = await _firestore
        .collection(collectionPath)
        .doc(documentId)
        .get();
    return snapshot.exists ? snapshot.data() : null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collectionPath,
  ) {
    return _firestore.collection(collectionPath).snapshots();
  }
}