import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'checkout_screen.dart';
import 'approval_screen.dart';
import 'order_status_screen.dart';  // Added import for OrderStatusScreen

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _isSeller = false;
  String? _sellerId;
  String _errorMessage = '';
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();

        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          setState(() {
            _isSeller = true;
            _sellerId = sellerData['id'];
          });
        }

        if (_isSeller) {
          await _setupSellerNotificationsListener(_sellerId!);
        } else {
          await _setupBuyerNotificationsListener(currentUser.uid);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user info: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setupSellerNotificationsListener(String sellerId) async {
    try {
      _notificationSubscription?.cancel();

      // Modified query to work without the compound index
      final notificationsQuery = _firestore
          .collection('seller_notifications')
          .where('sellerId', isEqualTo: sellerId)
          // Removed the orderBy clause that requires the composite index
          .limit(50);

      // Wrap in try-catch for better error handling during listening
      _notificationSubscription = notificationsQuery.snapshots().listen(
        (snapshot) {
          List<Map<String, dynamic>> notifications = [];
          List<String> unreadNotificationIds = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            notifications.add(data);

            // Track unread notifications for marking as read
            if (data['status'] == 'unread') {
              unreadNotificationIds.add(doc.id);
            }
          }

          // Sort notifications by timestamp locally instead of in the query
          notifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // descending order (newest first)
          });

          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
              _errorMessage = ''; // Clear any previous errors
            });
          }

          if (unreadNotificationIds.isNotEmpty) {
            _markNotificationsAsRead(unreadNotificationIds);
          }
        },
        onError: (error) {
          print('Error in seller notifications listener: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load notifications: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Exception in _setupSellerNotificationsListener: $e');
      setState(() {
        _errorMessage = 'Failed to load notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setupBuyerNotificationsListener(String userId) async {
    try {
      _notificationSubscription?.cancel();

      // Use a try-catch block to handle missing index errors
      try {
        // First attempt with ideal query that might require index
        final ordersQuery = _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(20);
            
        _notificationSubscription = ordersQuery.snapshots().listen(
          _processOrdersSnapshot,
          onError: (error) {
            print('Error in buyer notifications listener (with index): $error');
            
            // If there's an index error, fall back to the simpler query
            if (error.toString().contains('index')) {
              _setupBuyerNotificationsWithoutIndex(userId);
            } else if (mounted) {
              setState(() {
                _errorMessage = 'Failed to load orders: $error';
                _isLoading = false;
              });
            }
          },
        );
      } catch (queryError) {
        // Fall back to simpler query without orderBy
        print('Error setting up buyer notifications: $queryError');
        _setupBuyerNotificationsWithoutIndex(userId);
      }
    } catch (e) {
      print('Exception in _setupBuyerNotificationsListener: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper method for processing order snapshots
  void _processOrdersSnapshot(QuerySnapshot snapshot) {
    List<Map<String, dynamic>> notifications = [];
    
    for (var doc in snapshot.docs) {
      final orderData = doc.data() as Map<String, dynamic>;
      // Handle potential null values more robustly
      final notification = {
        'id': doc.id,
        'type': 'order_status',
        'orderId': doc.id,
        'status': orderData['status'] ?? 'pending',
        'timestamp': orderData['timestamp'] ?? Timestamp.now(),
        'totalAmount': orderData['totalAmount'] ?? 0.0,
        'productName': orderData['productName'] ?? 'Unknown Product',
        'quantity': orderData['quantity'] ?? 1,
        'message': _getStatusMessage(orderData['status'] ?? 'pending'),
        'isRead': true,
      };
      
      notifications.add(notification);
    }
    
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _errorMessage = ''; // Clear any previous errors
      });
    }
  }
  
  // Fallback method when index doesn't exist
  void _setupBuyerNotificationsWithoutIndex(String userId) async {
    try {
      final ordersQuery = _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          // No orderBy clause to avoid index requirements
          .limit(50);
          
      _notificationSubscription = ordersQuery.snapshots().listen(
        (snapshot) {
          List<Map<String, dynamic>> notifications = [];
          
          for (var doc in snapshot.docs) {
            final orderData = doc.data();
            final notification = {
              'id': doc.id,
              'type': 'order_status',
              'orderId': doc.id,
              'status': orderData['status'] ?? 'pending',
              'timestamp': orderData['timestamp'] ?? Timestamp.now(),
              'totalAmount': orderData['totalAmount'] ?? 0.0,
              'productName': orderData['productName'] ?? 'Unknown Product',
              'quantity': orderData['quantity'] ?? 1,
              'message': _getStatusMessage(orderData['status'] ?? 'pending'),
              'isRead': true,
            };
            
            notifications.add(notification);
          }
          
          // Sort notifications by timestamp locally instead of in the query
          notifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // descending order (newest first)
          });
          
          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
              _errorMessage = ''; // Clear any previous errors
            });
          }
        },
        onError: (error) {
          print('Error in buyer notifications listener (without index): $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load orders: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Exception in fallback buyer notifications: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markNotificationsAsRead(List<String> notificationIds) async {
    try {
      if (notificationIds.isEmpty) return;

      final batch = _firestore.batch();

      for (String notificationId in notificationIds) {
        final notificationRef = _firestore
            .collection('seller_notifications')
            .doc(notificationId);
        batch.update(notificationRef, {'status': 'read'});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Your order has been placed and is awaiting confirmation';
      case 'processing':
        return 'Your order is being processed';
      case 'shipped':
        return 'Your order has been shipped';
      case 'delivered':
        return 'Your order has been delivered';
      case 'cancelled':
        return 'Your order has been cancelled';
      default:
        return 'Order status updated';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(timestamp);

      final difference = DateTime.now().difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        final minutes = difference.inMinutes;
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (difference.inDays < 1) {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _getNotificationIcon(String type, String status) {
    IconData iconData;
    Color iconColor;

    if (type == 'new_order') {
      iconData = Icons.shopping_bag;
      iconColor = Colors.green;
    } else if (type == 'new_reservation') {
      iconData = Icons.event;
      iconColor = Colors.blue;
    } else {
      switch (status.toLowerCase()) {
        case 'pending':
          iconData = Icons.hourglass_empty;
          iconColor = Colors.orange;
          break;
        case 'processing':
          iconData = Icons.sync;
          iconColor = Colors.blue;
          break;
        case 'shipped':
          iconData = Icons.local_shipping;
          iconColor = Colors.indigo;
          break;
        case 'delivered':
          iconData = Icons.check_circle;
          iconColor = Colors.green;
          break;
        case 'cancelled':
          iconData = Icons.cancel;
          iconColor = Colors.red;
          break;
        default:
          iconData = Icons.notifications;
          iconColor = Colors.grey;
      }
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      radius: 24,
      child: Icon(iconData, color: iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please log in to view your notifications',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isSeller ? ' Notifications' : 'Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserInfo,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSeller ? 'Seller Notifications' : 'Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSeller
                        ? 'When customers order your products, you\'ll see notifications here'
                        : 'When you place orders, you\'ll see updates here',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadUserInfo(),
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isUnread = _isSeller && notification['status'] == 'unread';
                  final isNewOrder = _isSeller && notification['type'] == 'new_order';
                  final needsApproval = _isSeller && notification['needsApproval'] == true;
                  final isApproved = !_isSeller && notification['status'] == 'approved';
                  final isSellerApproved = _isSeller && notification['type'] == 'order_approved';
                  final isSellerDeclined = _isSeller && notification['type'] == 'order_declined';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: isUnread || isNewOrder || needsApproval || isApproved || isSellerApproved || isSellerDeclined ? 3 : 1,
                    color: needsApproval 
                          ? Colors.amber.shade50
                          : isApproved || isSellerApproved 
                              ? Colors.green.shade50 
                              : isSellerDeclined 
                                  ? Colors.red.shade50
                                  : isNewOrder
                                      ? Colors.orange.shade50
                                      : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isUnread || isNewOrder || needsApproval
                          ? BorderSide(color: needsApproval ? Colors.amber : isNewOrder ? Colors.orange : Colors.green, width: 1)
                          : isApproved || isSellerApproved
                              ? BorderSide(color: Colors.green.shade300, width: 1)
                              : isSellerDeclined
                                  ? BorderSide(color: Colors.red.shade300, width: 1)
                                  : BorderSide.none,
                    ),
                    child: InkWell(
                      onTap: () {
                        if (notification.containsKey('orderId')) {
                          print('Notification tapped: ${notification['type']} - ${notification['status']}');
                          try {
                            if (_isSeller && (notification['type'] == 'new_order' || notification['status'] == 'unread' || notification['status'] == 'pending')) {
                              // For sellers, navigate to the approval screen for new orders
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ApprovalScreen(
                                    orderId: notification['orderId'],
                                    notificationData: notification,
                                  ),
                                ),
                              ).then((result) {
                                // If order was approved or declined, refresh the notifications
                                if (result == 'approved' || result == 'declined') {
                                  _loadUserInfo();
                                }
                              });
                            } else if (_isSeller && (notification['type'] == 'order_approved' || notification['type'] == 'order_declined')) {
                              // For approved/declined orders, navigate to order status screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderStatusScreen(
                                    orderId: notification['orderId'],
                                  ),
                                ),
                              );
                            } else {
                              // For buyers, navigate to the checkout/order details screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    orderId: notification['orderId'],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error navigating to order details screen: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error viewing order details: $e')),
                            );
                          }
                        } else {
                          print('No orderId found in notification: $notification');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _getNotificationIcon(
                              notification['type'] ?? 'order_status',
                              notification['status'] ?? 'pending',
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isUnread)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (isApproved)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
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
                                    ),
                                  if (isSellerApproved)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'YOU APPROVED',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (isSellerDeclined)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'YOU DECLINED',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (isNewOrder)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEW ORDER',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (needsApproval)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEEDS APPROVAL',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    notification['message'] ?? 'Notification',
                                    style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (notification.containsKey('productName'))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Product: ${notification['productName']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  if (notification.containsKey('quantity') &&
                                      notification.containsKey('totalAmount'))
                                    Text(
                                      'Quantity: ${notification['quantity']} — ₱${notification['totalAmount'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTimestamp(notification['timestamp']),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (notification.containsKey('orderId'))
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}