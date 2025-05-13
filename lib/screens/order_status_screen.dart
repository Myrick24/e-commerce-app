import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;
  
  const OrderStatusScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  String _errorMessage = '';
  bool _isSeller = false;
  
  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }
  
  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // First check if the current user is a seller
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final sellerQuery = await _firestore
          .collection('sellers')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();
          
        setState(() {
          _isSeller = sellerQuery.docs.isNotEmpty;
        });
      }
      
      // Get the order data
      final orderDoc = await _firestore.collection('orders').doc(widget.orderId).get();
      
      if (!orderDoc.exists) {
        setState(() {
          _errorMessage = 'Order not found';
          _isLoading = false;
        });
        return;
      }
      
      // Get product image if available
      final orderData = orderDoc.data() as Map<String, dynamic>;
      if (orderData.containsKey('productId')) {
        final productDoc = await _firestore.collection('products').doc(orderData['productId']).get();
        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          if (productData.containsKey('imageUrl')) {
            orderData['productImage'] = productData['imageUrl'];
          }
        }
      }
      
      // Get comprehensive customer info if seller is viewing
      if (_isSeller && orderData.containsKey('userId')) {
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
        _errorMessage = 'Error loading order: $e';
        _isLoading = false;
      });
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
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'processing':
        return Icons.sync;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }
  
  Widget _buildStatusStep(String title, String status, bool isActive, bool isCompleted) {
    final color = isCompleted ? Colors.green : (isActive ? _getStatusColor(status) : Colors.grey);
    
    return Expanded(
      child: Column(
        children: [
          // Status circle
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCompleted || isActive ? color : Colors.white,
              border: Border.all(
                color: color,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Icon(
                isCompleted ? Icons.check : _getStatusIcon(status),
                color: isCompleted || isActive ? Colors.white : color,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isCompleted || isActive ? color : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline() {
    if (_orderData == null) return const SizedBox();
    
    final status = _orderData!['status']?.toLowerCase() ?? 'pending';
    
    // Determine which steps are active/completed
    final isPending = true; // Always show first step
    final isApproved = ['approved', 'processing', 'shipped', 'delivered'].contains(status);
    final isProcessing = ['processing', 'shipped', 'delivered'].contains(status);
    final isShipped = ['shipped', 'delivered'].contains(status);
    final isDelivered = ['delivered'].contains(status);
    final isCancelled = ['cancelled'].contains(status);
    
    if (isCancelled) {
      return Column(
        children: [
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Order Cancelled',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      );
    }
    
    return Column(
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              _buildStatusStep('Pending', 'pending', !isApproved && !isCancelled, isApproved),
              _buildDivider(isApproved),
              _buildStatusStep('Approved', 'approved', isApproved && !isProcessing, isProcessing),
              _buildDivider(isProcessing),
              _buildStatusStep('Processing', 'processing', isProcessing && !isShipped, isShipped),
              _buildDivider(isShipped),
              _buildStatusStep('Shipped', 'shipped', isShipped && !isDelivered, isDelivered),
              _buildDivider(isDelivered),
              _buildStatusStep('Delivered', 'delivered', isDelivered, false),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
  
  Widget _buildDivider(bool isActive) {
    return Container(
      height: 2,
      width: 15,
      color: isActive ? Colors.green : Colors.grey.shade300,
    );
  }
  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
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
                        onPressed: _loadOrderData,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Status Card
                      Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID and Date
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${widget.orderId.substring(0, 8)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_orderData?['status'] ?? 'pending'),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (_orderData?['status'] ?? 'PENDING').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ordered on: ${_formatTimestamp(_orderData?['timestamp'])}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              
                              // Order Timeline
                              _buildOrderTimeline(),
                              
                              // Product Details
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
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Product Info
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
                              const Divider(),
                              
                              // Order Details
                              const SizedBox(height: 8),
                              const Text(
                                'Order Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow('Total Amount', '₱${(_orderData?['totalAmount'] ?? 0).toStringAsFixed(2)}', isBold: true),
                              _buildInfoRow('Payment Method', _orderData?['paymentMethod'] ?? 'Cash on Delivery'),
                              _buildInfoRow('Delivery Method', _orderData?['deliveryMethod'] ?? 'Pick-up'),
                              
                              if (_orderData?['deliveryMethod'] == 'Meet-up' && _orderData?['meetupLocation'] != null)
                                _buildInfoRow('Meet-up Location', _orderData!['meetupLocation']),
                                
                              // Only show customer info to sellers
                              if (_isSeller) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Customer Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow('Name', _orderData?['customerName'] ?? 'Unknown'),
                                _buildInfoRow('Contact', _orderData?['customerContact'] ?? 'No contact info'),
                                _buildInfoRow('Email', _orderData?['customerEmail'] ?? _orderData?['userEmail'] ?? 'No email provided'),
                                _buildInfoRow('Address', _orderData?['customerAddress'] ?? 'No address provided'),
                              ],
                              
                              // Show updates log if any
                              if (_orderData != null && _orderData!.containsKey('statusUpdates')) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'Status Updates',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: (_orderData!['statusUpdates'] as List).length,
                                  itemBuilder: (context, index) {
                                    final update = (_orderData!['statusUpdates'] as List)[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(update['status']),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                _getStatusIcon(update['status']),
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  update['status'].toUpperCase(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _formatTimestamp(update['timestamp']),
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (update['note'] != null)
                                                  Text(
                                                    update['note'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Action button for buyers to cancel if the order is still pending
                      if (!_isSeller && (_orderData?['status']?.toLowerCase() == 'pending')) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancel Order'),
                                  content: const Text('Are you sure you want to cancel this order?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Yes'),
                                    ),
                                  ],
                                ),
                              );
                              
                              if (confirm == true) {
                                // Cancel the order
                                try {
                                  await _firestore.collection('orders').doc(widget.orderId).update({
                                    'status': 'cancelled',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  
                                  // Return quantity to inventory
                                  if (_orderData!.containsKey('productId') && _orderData!.containsKey('quantity')) {
                                    await _firestore.collection('products').doc(_orderData!['productId']).update({
                                      'quantity': FieldValue.increment(_orderData!['quantity']),
                                      'currentStock': FieldValue.increment(_orderData!['quantity']),
                                    });
                                  }
                                  
                                  // Reload order data to show updated status
                                  _loadOrderData();
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Order cancelled successfully')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to cancel order: $e')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Cancel Order'),
                          ),
                        ),
                      ],
                      
                      // Contact Seller button for buyers
                      if (!_isSeller && _orderData != null && _orderData!.containsKey('sellerId')) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Contact Seller'),
                            onPressed: () {
                              // Implement chat functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Chat feature coming soon')),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: _orderData != null && _isSeller && (_orderData?['status']?.toLowerCase() == 'approved' ||
                        _orderData?['status']?.toLowerCase() == 'processing')
          ? FloatingActionButton.extended(
              onPressed: () {
                // Show dialog to update order status
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Update Order Status'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.sync, color: Colors.blue),
                          title: const Text('Processing'),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await _firestore.collection('orders').doc(widget.orderId).update({
                                'status': 'processing',
                                'updatedAt': FieldValue.serverTimestamp(),
                                'statusUpdates': FieldValue.arrayUnion([
                                  {
                                    'status': 'processing',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  }
                                ]),
                              });
                              
                              // Create notification for buyer
                              await _firestore.collection('notifications').add({
                                'userId': _orderData!['userId'],
                                'orderId': widget.orderId,
                                'type': 'order_status',
                                'status': 'processing',
                                'message': 'Your order for ${_orderData!['productName']} is now being processed',
                                'productName': _orderData!['productName'],
                                'timestamp': FieldValue.serverTimestamp(),
                                'isRead': false,
                              });
                              
                              _loadOrderData();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update status: $e')),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.local_shipping, color: Colors.indigo),
                          title: const Text('Shipped'),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await _firestore.collection('orders').doc(widget.orderId).update({
                                'status': 'shipped',
                                'updatedAt': FieldValue.serverTimestamp(),
                                'statusUpdates': FieldValue.arrayUnion([
                                  {
                                    'status': 'shipped',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  }
                                ]),
                              });
                              
                              // Create notification for buyer
                              await _firestore.collection('notifications').add({
                                'userId': _orderData!['userId'],
                                'orderId': widget.orderId,
                                'type': 'order_status',
                                'status': 'shipped',
                                'message': 'Your order for ${_orderData!['productName']} has been shipped',
                                'productName': _orderData!['productName'],
                                'timestamp': FieldValue.serverTimestamp(),
                                'isRead': false,
                              });
                              
                              _loadOrderData();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update status: $e')),
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.done_all, color: Colors.teal),
                          title: const Text('Delivered'),
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await _firestore.collection('orders').doc(widget.orderId).update({
                                'status': 'delivered',
                                'updatedAt': FieldValue.serverTimestamp(),
                                'statusUpdates': FieldValue.arrayUnion([
                                  {
                                    'status': 'delivered',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  }
                                ]),
                              });
                              
                              // Create notification for buyer
                              await _firestore.collection('notifications').add({
                                'userId': _orderData!['userId'],
                                'orderId': widget.orderId,
                                'type': 'order_status',
                                'status': 'delivered',
                                'message': 'Your order for ${_orderData!['productName']} has been delivered',
                                'productName': _orderData!['productName'],
                                'timestamp': FieldValue.serverTimestamp(),
                                'isRead': false,
                              });
                              
                              _loadOrderData();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update status: $e')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.update),
              label: const Text('Update Status'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }
}