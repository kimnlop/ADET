// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    _firebaseAuth.setPersistence(Persistence.LOCAL);
  }

  Future<UserCredential> signIn(String email, String password) async {
    UserCredential userCredential = await _firebaseAuth
        .signInWithEmailAndPassword(email: email, password: password);
    bool isDisabled = await isAccountDisabled(userCredential.user!.uid);
    if (isDisabled) {
      throw Exception('Account is disabled.');
    }
    return userCredential;
  }

  Future<UserCredential> signUp(String email, String password) async {
    UserCredential userCredential = await _firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'userName': email.split('@')[0], // Default username based on email
      'role': 0, // Default role is 0 for non-admin
      'isDisabled': false, // Initially set account as not disabled
    });
    return userCredential;
  }

  Future<bool> checkUserExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<bool> isAdmin() async {
    User? user = _firebaseAuth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['role'] == 1;
      }
    }
    return false;
  }

  Future<void> disableAccount(String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isDisabled': true});
  }

  Future<void> enableAccount(String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isDisabled': false});
  }

  Future<bool> isAccountDisabled(String userId) async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists) {
      Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      return data['isDisabled'] ?? false;
    }
    return false; // Default to false if document not found or isDisabled field doesn't exist
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
