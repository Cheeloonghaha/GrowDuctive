import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_profile_model.dart';
import '../firebase_options.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Initialize GoogleSignIn with clientId for web platform
  // For web, we need the OAuth 2.0 Client ID from Firebase Console
  // This will be read from the meta tag in index.html, but we can also set it here
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // For web, clientId is read from meta tag, but we can also specify it here
    // Get it from: Firebase Console > Project Settings > Your apps > Web app > OAuth client ID
    // For now, we'll let it use the meta tag approach (recommended for web)
  );
  
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get userId => _currentUser?.uid;

  // Stream for auth state changes - automatically updates when user logs in/out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of current user's profile from Firestore (null when logged out or doc missing).
  Stream<UserProfileModel?> get currentUserProfileStream {
    final uid = _currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfileModel.fromMap(doc.data()!, doc.id);
    });
  }

  AuthViewModel() {
    // Listen to auth state changes and update current user
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  /// Register a new user with email and password.
  /// [username] is required.
  /// Returns null on success, error message on failure.
  /// Do not pass or store password_hash – Firebase Auth handles passwords.
  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final emailTrim = email.trim();
      final usernameTrim = username.trim();

      // Create user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: emailTrim,
        password: password,
      );

      // Set username as display name in Firebase Auth (for consistency)
      await result.user?.updateDisplayName(usernameTrim);
      await result.user?.reload();

      // Create user profile document in Firestore (no password_hash – Auth handles that)
      await _createUserDocument(
        result.user!,
        username: usernameTrim,
      );

      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error [Register]: ${e.code} - ${e.message}");
      return _getAuthErrorMessage(e.code);
    } catch (e) {
      print("General Error [Register]: $e");
      return "An error occurred: ${e.toString()}";
    }
  }

  /// Sign in with email and password
  /// Returns null on success, error message on failure
  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print("Attempting to sign in with email: ${email.trim()}");
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print("Sign in successful! User ID: ${userCredential.user?.uid}");
      
      // Update current user immediately
      _currentUser = userCredential.user;
      notifyListeners();

      // Update last login in Firestore (merge so we don't overwrite profile)
      if (userCredential.user != null) {
        try {
          await _db.collection('users').doc(userCredential.user!.uid).set({
            'email': userCredential.user!.email,
            'last_login_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print("Warning: Could not update user document: $e");
        }
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error [SignIn]: ${e.code} - ${e.message}");
      return _getAuthErrorMessage(e.code);
    } catch (e) {
      print("General Error [SignIn]: $e");
      return "An error occurred: ${e.toString()}";
    }
  }

  /// Sign in with Google
  /// Returns null on success, error message on failure
  Future<String?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null; // Return null to indicate cancellation (not an error)
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      print("Google Sign-In successful! User ID: ${userCredential.user?.uid}");
      
      // Update current user immediately
      _currentUser = userCredential.user;
      notifyListeners();

      // Extract username from Google account
      // Use displayName if available, otherwise use email prefix
      String username = _extractUsernameFromGoogleUser(googleUser);
      
      // Check if user profile already exists
      final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        // New user - create profile document
        await _createUserDocument(
          userCredential.user!,
          username: username,
        );
      } else {
        // Existing user - update last login
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'last_login_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error [Google Sign-In]: ${e.code} - ${e.message}");
      return _getAuthErrorMessage(e.code);
    } catch (e) {
      print("General Error [Google Sign-In]: $e");
      return "Google Sign-In failed: ${e.toString()}";
    }
  }

  /// Extract username from Google user account
  /// Uses displayName if available, otherwise uses email prefix
  String _extractUsernameFromGoogleUser(GoogleSignInAccount googleUser) {
    // Try to use display name first
    if (googleUser.displayName != null && googleUser.displayName!.isNotEmpty) {
      // Remove spaces and convert to lowercase for username
      String username = googleUser.displayName!
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      // Remove any special characters except alphanumeric
      username = username.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (username.length >= 3) {
        return username;
      }
    }
    
    // Fallback to email prefix
    if (googleUser.email.isNotEmpty) {
      String emailPrefix = googleUser.email.split('@')[0];
      // Remove any special characters except alphanumeric
      emailPrefix = emailPrefix.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (emailPrefix.length >= 3) {
        return emailPrefix;
      }
    }
    
    // Final fallback
    return 'user${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  /// Send a password reset email to the given address.
  /// Returns null on success, error message on failure.
  /// Note: Firebase does not reveal whether the email exists (security).
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final emailTrim = email.trim();
      if (emailTrim.isEmpty || !emailTrim.contains('@')) {
        return 'Please enter a valid email address.';
      }
      await _auth.sendPasswordResetEmail(email: emailTrim);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error [Password Reset]: ${e.code} - ${e.message}");
      return _getAuthErrorMessage(e.code);
    } catch (e) {
      print("General Error [Password Reset]: $e");
      return "Could not send reset email: ${e.toString()}";
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Sign out from Google
      await _googleSignIn.signOut();
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  /// Create user profile document in Firestore (id = Auth UID).
  /// No password_hash – Firebase Auth handles passwords.
  Future<void> _createUserDocument(
    User user, {
    required String username,
  }) async {
    try {
      final now = DateTime.now();
      final profile = UserProfileModel(
        id: user.uid,
        email: user.email ?? '',
        username: username,
        profileImageUrl: user.photoURL,
        bio: null,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );
      await _db.collection('users').doc(user.uid).set(profile.toMap());
    } catch (e) {
      print("Error creating user document: $e");
    }
  }

  /// One-time fetch of current user profile (e.g. for profile screen).
  Future<UserProfileModel?> getCurrentUserProfile() async {
    final uid = _currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserProfileModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  /// Update current user's profile in Firestore (only provided fields).
  /// Do not pass password or password_hash. Uses set+merge so doc/fields may be created.
  Future<String?> updateUserProfile({
    String? username,
    String? profileImageUrl,
    String? bio,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) return 'Not logged in';
    try {
      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
        'email': _currentUser!.email,
      };
      if (username != null) {
        updates['username'] = username;
        // Also update Firebase Auth displayName to match username
        await _currentUser!.updateDisplayName(username);
        await _currentUser!.reload();
      }
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (bio != null) updates['bio'] = bio; // use '' to clear

      await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
      return null;
    } catch (e) {
      print("Error updating user profile: $e");
      return e.toString();
    }
  }

  /// Convert Firebase Auth error codes to user-friendly messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/Password authentication is not enabled. Please enable it in Firebase Console.';
      case 'configuration-not-found':
      case 'auth/configuration-not-found':
        return 'Email/Password authentication is not enabled. Please enable it in Firebase Console under Authentication > Sign-in method.';
      default:
        return 'Authentication failed: $code\n\nIf this persists, check Firebase Console > Authentication > Sign-in method and enable Email/Password.';
    }
  }
}
