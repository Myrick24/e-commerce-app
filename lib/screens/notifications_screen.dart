import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/product_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProductService _productService = ProductService();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];
  
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    if (_auth.currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _auth.currentUser!.uid;
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      List<Map<String, dynamic>> notifications = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        notifications.add({
          'id': doc.id,
          ...data,
        });
      }
      
      setState(() {
        _notifications = notifications;
        _markAllAsRead();
      });
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _markAllAsRead() async {
    if (_auth.currentUser == null) return;
    
    try {
      final batch = _firestore.batch();
      final userId = _auth.currentUser!.uid;
      
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }
  
  void _viewProductDetails(String productId) {
    // Navigate to product detail screen
    Navigator.pushNamed(
      context,
      '/product-detail',
      arguments: {'productId': productId},
    );
  }
  
  void _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      setState(() {
        _notifications.removeWhere((notification) => notification['id'] == notificationId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete notification')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              // Confirm delete all notifications
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete All Notifications'),
                  content: const Text('Are you sure you want to delete all notifications?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        
                        try {
                          final userId = _auth.currentUser!.uid;
                          final batch = _firestore.batch();
                          
                          final querySnapshot = await _firestore
                              .collection('notifications')
                              .where('userId', isEqualTo: userId)
                              .get();
                          
                          for (var doc in querySnapshot.docs) {
                            batch.delete(doc.reference);
                          }
                          
                          await batch.commit();
                          
                          setState(() {
                            _notifications = [];
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All notifications deleted')),
                          );
                        } catch (e) {
                          print('Error deleting all notifications: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to delete notifications')),
                          );
                        }
                      },
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationItem(notification);
                    },
                  ),
                ),
    );
  }
  
  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final String title = notification['title'] ?? 'Notification';
    final String message = notification['message'] ?? '';
    final bool isRead = notification['read'] ?? false;
    final String type = notification['type'] ?? '';
    final String productId = notification['productId'] ?? '';
    
    IconData iconData;
    Color iconColor;
    
    switch (type) {
      case 'product_approved':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'product_rejected':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.blue;
    }
    
    return Dismissible(
      key: Key(notification['id']),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteNotification(notification['id']);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        elevation: isRead ? 0 : 1,
        color: isRead ? null : Colors.blue.shade50,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notification['createdAt']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () {
            if (productId.isNotEmpty) {
              _viewProductDetails(productId);
            }
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteNotification(notification['id']),
          ),
        ),
      ),
    );
  }
  
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 7) {
        return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }
}
