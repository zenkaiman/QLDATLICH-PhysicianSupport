import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setDocument(
    String collectionPath,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collectionPath).doc(documentId).set(data);
  }

  Future<void> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collectionPath).add(data);
  }

  Future<Map<String, dynamic>?> getDocument(
    String collectionPath,
    String documentId,
  ) async {
    final snapshot = await _firestore.collection(collectionPath).doc(documentId).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collectionPath,
  ) {
    return _firestore.collection(collectionPath).snapshots();
  }
}
