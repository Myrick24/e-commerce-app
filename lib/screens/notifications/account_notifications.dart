import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AccountNotifications extends StatefulWidget {
  const AccountNotifications({Key? key}) : super(key: key);

  @override
  _AccountNotificationsState createState() => _AccountNotificationsState();
}

class _AccountNotificationsState extends State<AccountNotifications> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get user notifications
        final querySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .get();
            
        setState(() {
          _notifications = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Notification',
              'message': data['message'] ?? '',
              'type': data['type'] ?? 'general',
              'read': data['read'] ?? false,
              'createdAt': data['createdAt'],
              'imageUrl': data['imageUrl'],
              'additionalData': data['additionalData'] ?? {},
            };
          }).toList();
          _isLoading = false;
        });
        
        // Mark all as read
        final batch = _firestore.batch();
        for (var doc in querySnapshot.docs) {
          if (doc.data()['read'] != true) {
            batch.update(doc.reference, {'read': true});
          }
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return 'Unknown date';
    }
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      try {
        dateTime = DateTime.parse(timestamp.toString());
      } catch (e) {
        return 'Invalid date';
      }
    }
    
    return DateFormat('MMM d, y - h:mm a').format(dateTime);
  }
  
  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    IconData iconData;
    Color iconColor;
    
    switch (notification['type']) {
      case 'seller_approval':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'seller_rejection':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'order':
        iconData = Icons.shopping_bag;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: notification['read'] ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification['message']),
            const SizedBox(height: 4),
            Text(
              _formatDate(notification['createdAt']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
  
  Widget _buildNotificationList(String type) {
    final filteredNotifications = type == 'all'
        ? _notifications
        : _notifications.where((n) => n['type'] == type).toList();
    
    if (filteredNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No notifications found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        return _buildNotificationItem(filteredNotifications[index]);
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Account'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList('all'),
                _buildNotificationList('seller_approval'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadNotifications,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
