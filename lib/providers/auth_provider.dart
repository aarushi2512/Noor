// import 'package:flutter/foundation.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../services/auth_service.dart';

// class AuthProvider extends ChangeNotifier {
//   final AuthService _authService = AuthService();
//   bool _isSignedIn = false;
//   User? _user;

//   // Getters (read-only access for your UI)
//   bool get isSignedIn => _isSignedIn;
//   User? get user => _user;

//   // Constructor: Automatically listens to Firebase auth changes
//   AuthProvider() {
//     _authService.authStateChanges.listen((User? firebaseUser) {
//       _user = firebaseUser;
//       _isSignedIn = firebaseUser != null;
//       notifyListeners(); // Tells UI to rebuild
//     });
//   }

//   // UI-friendly wrappers for AuthService methods
//   Future<String> signIn(String email, String password) async {
//     final result = await _authService.signIn(email: email, password: password);
//     notifyListeners();
//     return result;
//   }

//   Future<String> signUp(String email, String password, String name) async {
//     final result = await _authService.signUp(email: email, password: password, name: name);
//     notifyListeners();
//     return result;
//   }

//   Future<void> signOut() async {
//     await _authService.signOut();
//     // Firebase automatically triggers authStateChanges, so UI updates automatically
//   }

//   Future<String> addContact(String name, String phone, String relationship) async {
//     return await _authService.addTrustedContact(
//       name: name,
//       phone: phone,
//       relationship: relationship,
//     );
//   }
// }


import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isSignedIn = false;
  User? _user;

  // Getters
  bool get isSignedIn => _isSignedIn;
  User? get user => _user;

  // Constructor: Listen to Firebase auth changes
  AuthProvider() {
    _authService.authStateChanges.listen((User? firebaseUser) {
      _user = firebaseUser;
      _isSignedIn = firebaseUser != null;
      notifyListeners();
    });
  }

  // ✅ AUTH METHODS
  Future<String> signIn(String email, String password) async {
    final result = await _authService.signIn(email: email, password: password);
    notifyListeners();
    return result;
  }

  Future<String> signUp(String email, String password, String name) async {
    final result = await _authService.signUp(email: email, password: password, name: name);
    notifyListeners();
    return result;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // ✅ CONTACT METHODS
  
  // Add a new contact to cloud
  Future<String> addContact(String name, String phone, String relationship) async {
    return await _authService.addTrustedContact(
      name: name,
      phone: phone,
      relationship: relationship,
    );
  }

  // Get all contacts from cloud (as Stream)
  Stream<QuerySnapshot> getContacts() {
    return _authService.getContacts();
  }

  // Delete a contact from cloud
  Future<String> deleteContact(String contactId) async {
    return await _authService.deleteContact(contactId);
  }
}