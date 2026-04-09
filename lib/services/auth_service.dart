import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // 🔑 Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1️⃣ Get currently logged-in user
  User? get currentUser => _auth.currentUser;

  // 2️⃣ Listen to login/logout changes in real-time
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 3️⃣ SIGN IN
  Future<String> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return 'success';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign in failed';
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // 4️⃣ SIGN UP (Creates account + saves basic profile to cloud)
  Future<String> signUp({
    required String email, 
    required String password, 
    required String name
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // Save user profile to Firestore so we can link contacts to them
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return 'success';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed';
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // 5️⃣ SIGN OUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 6️⃣ ADD TRUSTED CONTACT TO CLOUD
  Future<String> addTrustedContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    try {
      if (_auth.currentUser == null) return 'You must be logged in first';
      
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('trustedContacts')
          .add({
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'addedAt': FieldValue.serverTimestamp(),
      });
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }

  // 7️⃣ GET ALL CONTACTS (Real-time stream)
  Stream<QuerySnapshot> getContacts() {
    if (_auth.currentUser == null) return const Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('trustedContacts')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  // 8️⃣ DELETE CONTACT
  Future<String> deleteContact(String contactId) async {
    try {
      if (_auth.currentUser == null) return 'You must be logged in first';
      
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('trustedContacts')
          .doc(contactId)
          .delete();
      return 'success';
    } catch (e) {
      return e.toString();
    }
  }
}