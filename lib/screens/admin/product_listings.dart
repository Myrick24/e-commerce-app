import 'package:flutter/material.dart';
import '../../services/product_service.dart';

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

    return Card(
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
                  'Seller: ${product['sellerName'] ?? 'Unknown'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${product['price']?.toString() ?? '0.00'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Action Buttons
          status == 'pending'
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveProduct(product['id']),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectProduct(product['id']),
                      tooltip: 'Reject',
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () {
                        // View product details
                      },
                      tooltip: 'View Details',
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () {
                        // View product details
                      },
                      tooltip: 'View Details',
                    ),
                    if (status == 'rejected')
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _approveProduct(product['id']),
                        tooltip: 'Approve',
                      ),
                    if (status == 'approved')
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _rejectProduct(product['id']),
                        tooltip: 'Reject',
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}
