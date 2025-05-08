import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String? orderId; // Add orderId parameter
  
  const CheckoutScreen({Key? key, this.orderId}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final List<Map<String, dynamic>> ordersList = [];
        
        // If orderId is provided, only fetch that specific order
        if (widget.orderId != null) {
          final orderDoc = await _firestore
              .collection('orders')
              .doc(widget.orderId)
              .get();
              
          if (orderDoc.exists) {
            final orderData = orderDoc.data() as Map<String, dynamic>;
            orderData['id'] = orderDoc.id; // Make sure ID is included
            ordersList.add(orderData);
            print('Found specific order: ${orderData['id']}, Product: ${orderData['productName']}');
          } else {
            print('Order with ID ${widget.orderId} not found');
          }
        } else {
          // Otherwise, get all orders for current user
          try {
            // Simplified query - removed orderBy to avoid index requirements
            final ordersSnapshot = await _firestore
                .collection('orders')
                .where('userId', isEqualTo: user.uid)
                .get();
                
            // Debug print the count of orders found
            print('Found ${ordersSnapshot.docs.length} orders for user ${user.uid}');
            
            if (ordersSnapshot.docs.isEmpty) {
              print('No orders found for user ${user.uid}');
            }
            
            for (var doc in ordersSnapshot.docs) {
              final orderData = doc.data();
              orderData['id'] = doc.id; // Make sure ID is included
              
              // Debug print each order
              print('Order ID: ${doc.id}, Product: ${orderData['productName']}, Status: ${orderData['status']}');
              
              ordersList.add(orderData);
            }
            
            // Sort locally instead of using orderBy
            ordersList.sort((a, b) {
              var aTime = a['timestamp'] as Timestamp?;
              var bTime = b['timestamp'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime); // descending order
            });
          } catch (queryError) {
            print('Error querying orders: $queryError');
            
            // Check if missing index error
            final errorString = queryError.toString().toLowerCase();
            if (errorString.contains('index') && errorString.contains('missing')) {
              setState(() {
                _errorMessage = 'Firestore index not found. The database is still being set up.';
              });
              
              // Optional: handle missing index - could copy URL from error message
              // and direct user or admin to create the required index
            }
          }
          
          // If no orders were found in 'orders' collection, also check 'reservations' collection
          if (ordersList.isEmpty) {
            try {
              print('Checking reservations collection for user ${user.uid}');
              
              // Simplified query - removed orderBy to avoid index requirements
              final reservationsSnapshot = await _firestore
                  .collection('reservations')
                  .where('userId', isEqualTo: user.uid)
                  .get();
                  
              print('Found ${reservationsSnapshot.docs.length} reservations');
              
              for (var doc in reservationsSnapshot.docs) {
                final reservationData = doc.data();
                reservationData['id'] = doc.id;
                reservationData['isReservation'] = true; // Mark as reservation for UI
                
                print('Reservation ID: ${doc.id}, Product: ${reservationData['productName']}');
                
                ordersList.add(reservationData);
              }
              
              // Sort locally instead of using orderBy
              ordersList.sort((a, b) {
                var aTime = a['timestamp'] as Timestamp?;
                var bTime = b['timestamp'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime); // descending order
              });
            } catch (reservationError) {
              print('Error querying reservations: $reservationError');
            }
          }
        }

        setState(() {
          _orders = ordersList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      // Check if it's a reservation or regular order
      bool isReservation = false;
      for (var order in _orders) {
        if (order['id'] == orderId && order['isReservation'] == true) {
          isReservation = true;
          break;
        }
      }
      
      final collectionName = isReservation ? 'reservations' : 'orders';
      
      await _firestore.collection(collectionName).doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully')),
      );
      
      _loadOrders();  // Refresh the orders
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel order: $e')),
      );
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

  Widget _buildOrderStatusChip(String status) {
    Color chipColor;
    IconData iconData;
    
    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        iconData = Icons.hourglass_empty;
        break;
      case 'processing':
        chipColor = Colors.blue;
        iconData = Icons.sync;
        break;
      case 'shipped':
        chipColor = Colors.indigo;
        iconData = Icons.local_shipping;
        break;
      case 'delivered':
        chipColor = Colors.green;
        iconData = Icons.check_circle;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        iconData = Icons.cancel;
        break;
      default:
        chipColor = Colors.grey;
        iconData = Icons.help_outline;
    }
    
    return Chip(
      avatar: Icon(iconData, color: Colors.white, size: 16),
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh orders',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage.isNotEmpty 
                            ? _errorMessage 
                            : 'No orders found',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                        child: const Text('Shop Now'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final status = order['status'] ?? 'pending';
                    final canCancel = status.toLowerCase() == 'pending';
                    final isReservation = order['isReservation'] == true;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order header
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey, width: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isReservation 
                                      ? 'Reservation #${order['id'].toString().substring(0, 8)}'
                                      : 'Order #${order['id'].toString().substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                _buildOrderStatusChip(status),
                              ],
                            ),
                          ),
                          
                          // Order product
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product Image
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: order['productImage'] != null && order['productImage'].isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(order['productImage']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey.shade200,
                                  ),
                                  child: order['productImage'] == null || order['productImage'].isEmpty
                                      ? const Icon(Icons.image_not_supported, color: Colors.grey)
                                      : null,
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // Product Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order['productName'] ?? 'Unknown Product',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Quantity: ${order['quantity'] ?? 1} ${order['unit'] ?? ''}',
                                        style: TextStyle(color: Colors.grey.shade700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Price: ₱${(order['price'] ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      if (order['deliveryMethod'] == 'Meet-up' && order['meetupLocation'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 14, color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Meet-up at: ${order['meetupLocation']}',
                                                  style: TextStyle(
                                                    color: Colors.orange.shade800,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (isReservation && order['pickupDate'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Pickup on: ${_formatTimestamp(order['pickupDate'])}',
                                            style: TextStyle(
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Ordered on: ${_formatTimestamp(order['timestamp'])}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Order actions
                          if (canCancel)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _cancelOrder(order['id']),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Cancel Order'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
