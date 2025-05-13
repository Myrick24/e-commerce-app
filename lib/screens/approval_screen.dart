import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_status_screen.dart';

class ApprovalScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? notificationData;

  const ApprovalScreen({
    Key? key,
    required this.orderId,
    this.notificationData,
  }) : super(key: key);

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isProcessing = false;
  String _errorMessage = '';
  Map<String, dynamic>? _orderData;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(widget.orderId).get();
      
      if (!orderDoc.exists) {
        setState(() {
          _errorMessage = 'Order not found';
          _isLoading = false;
        });
        return;
      }

      // Get the order data first
      final orderData = orderDoc.data() as Map<String, dynamic>;
      orderData['id'] = orderDoc.id;
      
      // Get product image if available
      if (orderData.containsKey('productId')) {
        try {
          final productDoc = await _firestore.collection('products').doc(orderData['productId']).get();
          if (productDoc.exists) {
            final productData = productDoc.data() as Map<String, dynamic>;
            if (productData.containsKey('imageUrl')) {
              orderData['productImage'] = productData['imageUrl'];
            }
          }
        } catch (productError) {
          print('Error fetching product data: $productError');
          // Continue without the product image
        }
      }
      
      // Get comprehensive customer information from the users collection
      if (orderData.containsKey('userId')) {
        try {
          final userDoc = await _firestore.collection('users').doc(orderData['userId']).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            
            // Get all available customer information
            orderData['customerName'] = userData['name'] ?? userData['fullName'] ?? 'Unknown Customer';
            orderData['customerContact'] = userData['phone'] ?? userData['phoneNumber'] ?? userData['contact'] ?? 'No contact info';
            orderData['customerEmail'] = userData['email'] ?? orderData['userEmail'] ?? 'No email provided';
            orderData['customerAddress'] = userData['address'] ?? userData['location'] ?? 'No address provided';
            
            // Try to get additional profile information if available
            if (userData.containsKey('profile')) {
              final profileData = userData['profile'] as Map<String, dynamic>?;
              if (profileData != null) {
                if (!orderData.containsKey('customerAddress') || orderData['customerAddress'] == 'No address provided') {
                  orderData['customerAddress'] = profileData['address'] ?? 'No address provided';
                }
                if (!orderData.containsKey('customerContact') || orderData['customerContact'] == 'No contact info') {
                  orderData['customerContact'] = profileData['phone'] ?? profileData['phoneNumber'] ?? 'No contact info';
                }
              }
            }
          }
        } catch (userError) {
          print('Error fetching user data: $userError');
          // Continue with existing order data even if user fetch fails
        }
      }
      
      setState(() {
        _orderData = orderData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading order details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendApprovalMessage(String customerId, String productName, String sellerId) async {
    try {
      // Check if there's an existing chat between this seller and customer
      final chatQuery = await _firestore.collection('chats')
          .where('sellerId', isEqualTo: sellerId)
          .where('customerId', isEqualTo: customerId)
          .limit(1)
          .get();

      String chatId;
      final timestamp = FieldValue.serverTimestamp();
      final approvalMessage = "Your order for $productName has been approved! Thank you for your purchase.";
      
      if (chatQuery.docs.isEmpty) {
        // Create a new chat if none exists
        final chatRef = _firestore.collection('chats').doc();
        chatId = chatRef.id;
        
        await chatRef.set({
          'sellerId': sellerId,
          'customerId': customerId,
          'createdAt': timestamp,
          'lastMessage': approvalMessage,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': sellerId,
          'unreadCustomerCount': 1,
          'unreadSellerCount': 0,
        });
      } else {
        // Use existing chat
        chatId = chatQuery.docs.first.id;
        
        // Update the existing chat with new message info
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': approvalMessage,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': sellerId,
          'unreadCustomerCount': FieldValue.increment(1),
        });
      }
      
      // Add message to the chat's messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': approvalMessage,
            'senderId': sellerId,
            'timestamp': timestamp,
            'isRead': false,
          });
      
      print('Approval message sent to customer successfully');
    } catch (e) {
      print('Error sending approval message: $e');
      // Don't throw error - this should be considered a non-critical failure
    }
  }

  Future<void> _approveOrder() async {
    if (_orderData == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Update order status
      await _firestore.collection('orders').doc(widget.orderId).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Create notification for the buyer
      await _firestore.collection('notifications').add({
        'userId': _orderData!['userId'],
        'orderId': widget.orderId,
        'type': 'order_status',
        'status': 'approved',
        'message': 'Your order for ${_orderData!['productName']} has been approved',
        'productName': _orderData!['productName'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 3. Create a confirmation notification for the seller
      String? sellerId;
      try {
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          print('Approval: Current user email: ${currentUser.email}');
          
          final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
            
          print('Approval: Seller query completed, found ${sellerQuery.docs.length} sellers');
            
          if (sellerQuery.docs.isNotEmpty) {
            sellerId = sellerQuery.docs.first.data()['id'];
            print('Approval: Found seller ID: $sellerId');
            
            // Create a notification document with specific ID to ensure creation
            final notificationId = 'approved_${DateTime.now().millisecondsSinceEpoch}_${widget.orderId}';
            print('Approval: Creating seller notification with ID: $notificationId');
            
            await _firestore.collection('seller_notifications').doc(notificationId).set({
              'sellerId': sellerId,
              'orderId': widget.orderId,
              'productName': _orderData!['productName'],
              'type': 'order_approved',
              'status': 'confirmed',
              'message': 'You approved order for ${_orderData!['productName']}',
              'quantity': _orderData!['quantity'],
              'totalAmount': _orderData!['totalAmount'] ?? (_orderData!['price'] * _orderData!['quantity']),
              'timestamp': FieldValue.serverTimestamp(),
            });
            
            print('Approval: Seller notification created successfully');
          } else {
            print('Approval: No seller found with email ${currentUser.email}');
          }
        } else {
          print('Approval: No authenticated user found');
        }
      } catch (notifError) {
        print('Approval: Error creating seller notification: $notifError');
        // Continue with the process even if seller notification fails
      }

      // 4. Mark seller notification as processed
      if (widget.notificationData != null && widget.notificationData!.containsKey('id')) {
        await _firestore.collection('seller_notifications').doc(widget.notificationData!['id']).update({
          'status': 'processed',
        });
      }
      
      // 5. Send automatic message to customer about the approval
      if (sellerId != null && _orderData!.containsKey('userId')) {
        await _sendApprovalMessage(
          _orderData!['userId'],
          _orderData!['productName'],
          sellerId
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order approved successfully')),
      );

      // Navigate to order status screen after successful approval
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(orderId: widget.orderId),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to approve order: $e';
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _declineOrder() async {
    if (_orderData == null || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Start a batch write to ensure all operations complete together
      final batch = _firestore.batch();
      
      // 1. Update order status
      final orderRef = _firestore.collection('orders').doc(widget.orderId);
      batch.update(orderRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Return quantity to inventory
      if (_orderData!.containsKey('productId') && _orderData!.containsKey('quantity')) {
        final productRef = _firestore.collection('products').doc(_orderData!['productId']);
        
        // Get current product data to update quantity
        final productDoc = await productRef.get();
        if (productDoc.exists) {
          final currentQuantity = productDoc.data()?['quantity'] ?? 0;
          final orderedQuantity = _orderData!['quantity'];
          
          batch.update(productRef, {
            'quantity': currentQuantity + orderedQuantity,
          });
        }
      }

      // 3. Create notification for the buyer
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': _orderData!['userId'],
        'orderId': widget.orderId,
        'type': 'order_status',
        'status': 'cancelled',
        'message': 'Your order for ${_orderData!['productName']} has been declined',
        'productName': _orderData!['productName'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 4. Create a confirmation notification for the seller
      try {
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          print('Decline: Current user email: ${currentUser.email}');
          
          final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
            
          print('Decline: Seller query completed, found ${sellerQuery.docs.length} sellers');
            
          if (sellerQuery.docs.isNotEmpty) {
            final sellerId = sellerQuery.docs.first.data()['id'];
            print('Decline: Found seller ID: $sellerId');
            
            // Create a notification document with specific ID to ensure creation
            final notificationId = 'declined_${DateTime.now().millisecondsSinceEpoch}_${widget.orderId}';
            print('Decline: Creating seller notification with ID: $notificationId');
            
            // Don't use batch for this critical operation - do it directly
            await _firestore.collection('seller_notifications').doc(notificationId).set({
              'sellerId': sellerId,
              'orderId': widget.orderId,
              'productName': _orderData!['productName'],
              'type': 'order_declined',
              'status': 'confirmed',
              'message': 'You declined order for ${_orderData!['productName']}',
              'quantity': _orderData!['quantity'],
              'totalAmount': _orderData!['totalAmount'] ?? (_orderData!['price'] * _orderData!['quantity']),
              'timestamp': FieldValue.serverTimestamp(),
            });
            
            print('Decline: Seller notification created successfully');
          } else {
            print('Decline: No seller found with email ${currentUser.email}');
          }
        } else {
          print('Decline: No authenticated user found');
        }
      } catch (notifError) {
        print('Decline: Error creating seller notification: $notifError');
        // Continue with the process even if seller notification fails
      }

      // 5. Mark seller notification as processed
      if (widget.notificationData != null && widget.notificationData!.containsKey('id')) {
        final sellerNotificationRef = _firestore.collection('seller_notifications').doc(widget.notificationData!['id']);
        batch.update(sellerNotificationRef, {
          'status': 'processed',
        });
      }

      // Commit all the operations
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order declined and product returned to inventory')),
      );

      // Navigate to order status screen after successful decline
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(orderId: widget.orderId),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to decline order: $e';
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      final DateTime dateTime = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.fromMillisecondsSinceEpoch(timestamp);
          
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Approval'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadOrderDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Summary Card
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Order Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _orderData?['status']?.toUpperCase() ?? 'PENDING',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                ],
                              ),
                              const Divider(),
                              
                              // Order Details
                              const Text(
                                'Order Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Order ID', '#${widget.orderId.substring(0, 8)}'),
                              _buildInfoRow('Date', _formatTimestamp(_orderData?['timestamp'])),
                              
                              const SizedBox(height: 16),
                              
                              // Product Info
                              const Text(
                                'Product',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: _orderData?['productImage'] != null 
                                          ? DecorationImage(
                                              image: NetworkImage(_orderData!['productImage']),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: Colors.grey.shade200,
                                    ),
                                    child: _orderData?['productImage'] == null
                                        ? const Icon(Icons.image_not_supported, color: Colors.grey)
                                        : null,
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Product Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _orderData?['productName'] ?? 'Unknown Product',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Quantity: ${_orderData?['quantity'] ?? 1} ${_orderData?['unit'] ?? ''}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Price: ₱${(_orderData?['price'] ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Customer Info
                              const Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Name', _orderData?['customerName'] ?? 'Unknown'),
                              _buildInfoRow('Contact', _orderData?['customerContact'] ?? 'No contact info'),
                              _buildInfoRow('Email', _orderData?['customerEmail'] ?? _orderData?['userEmail'] ?? 'No email provided'),
                              _buildInfoRow('Address', _orderData?['customerAddress'] ?? 'No address provided'),
                              if (_orderData?['deliveryMethod'] == 'Meet-up' && _orderData?['meetupLocation'] != null)
                                _buildInfoRow('Meet-up Location', _orderData!['meetupLocation']),
                              
                              const SizedBox(height: 16),
                              
                              // Payment Info
                              const Text(
                                'Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Subtotal', '₱${(_orderData?['price'] ?? 0).toStringAsFixed(2)}'),
                              _buildInfoRow('Quantity', '${_orderData?['quantity'] ?? 1}'),
                              _buildInfoRow('Delivery Fee', '₱${(_orderData?['deliveryFee'] ?? 0).toStringAsFixed(2)}'),
                              const Divider(),
                              _buildInfoRow(
                                'Total Amount', 
                                '₱${(_orderData?['totalAmount'] ?? 0).toStringAsFixed(2)}',
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Action Buttons
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _declineOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                      ),
                                    )
                                  : const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _approveOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
  
  // Helper widget for displaying information rows
  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}