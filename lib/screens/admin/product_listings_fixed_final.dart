import 'package:flutter/material.dart';
import '../../services/product_service.dart';
import './product_card_final_fix.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving product: $e')),
      );
    }
  }

  Future<void> _rejectProduct(String productId) async {
    try {
      bool success = await _productService.rejectProduct(productId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected successfully')),
        );
        
        // Refresh the list
        _loadProductsByTab(_tabController.index);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Products'),
            Tab(text: 'Pending Products'),
            Tab(text: 'Approved Products'),
            Tab(text: 'Rejected Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductList(_allProducts),
          _buildProductList(_pendingProducts),
          _buildProductList(_approvedProducts),
          _buildProductList(_rejectedProducts),
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
          childAspectRatio: 0.45, // Optimized to eliminate overflow completely
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          // Use the fixed card builder to avoid overflow
          return ProductCardFinalFix.buildProductCard(
            context, 
            product, 
            _approveProduct, 
            _rejectProduct, 
            _loadProductsByTab, 
            _tabController
          );
        },
      ),
    );
  }
}
