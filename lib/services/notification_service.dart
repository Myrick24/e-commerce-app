import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
}
