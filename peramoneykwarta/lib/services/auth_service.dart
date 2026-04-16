import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Helper to get user document reference
  DocumentReference _userDoc(String uid) => _firestore.collection('users').doc(uid);

  // Check if email is already registered (using a collection query)
  Future<bool> isEmailRegisteredInAppDb(String email) async {
    final snap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String name, {
    bool isConductor = false,
    String? conductorLicense,
    String? employeeNumber,
  }) async {
    // 1. Create the Auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(), // Trim and lowercase here too
      password: password.trim(),
    );

    final uid = credential.user!.uid;

    // 2. Initialize the user document with default budget
    await _userDoc(uid).set({
      'userId': uid,
      'email': email.trim().toLowerCase(),
      'username': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'monthlyBudget': 5000.0, // Start them off with a default goal
    });
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}