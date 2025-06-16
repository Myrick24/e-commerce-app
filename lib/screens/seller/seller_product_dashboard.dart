import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/product_service.dart';
import '../../widgets/notification_badge.dart';

class SellerProductDashboard extends StatefulWidget {
  const SellerProductDashboard({Key? key}) : super(key: key);

  @override
  State<SellerProductDashboard> createState() => _SellerProductDashboardState();
}

class _SellerProductDashboardState extends State<SellerProductDashboard> with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingProducts = [];
  List<Map<String, dynamic>> _approvedProducts = [];
  List<Map<String, dynamic>> _rejectedProducts = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      _loadProductsByTab(_tabController.index);
    });
    _loadProductsByTab(0); // Load Pending Products initially
    _countUnreadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsByTab(int tabIndex) async {
    if (_auth.currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final sellerId = _auth.currentUser!.uid;
    
    try {
      switch (tabIndex) {
        case 0: // Pending Products
          _pendingProducts = await _productService.getSellerProductsByStatus(sellerId, 'pending');
          break;
        case 1: // Approved Products
          _approvedProducts = await _productService.getSellerProductsByStatus(sellerId, 'approved');
          break;
        case 2: // Rejected Products
          _rejectedProducts = await _productService.getSellerProductsByStatus(sellerId, 'rejected');
          break;
      }
    } catch (e) {
      print('Error loading seller products: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _countUnreadNotifications() async {
    if (_auth.currentUser == null) return;
    
    try {
      final userId = _auth.currentUser!.uid;
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      setState(() {
        _unreadNotifications = querySnapshot.docs.length;
      });
    } catch (e) {
      print('Error counting unread notifications: $e');
    }
  }
  
  void _showProductDetailsModal(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Product Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(product['status'] ?? 'pending'),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Product Image
              if (product['imageUrl'] != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      product['imageUrl'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.image_not_supported, size: 50)),
                        );
                      },
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              Expanded(
                child: ListView(
                  children: [
                    // Product Name
                    _detailRow('Product Name', product['name'] ?? 'Unnamed Product'),
                    const Divider(),
                    
                    // Description
                    _detailRow('Description', product['description'] ?? 'No description available'),
                    const Divider(),
                    
                    // Price and Category
                    Row(
                      children: [
                        Expanded(child: _detailRow('Price', '₱${product['price']?.toString() ?? '0.00'}')),
                        Expanded(child: _detailRow('Category', product['category'] ?? 'Uncategorized')),
                      ],
                    ),
                    const Divider(),
                    
                    // Quantity and Unit
                    Row(
                      children: [
                        Expanded(child: _detailRow('Quantity', '${product['quantity']?.toString() ?? '0'}')),
                        Expanded(child: _detailRow('Unit', product['unit'] ?? '')),
                      ],
                    ),
                    const Divider(),
                    
                    // Organic Badge
                    _detailRow('Organic', (product['isOrganic'] ?? false) ? 'Yes' : 'No'),
                    const Divider(),
                    
                    // Available Date and Reservation
                    Row(
                      children: [
                        Expanded(child: _detailRow('Available Date', product['availableDate'] ?? 'Not specified')),
                        Expanded(child: _detailRow('Allows Reservation', (product['allowsReservation'] ?? false) ? 'Yes' : 'No')),
                      ],
                    ),
                    
                    // Show rejection reason if product was rejected
                    if (product['status'] == 'rejected' && product['rejectionReason'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          _detailRow('Rejection Reason', product['rejectionReason']),
                        ],
                      ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  void _viewNotifications() {
    Navigator.pushNamed(context, '/notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Notification Bell with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _viewNotifications,
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: NotificationBadge(count: _unreadNotifications),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(_pendingProducts),
                _buildProductList(_approvedProducts),
                _buildProductList(_rejectedProducts),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add-product')
              .then((_) => _loadProductsByTab(_tabController.index));
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (products.isEmpty) {
      return const Center(child: Text('No products found'));
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadProductsByTab(_tabController.index),
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    String status = product['status'] ?? 'pending';
    Color statusColor;
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () => _showProductDetailsModal(product),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: product['imageUrl'] != null
                        ? Image.network(
                            product['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Product Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Unnamed Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${product['price']?.toString() ?? '0.00'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['category'] ?? 'Uncategorized',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Status-specific messages
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: status == 'pending'
                ? const Text(
                    'Awaiting approval',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : status == 'rejected'
                  ? const Text(
                      'Tap to view rejection reason',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : const Text(
                      'Available to buyers',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
