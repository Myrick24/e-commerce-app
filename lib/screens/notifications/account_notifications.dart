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
        List<Map<String, dynamic>> allNotifications = [];
        
        // Get user notifications
        final userNotificationsQuery = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .get();
            
        allNotifications.addAll(userNotificationsQuery.docs.map((doc) {
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
        }));
        
        // Get seller notifications if user is a seller
        try {
          final sellerQuery = await _firestore
              .collection('sellers')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
              
          if (sellerQuery.docs.isNotEmpty) {
            final sellerId = sellerQuery.docs.first.id;
            
            // Fetch seller status notifications
            final sellerNotificationsQuery = await _firestore
                .collection('seller_notifications')
                .where('sellerId', isEqualTo: sellerId)
                .orderBy('timestamp', descending: true)
                .get();
                
            allNotifications.addAll(sellerNotificationsQuery.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'title': data['isApproved'] == true 
                    ? 'Seller Account Approved' 
                    : 'Seller Account Status Update',
                'message': data['message'] ?? '',
                'type': 'seller_status',
                'read': data['status'] == 'read',
                'createdAt': data['timestamp'],
                'isApproved': data['isApproved'],
                'additionalData': {'isApproved': data['isApproved']},
              };
            }));
            
            // Mark seller notifications as read
            final batch = _firestore.batch();
            for (var doc in sellerNotificationsQuery.docs) {
              if (doc.data()['status'] != 'read') {
                batch.update(doc.reference, {'status': 'read'});
              }
            }
            await batch.commit();
          }
        } catch (sellerError) {
          print('Error fetching seller notifications: $sellerError');
        }
          // Sort all notifications by timestamp
        allNotifications.sort((a, b) {
          // Handle different timestamp field names (createdAt or timestamp)
          final aTime = a['createdAt'] as Timestamp? ?? a['timestamp'] as Timestamp?;
          final bTime = b['createdAt'] as Timestamp? ?? b['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order (newest first)
        });
        
        setState(() {
          _notifications = allNotifications;
          _isLoading = false;
        });
        
        // Mark user notifications as read
        final batch = _firestore.batch();
        for (var doc in userNotificationsQuery.docs) {
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
  }    Widget _buildNotificationItem(Map<String, dynamic> notification) {
    IconData iconData;
    Color iconColor;
    Color? cardColor;
    Widget? badge;
    
    switch (notification['type']) {
      case 'seller_approval':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'seller_rejection':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'seller_status':
        // Check if the notification contains isApproved field (direct or in additionalData)
        final isApproved = notification['isApproved'] == true || 
                          notification['additionalData']?['isApproved'] == true;
        if (isApproved) {
          iconData = Icons.verified_user;
          iconColor = Colors.green;
          cardColor = Colors.green.shade50;
          badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'APPROVED',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          );
        } else {
          iconData = Icons.pending;
          iconColor = Colors.amber;
          cardColor = Colors.amber.shade50;
          badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PENDING',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          );
        }
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
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification['type'] == 'seller_status' 
          ? BorderSide(
              color: iconColor.withOpacity(0.5),
              width: 1,
            )
          : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.2),
              child: Icon(iconData, color: iconColor),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    notification['title'],
                    style: TextStyle(
                      fontWeight: notification['read'] ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                if (badge != null) badge,
              ],
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
        ],
      ),
    );
  }
    Widget _buildNotificationList(String type) {
    // Updated filter to handle account-related notifications
    final filteredNotifications = type == 'all'
        ? _notifications
        : type == 'account'
            ? _notifications.where((n) => 
                n['type'] == 'seller_approval' || 
                n['type'] == 'seller_rejection' || 
                n['type'] == 'seller_status').toList()
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
      ),      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList('all'),
                _buildNotificationList('account'),
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
