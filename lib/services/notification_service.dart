import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // Key constants for shared preferences
  static const String _notificationShownKey = 'seller_notification_shown_';

  // Check if notification has been shown for the current user
  static Future<bool> hasShownNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      
      if (userId == null) return false;
      return prefs.getBool('$_notificationShownKey$userId') ?? false;
    } catch (e) {
      print('Error checking if notification has been shown: $e');
      return false;
    }
  }

  // Mark notification as shown
  static Future<void> markNotificationAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        await prefs.setBool('$_notificationShownKey$userId', true);
      }
    } catch (e) {
      print('Error marking notification as shown: $e');
    }
  }
  // Reset notification state
  static Future<void> resetNotificationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        await prefs.setBool('$_notificationShownKey$userId', false);
      }
    } catch (e) {
      print('Error resetting notification state: $e');
    }
  }
  
  // Mark specific notification as shown - for tracking different types of notifications
  static Future<void> markSpecificNotificationAsShown(String notificationType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        final specificKey = '${_notificationShownKey}${userId}_$notificationType';
        await prefs.setBool(specificKey, true);
      }
    } catch (e) {
      print('Error marking specific notification as shown: $e');
    }
  }
  
  // Check if specific notification has been shown
  static Future<bool> hasShownSpecificNotification(String notificationType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _auth.currentUser?.uid;
      
      if (userId == null) return false;
      final specificKey = '${_notificationShownKey}${userId}_$notificationType';
      return prefs.getBool(specificKey) ?? false;
    } catch (e) {
      print('Error checking if specific notification has been shown: $e');
      return false;
    }
  }

  // Send an announcement to all users
  Future<bool> sendAnnouncement({
    required String title,
    required String message,
    String? imageUrl,
  }) async {
    try {
      // Create announcement document
      await _firestore.collection('announcements').add({
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Get all user IDs to create individual notifications
      QuerySnapshot userSnapshot = await _firestore.collection('users').get();
      List<String> userIds = userSnapshot.docs.map((doc) => doc.id).toList();
      
      // Create batch for efficiency
      WriteBatch batch = _firestore.batch();
      
      // Add notification for each user
      for (String userId in userIds) {
        DocumentReference notificationRef = _firestore.collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();
            
        batch.set(notificationRef, {
          'title': title,
          'message': message,
          'imageUrl': imageUrl,
          'type': 'announcement',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Commit batch
      await batch.commit();
      return true;
    } catch (e) {
      print('Error sending announcement: $e');
      return false;
    }
  }

  // Send notification to specific user
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? imageUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      });
      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Get all announcements
  Future<List<Map<String, dynamic>>> getAllAnnouncements() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .get();
          
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting announcements: $e');
      return [];
    }
  }

  // Get user support messages
  Future<List<Map<String, dynamic>>> getSupportMessages() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('support_messages')
          .orderBy('createdAt', descending: true)
          .get();
          
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting support messages: $e');
      return [];
    }
  }

  // Reply to a support message
  Future<bool> replySupportMessage({
    required String messageId,
    required String reply,
  }) async {
    try {
      // Update the support message with the reply
      await _firestore.collection('support_messages').doc(messageId).update({
        'adminReply': reply,
        'status': 'replied',
        'repliedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the user ID to notify them
      DocumentSnapshot docSnapshot = await _firestore
          .collection('support_messages')
          .doc(messageId)
          .get();
          
      String userId = (docSnapshot.data() as Map<String, dynamic>)['userId'];
      String subject = (docSnapshot.data() as Map<String, dynamic>)['subject'];
      
      // Send notification to user
      await sendNotificationToUser(
        userId: userId,
        title: 'Support reply: $subject',
        message: 'Your support inquiry has been answered. Check your messages for the reply.',
        type: 'support_reply',
        additionalData: {
          'supportMessageId': messageId,
        },
      );
      
      return true;
    } catch (e) {
      print('Error replying to support message: $e');
      return false;
    }
  }

  // Add seller status notification
  static Future<void> addSellerStatusNotification({
    required String sellerId,
    required bool isApproved,
    required String message,
  }) async {
    try {
      // First check if there's a recent notification (within the last two hours) with the same status
      QuerySnapshot? recentNotifications;
      
      try {
        recentNotifications = await _firestore
            .collection('seller_notifications')
            .where('sellerId', isEqualTo: sellerId)
            .where('type', isEqualTo: 'seller_status')
            .where('isApproved', isEqualTo: isApproved)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
      } catch (indexError) {
        // Fallback if the composite index doesn't exist
        final allNotifications = await _firestore
            .collection('seller_notifications')
            .where('sellerId', isEqualTo: sellerId)
            .get();              // Filter the notifications manually
        final filteredDocs = allNotifications.docs.where((doc) {
          final data = doc.data();
          return data['type'] == 'seller_status' && 
                 data['isApproved'] == isApproved;
        }).toList();
        
        if (filteredDocs.isNotEmpty) {
          // Sort by timestamp manually
          filteredDocs.sort((a, b) {
            final aTimestamp = a['timestamp'] as Timestamp?;
            final bTimestamp = b['timestamp'] as Timestamp?;
            
            if (aTimestamp == null || bTimestamp == null) return 0;
            return bTimestamp.compareTo(aTimestamp);
          });
          
          // Check the most recent notification
          final latestDoc = filteredDocs.first;
          final timestamp = latestDoc['timestamp'] as Timestamp?;
          
          if (timestamp != null) {
            final notificationTime = timestamp.toDate();
            final timeSinceNotification = DateTime.now().difference(notificationTime);
            
            // If we already have a notification that's less than 2 hours old
            if (timeSinceNotification.inHours < 2) {
              // Update it to be unread again
              await _firestore
                  .collection('seller_notifications')
                  .doc(latestDoc.id)
                  .update({'status': 'unread'});
                  
              print('Recent notification exists, marked as unread');
              return;
            }
          }
        }
      }
        // Check if we found a recent notification with composite index
      if (recentNotifications != null && recentNotifications.docs.isNotEmpty) {        final latestNotification = recentNotifications.docs.first;
        final data = latestNotification.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        
        // If the notification is less than two hours old, don't create a new one
        if (timestamp != null) {
          final notificationTime = timestamp.toDate();
          final timeSinceNotification = DateTime.now().difference(notificationTime);
          
          if (timeSinceNotification.inHours < 2) {
            print('Recent notification exists. Updating status.');
            
            // Update existing notification to ensure it's marked unread
            await _firestore
                .collection('seller_notifications')
                .doc(latestNotification.id)
                .update({'status': 'unread'});
                
            return;
          }
        }
      }
      
      // Create a new notification
      final timestamp = FieldValue.serverTimestamp();
      final notificationId = 'seller_status_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('seller_notifications').doc(notificationId).set({
        'id': notificationId,
        'sellerId': sellerId,
        'type': 'seller_status',
        'status': 'unread',
        'timestamp': timestamp,
        'message': message,
        'isApproved': isApproved,
      });
      
      print('Seller status notification added successfully');
        // Mark notification as shown for the user based on the status
      // Each status type gets its own flag to prevent showing duplicates
      final statusKey = isApproved ? 'approved' : 'changed';
      await markSpecificNotificationAsShown('seller_status_$statusKey');
    } catch (e) {
      print('Error adding seller status notification: $e');
    }
  }
}
