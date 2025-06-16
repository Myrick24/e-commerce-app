import 'package:flutter/material.dart';
import '../../services/product_service.dart';
import './product_approval_screen_consolidated.dart';

class ProductListings extends StatefulWidget {
  const ProductListings({Key? key}) : super(key: key);

  @override
  State<ProductListings> createState() => _ProductListingsState();
}

class _ProductListingsState extends State<ProductListings> with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _pendingProducts = [];
  List<Map<String, dynamic>> _approvedProducts = [];
  List<Map<String, dynamic>> _rejectedProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _loadProductsByTab(_tabController.index);
    });
    _loadProductsByTab(0); // Load All Products initially
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProductsByTab(int tabIndex) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      switch (tabIndex) {
        case 0: // All Products
          _allProducts = await _productService.getAllProducts();
          break;
        case 1: // Pending Products
          _pendingProducts = await _productService.getProductsByStatus('pending');
          break;
        case 2: // Approved Products
          _approvedProducts = await _productService.getProductsByStatus('approved');
          break;
        case 3: // Rejected Products
          _rejectedProducts = await _productService.getProductsByStatus('rejected');
          break;
      }
    } catch (e) {
      print('Error loading products: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveProduct(String productId) async {
    try {
      bool success = await _productService.approveProduct(productId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product approved successfully')),
        );
        
        // Refresh the list
        _loadProductsByTab(_tabController.index);
      }
    } catch (e) {
      print('Error approving product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve product')),
      );
    }
  }
  Future<void> _rejectProduct(String productId) async {
    try {
      bool success = await _productService.rejectProduct(productId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected')),
        );
        
        // Refresh the list
        _loadProductsByTab(_tabController.index);
      }
    } catch (e) {
      print('Error rejecting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject product')),
      );
    }
  }
  
  Future<void> _rejectProductWithReason(String productId, String reason) async {
    try {
      bool success = await _productService.rejectProductWithReason(productId, reason);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected with reason')),
        );
        
        // Refresh the list
        _loadProductsByTab(_tabController.index);
      }
    } catch (e) {
      print('Error rejecting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject product')),
      );
    }
  }
  void _openProductApprovalScreen(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductApprovalScreenFixed(productId: product['id']),
      ),
    ).then((_) => _loadProductsByTab(_tabController.index));
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
  void _showRejectReasonDialog(String productId) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Rejection'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                _rejectProductWithReason(productId, reasonController.text.trim());
                Navigator.pop(context);
              } else {
                // Show validation error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for rejection')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(_allProducts),
                _buildProductList(_pendingProducts),
                _buildProductList(_approvedProducts),
                _buildProductList(_rejectedProducts),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(8.0),        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // Increased to reduce card height
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          // Product Image - slightly reduced height
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                SizedBox(
                  height: 110, // Slightly reduced height
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
            // Product Info - optimized for space
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product['name'] ?? 'Unnamed Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Price and seller in one row to save space
                Row(
                  children: [
                    // Price with currency
                    Text(
                      '\$${product['price']?.toString() ?? '0.00'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 4),
                    // Seller name
                    Expanded(
                      child: Text(
                        '${product['sellerName'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            // Small spacer to push buttons to the bottom without overflow
          const SizedBox(height: 4),
          
          // Action Buttons - optimized layout
          status == 'pending'
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Combined action row with smaller buttons
                      Row(
                        children: [
                          // View button
                          Expanded(
                            flex: 1,
                            child: IconButton(
                              icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductApprovalScreenFixed(productId: product['id']),
                                  ),
                                ).then((_) => _loadProductsByTab(_tabController.index));
                              },
                              tooltip: 'View Details',
                              padding: EdgeInsets.zero, // Reduce padding to save space
                            ),
                          ),
                          // Approve button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: const Size(0, 32), // Smaller button height
                              ),
                              onPressed: () => _approveProduct(product['id']),
                              child: const Text('Approve', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Reject button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: const Size(0, 32), // Smaller button height
                          ),
                          onPressed: () => _rejectProduct(product['id']),
                          child: const Text('Reject', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductApprovalScreenFixed(productId: product['id']),
                            ),
                          ).then((_) => _loadProductsByTab(_tabController.index));
                        },
                        tooltip: 'View Details',
                        padding: EdgeInsets.zero, // Reduce padding
                      ),
                      if (status == 'rejected')
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _approveProduct(product['id']),
                          tooltip: 'Approve',
                          padding: EdgeInsets.zero, // Reduce padding
                        ),
                      if (status == 'approved')
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _rejectProduct(product['id']),
                          tooltip: 'Reject',
                          padding: EdgeInsets.zero, // Reduce padding
                        ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
