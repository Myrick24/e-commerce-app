import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('products').get();
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting all products: $e');
      return [];
    }
  }

  // Get products by status (pending, approved, rejected)
  Future<List<Map<String, dynamic>>> getProductsByStatus(String status) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: status)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting products by status: $e');
      return [];
    }
  }

  // Get products by seller ID and status (pending, approved, rejected)
  Future<List<Map<String, dynamic>>> getSellerProductsByStatus(String sellerId, String status) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting seller products by status: $e');
      return [];
    }
  }

  // Get all products by seller ID
  Future<List<Map<String, dynamic>>> getAllSellerProducts(String sellerId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting all seller products: $e');
      return [];
    }
  }
  
  // Approve product
  Future<bool> approveProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status': 'approved',
        'approvedAt': DateTime.now().toIso8601String(),
      });
      
      // Create notification for the seller
      final product = await _firestore.collection('products').doc(productId).get();
      if (product.exists) {
        final data = product.data() as Map<String, dynamic>;
        final sellerId = data['sellerId'];
        
        // Add notification
        await _firestore.collection('notifications').add({
          'userId': sellerId,
          'title': 'Product Approved',
          'message': 'Your product "${data['name']}" was approved and is now available for purchase.',
          'type': 'product_approved',
          'productId': productId,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      
      return true;
    } catch (e) {
      print('Error approving product: $e');
      return false;
    }
  }

  // Reject product
  Future<bool> rejectProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status': 'rejected',
      });
      return true;
    } catch (e) {
      print('Error rejecting product: $e');
      return false;
    }
  }

  // Reject product with reason
  Future<bool> rejectProductWithReason(String productId, String reason) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': DateTime.now().toIso8601String(),
      });
      
      // Create notification for the seller
      final product = await _firestore.collection('products').doc(productId).get();
      if (product.exists) {
        final data = product.data() as Map<String, dynamic>;
        final sellerId = data['sellerId'];
        
        // Add notification
        await _firestore.collection('notifications').add({
          'userId': sellerId,
          'title': 'Product Rejected',
          'message': 'Your product "${data['name']}" was rejected. Reason: $reason',
          'type': 'product_rejected',
          'productId': productId,
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      
      return true;
    } catch (e) {
      print('Error rejecting product with reason: $e');
      return false;
    }
  }

  // Get product stats
  Future<Map<String, int>> getProductStats() async {
    try {
      QuerySnapshot allProducts = await _firestore.collection('products').get();
      
      // Fixed the query to properly get count
      AggregateQuerySnapshot activeListingsSnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();
      
      // Handle potentially nullable count with null-aware operator
      int activeListings = activeListingsSnapshot.count ?? 0;
      
      return {
        'totalProducts': allProducts.docs.length,
        'activeListings': activeListings,
      };
    } catch (e) {
      print('Error getting product stats: $e');
      return {
        'totalProducts': 0,
        'activeListings': 0,
      };
    }
  }

  // Get weekly product activity (for graph)
  Future<Map<String, int>> getWeeklyProductActivity() async {
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
        // Query products created in the last 7 days
      DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      String sevenDaysAgoStr = sevenDaysAgo.toIso8601String();
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .get();
          
      // Count products by day
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime? createdAt;
          
          // Handle different timestamp formats
          if (data['createdAt'] is String) {
            try {
              createdAt = DateTime.parse(data['createdAt']);
            } catch (e) {
              print('Error parsing date string: ${data['createdAt']}');
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
      print('Error getting weekly product activity: $e');
      return {};
    }
  }

  // Get unread notification count for user
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }
}
