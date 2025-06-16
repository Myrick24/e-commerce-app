import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:e_commerce/services/notification_service.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;
      
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['role'] == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
  // Get all users sorted by ID, then by role (buyers first, then sellers)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('users').get();
      
      // Convert to list and add document ID
      List<Map<String, dynamic>> users = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // First sort by ID
      users.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      
      // Then sort by role (buyers first, then sellers)
      users.sort((a, b) {
        String roleA = a['role'] as String? ?? '';
        String roleB = b['role'] as String? ?? '';
        return roleA.compareTo(roleB);
      });
      
      return users;
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }
  // Get users by role with sorting by ID
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      
      // Convert to list, add ID, then sort by ID
      List<Map<String, dynamic>> users = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort the list by ID
      users.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      
      return users;
    } catch (e) {
      print('Error getting users by role: $e');
      return [];
    }
  }  // Get pending sellers sorted by ID
  Future<List<Map<String, dynamic>>> getPendingSellers() async {
    try {
      // First get all users with role 'seller' and status 'pending'
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Convert to list, add ID, then sort
      List<Map<String, dynamic>> pendingSellers = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by ID
      pendingSellers.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      
      return pendingSellers;
    } catch (e) {
      print('Error getting pending sellers: $e');
      return [];
    }
  }// Approve seller
  Future<bool> approveSeller(String userId) async {
    try {
      // Update the user document
      await _firestore.collection('users').doc(userId).update({
        'status': 'approved',
      });
      
      // Find the associated seller document by getting the user's email first
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? userEmail = userData['email'];
        
        if (userEmail != null) {
          QuerySnapshot sellerQuery = await _firestore
              .collection('sellers')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
              
          if (sellerQuery.docs.isNotEmpty) {
            // Update the seller status to 'approved'
            await _firestore.collection('sellers').doc(sellerQuery.docs.first.id).update({
              'status': 'approved',
            });
            
            // Send notification to the seller
            final notificationService = NotificationService();
            await notificationService.sendNotificationToUser(
              userId: userId,
              title: 'Seller Account Approved!',
              message: 'Congratulations! Your seller account has been approved. You can now add products to sell in our marketplace.',
              type: 'seller_approval',
              additionalData: {
                'status': 'approved',
                'timestamp': FieldValue.serverTimestamp()
              },
            );
          }
        }
      }
      
      return true;
    } catch (e) {
      print('Error approving seller: $e');
      return false;
    }
  }  // Reject seller
  Future<bool> rejectSeller(String userId) async {
    try {
      // Update the user document
      await _firestore.collection('users').doc(userId).update({
        'status': 'rejected',
      });
      
      // Find the associated seller document by getting the user's email first
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? userEmail = userData['email'];
        
        if (userEmail != null) {
          QuerySnapshot sellerQuery = await _firestore
              .collection('sellers')
              .where('email', isEqualTo: userEmail)
              .limit(1)
              .get();
              
          if (sellerQuery.docs.isNotEmpty) {
            // Update the seller status to 'rejected'
            await _firestore.collection('sellers').doc(sellerQuery.docs.first.id).update({
              'status': 'rejected',
            });
            
            // Send notification to the seller
            final notificationService = NotificationService();
            await notificationService.sendNotificationToUser(
              userId: userId,
              title: 'Seller Application Status',
              message: 'Your seller account application has been reviewed. Unfortunately, we are unable to approve it at this time. Please contact support for more information.',
              type: 'seller_rejection',
              additionalData: {
                'status': 'rejected',
                'timestamp': FieldValue.serverTimestamp()
              },
            );
          }
        }
      }
      
      return true;
    } catch (e) {
      print('Error rejecting seller: $e');
      return false;
    }
  }

  // Update user status (active, suspended)
  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
      });
      return true;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }  // Get user stats
  Future<Map<String, int>> getUserStats() async {
    try {
      AggregateQuerySnapshot totalSnapshot = await _firestore.collection('users').count().get();
      AggregateQuerySnapshot approvedSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      
      // Add query for pending sellers
      AggregateQuerySnapshot pendingSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      
      // Handle potentially nullable counts with null-aware operators
      int totalUsers = totalSnapshot.count ?? 0;
      int approvedSellers = approvedSnapshot.count ?? 0;
      int pendingSellers = pendingSnapshot.count ?? 0;
      
      return {
        'totalUsers': totalUsers,
        'approvedSellers': approvedSellers,
        'pendingSellers': pendingSellers,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'totalUsers': 0,
        'approvedSellers': 0,
      };
    }
  }

  // Get weekly user registration activity (for graph)
  Future<Map<String, int>> getWeeklyUserActivity() async {
    try {
      // Get current date
      DateTime now = DateTime.now();
      
      // Create a map to store data for the last 7 days
      Map<String, int> weeklyActivity = {};
      
      // Populate map with last 7 days (including today)
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        String dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        weeklyActivity[dateString] = 0;
      }
        // Query users created in the last 7 days
      DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      String sevenDaysAgoStr = sevenDaysAgo.toIso8601String();
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .get();
          
      // Count users by day
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime? createdAt;
          
          // Handle different timestamp formats
          if (data['createdAt'] is String) {
            try {
              createdAt = DateTime.parse(data['createdAt']);
            } catch (e) {
              print('Error parsing user date string: ${data['createdAt']}');
              continue;
            }
          } else if (data['createdAt'].runtimeType.toString().contains('Timestamp')) {
            // Firestore Timestamp
            createdAt = data['createdAt'].toDate();
          }
          
          if (createdAt != null) {
            String dateString = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
            if (weeklyActivity.containsKey(dateString)) {
              weeklyActivity[dateString] = weeklyActivity[dateString]! + 1;
            }
          }
        }
      }
      
      return weeklyActivity;
    } catch (e) {
      print('Error getting weekly user activity: $e');
      return {};
    }
  }

  // Update user role to seller when they register as a seller
  Future<bool> updateUserToSeller(String userId) async {
    try {
      // Update the user document with seller role and pending status
      await _firestore.collection('users').doc(userId).update({
        'role': 'seller',
        'status': 'pending',
      });
      
      return true;
    } catch (e) {
      print('Error updating user to seller: $e');
      return false;
    }
  }

  // Restore admin account - creates user document for existing Firebase Auth admin
  Future<bool> restoreAdminAccount(String adminEmail, String adminPassword) async {
    try {
      // Sign in with the admin credentials
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Check if user document already exists
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          print('Admin user document already exists');
          return true;
        }

        // Create the admin user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'name': 'Admin',
          'email': adminEmail,
          'role': 'admin',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'isMainAdmin': true, // Flag to identify the main admin
        });

        print('Admin account restored successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('Error restoring admin account: $e');
      return false;
    }
  }

  // Create admin user document for existing auth account by UID
  Future<bool> createAdminUserDocument(String uid, String email, String name) async {
    try {
      // Check if user document already exists
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        print('User document already exists');
        return true;
      }

      // Create the admin user document in Firestore
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'isMainAdmin': true, // Flag to identify the main admin
      });

      print('Admin user document created successfully');
      return true;
    } catch (e) {
      print('Error creating admin user document: $e');
      return false;
    }
  }
}
