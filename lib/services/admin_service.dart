import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';
import 'product_service.dart';
import 'transaction_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();

  // Check if user is admin
  Future<bool> isAdmin() async {
    return await _userService.isAdmin();
  }
  // Get dashboard stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      Map<String, int> userStats = await _userService.getUserStats();
      Map<String, int> productStats = await _productService.getProductStats();
      Map<String, int> transactionStats = await _transactionService.getTransactionStats();
      
      return {
        'totalUsers': userStats['totalUsers'],
        'approvedSellers': userStats['approvedSellers'],
        'pendingSellers': userStats['pendingSellers'] ?? 0,
        'activeListings': productStats['activeListings'],
        'completedTransactions': transactionStats['completedTransactions'],
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalUsers': 0,
        'approvedSellers': 0,
        'activeListings': 0,
        'completedTransactions': 0,
      };
    }
  }

  // Get recent activity
  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      // List to store all activities
      List<Map<String, dynamic>> recentActivities = [];
      
      // Get recent user registrations
      QuerySnapshot userRegistrations = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      for (var doc in userRegistrations.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        recentActivities.add({
          'id': doc.id,
          'type': 'user_registration',
          'user': {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'role': data['role'] ?? 'buyer',
          },
          'timestamp': data['createdAt'],
        });
      }
      
      // Get recent seller registrations
      QuerySnapshot sellerRegistrations = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      for (var doc in sellerRegistrations.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        recentActivities.add({
          'id': doc.id,
          'type': 'pending_seller',
          'user': {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
          },
          'timestamp': data['createdAt'],
        });
      }
      
      // Get recent transactions
      QuerySnapshot recentTransactions = await _firestore
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      for (var doc in recentTransactions.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        recentActivities.add({
          'id': doc.id,
          'type': 'transaction',
          'transaction': {
            'id': doc.id,
            'amount': data['amount'] ?? 0,
            'status': data['status'] ?? 'pending',
          },
          'timestamp': data['createdAt'],
        });
      }
      
      // Get recent product listings
      QuerySnapshot recentProducts = await _firestore
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      for (var doc in recentProducts.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        recentActivities.add({
          'id': doc.id,
          'type': 'product_listing',
          'product': {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown product',
            'status': data['status'] ?? 'pending',
          },
          'timestamp': data['createdAt'],
        });
      }
      
      // Sort all activities by timestamp
      recentActivities.sort((a, b) {
        Timestamp timestampA = a['timestamp'] as Timestamp;
        Timestamp timestampB = b['timestamp'] as Timestamp;
        return timestampB.compareTo(timestampA);
      });
      
      // Return most recent 10 activities
      return recentActivities.take(10).toList();
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  // Add a sub-admin user
  Future<bool> addSubAdmin(String email, String password, String name) async {
    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Add user to Firestore with admin role
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'admin',
        'isSubAdmin': true,
        'createdBy': _auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error adding sub-admin: $e');
      return false;
    }
  }

  // Get all admin users
  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
          
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting all admins: $e');
      return [];
    }
  }

  // Remove sub-admin
  Future<bool> removeSubAdmin(String userId) async {
    try {
      // First check if user is a sub-admin to prevent removing main admin
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      if (userData['isSubAdmin'] != true) {
        return false; // Cannot remove main admin
      }
      
      // Update user role to buyer
      await _firestore.collection('users').doc(userId).update({
        'role': 'buyer',
        'isSubAdmin': false,
      });
      
      return true;
    } catch (e) {
      print('Error removing sub-admin: $e');
      return false;
    }
  }
}
