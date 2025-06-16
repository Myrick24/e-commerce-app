import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manual script to restore admin account
/// Run this if you accidentally deleted the admin user document from Firestore
/// 
/// Instructions:
/// 1. Make sure you can still log in with admin@gmail.com / admin123 in Firebase Auth
/// 2. Run this script to recreate the Firestore user document
/// 3. After running, you should be able to access admin features

class ManualAdminRestore {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Restore admin account by signing in and creating Firestore document
  static Future<String> restoreAdminAccount() async {
    try {
      print('🔄 Starting admin account restoration...');
      
      // Step 1: Sign in with admin credentials
      print('📧 Signing in with admin@gmail.com...');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: 'admin@gmail.com',
        password: 'admin123',
      );

      User? user = userCredential.user;
      if (user == null) {
        return '❌ Failed to sign in admin user';
      }

      print('✅ Successfully signed in with UID: ${user.uid}');

      // Step 2: Check if user document already exists
      print('🔍 Checking if Firestore document exists...');
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'unknown';
        return '✅ Admin document already exists!\nUID: ${user.uid}\nRole: $role\nEmail: ${userData['email']}';
      }

      // Step 3: Create the admin user document
      print('📝 Creating admin user document in Firestore...');
      await _firestore.collection('users').doc(user.uid).set({
        'name': 'Admin',
        'email': 'admin@gmail.com',
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'isMainAdmin': true,
        'restoredAt': FieldValue.serverTimestamp(),
      });

      print('🎉 Admin account restored successfully!');
      
      return '''✅ Admin account restored successfully!
      
📋 Details:
• UID: ${user.uid}
• Email: admin@gmail.com
• Role: admin
• Status: active

🚀 You can now:
1. Sign out and sign back in with admin@gmail.com / admin123
2. Access the admin dashboard
3. Manage users, products, and other admin features

💡 Next steps:
- Go to login screen and sign in with admin credentials
- You should be redirected to the admin dashboard automatically''';
      
    } catch (e) {
      String error = e.toString();
      print('❌ Error restoring admin account: $error');
      
      if (error.contains('user-not-found')) {
        return '❌ Admin account not found in Firebase Auth. Please create it first using the Admin Setup Tool.';
      } else if (error.contains('wrong-password')) {
        return '❌ Wrong password. Please verify the admin password is "admin123".';
      } else if (error.contains('permission-denied')) {
        return '❌ Permission denied. Please check your Firestore security rules.';
      }
      
      return '❌ Error: $error';
    }
  }

  /// Get current Firebase Auth admin info (if signed in)
  static Future<String> getCurrentAdminInfo() async {
    try {
      User? currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        return '❌ No user currently signed in';
      }

      print('👤 Current user: ${currentUser.email}');

      // Check Firestore document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return '''✅ Current user info:
• UID: ${currentUser.uid}
• Email: ${currentUser.email}
• Firestore Role: ${userData['role'] ?? 'unknown'}
• Firestore Status: ${userData['status'] ?? 'unknown'}
• Document exists: Yes''';
      } else {
        return '''⚠️ Current user info:
• UID: ${currentUser.uid}
• Email: ${currentUser.email}
• Firestore Document: NOT FOUND
• Action needed: Run restoreAdminAccount()''';
      }
    } catch (e) {
      return '❌ Error getting current user info: ${e.toString()}';
    }
  }

  /// Alternative method: Create admin document by UID (if you know the admin UID)
  static Future<String> createAdminDocumentByUID(String adminUID) async {
    try {
      print('📝 Creating admin document for UID: $adminUID');
      
      // Check if document already exists
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(adminUID).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return '✅ Document already exists for UID: $adminUID\nRole: ${userData['role']}';
      }

      // Create the admin document
      await _firestore.collection('users').doc(adminUID).set({
        'name': 'Admin',
        'email': 'admin@gmail.com',
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'isMainAdmin': true,
        'restoredByUID': true,
      });

      return '✅ Admin document created successfully for UID: $adminUID';
    } catch (e) {
      return '❌ Error creating admin document: ${e.toString()}';
    }
  }
}

/// Quick usage examples:
/// 
/// To restore admin account (most common):
/// String result = await ManualAdminRestore.restoreAdminAccount();
/// print(result);
/// 
/// To check current user info:
/// String info = await ManualAdminRestore.getCurrentAdminInfo();
/// print(info);
/// 
/// To create admin document by UID (if you know the UID):
/// String result = await ManualAdminRestore.createAdminDocumentByUID('your-admin-uid-here');
/// print(result);
