import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';
import '../models/user_status.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return AppUser.fromFirestore(doc);
  }

  Stream<AppUser?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    required String organizationId,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = AppUser(
        id: userCredential.user!.uid,
        organizationId: organizationId,
        name: name,
        phone: phone,
        role: role,
        status: UserStatus.offline,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(user.toFirestore());

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final user = currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'status': UserStatus.offline.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserStatus(UserStatus status) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'status': status.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFcmToken(String token) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
