import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Initialize authentication (sign in anonymously if not signed in)
  Future<void> initialize() async {
    print('🔐 Initializing authentication...');

    try {
      if (_auth.currentUser == null) {
        print('🔐 No user found, signing in anonymously...');
        final userCredential = await _auth.signInAnonymously();
        print('✅ Anonymous authentication successful: ${userCredential.user?.uid?.substring(0, 8)}');
      } else {
        print('✅ User already authenticated: ${_auth.currentUser?.uid?.substring(0, 8)}');
      }
    } catch (e) {
      print('❌ Authentication failed: $e');
      rethrow;
    }
  }

  /// Sign in anonymously
  Future<UserCredential> signInAnonymously() async {
    try {
      print('🔐 Signing in anonymously...');
      final userCredential = await _auth.signInAnonymously();
      print('✅ Anonymous sign-in successful: ${userCredential.user?.uid?.substring(0, 8)}');
      return userCredential;
    } catch (e) {
      print('❌ Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('🔐 User signed out');
    } catch (e) {
      print('❌ Sign out failed: $e');
      rethrow;
    }
  }

  /// Get current user ID for database operations
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}