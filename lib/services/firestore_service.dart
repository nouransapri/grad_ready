import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// إضافة أو تحديث بيانات المستخدم
  Future<void> addUser({
    required String name,
    required int age,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'age': age,
      'createdAt': Timestamp.now(),
    });
  }

  /// جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    return doc.exists ? doc.data() : null;
  }

  /// تحديث بيانات المستخدم
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).update(data);
  }
}