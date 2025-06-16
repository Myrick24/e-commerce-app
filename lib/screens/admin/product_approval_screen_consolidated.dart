//
// This file is a consolidation of three previously separate product approval screens:
// - product_approval_screen.dart
// - product_approval_screen_new.dart
// - product_approval_screen_fixed.dart
//
// All functionality has been merged into the ProductApprovalScreenNew class as the main implementation,
// while ProductApprovalScreen and ProductApprovalScreenFixed are kept as compatibility classes
// to maintain backward compatibility with existing code.
//
// Last consolidated: May 18, 2025
//

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/product_service.dart';

// Main class used by all card components
class ProductApprovalScreenNew extends StatefulWidget {
  final String productId;
  
  const ProductApprovalScreenNew({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductApprovalScreenNew> createState() => _ProductApprovalScreenNewState();
}

class _ProductApprovalScreenNewState extends State<ProductApprovalScreenNew> {
  final ProductService _productService = ProductService();
  bool _isLoading = true;
  Map<String, dynamic>? _product;
  
  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }
  
  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get product document
      DocumentSnapshot productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();
          
      if (productDoc.exists) {
        setState(() {
          _product = productDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        // Handle product not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error loading product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Review'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Review'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: Text('Product not found')),
      );
    }
    
    String status = _product!['status'] ?? 'pending';
    Color statusColor;
    
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Review'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'approved'
                      ? Icons.check_circle
                      : status == 'rejected'
                          ? Icons.cancel
                          : Icons.pending,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            if (_product!['imageUrl'] != null)
              SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  _product!['imageUrl'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, size: 80),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Product Details
            _buildProductDetailsSection(),
            
            const SizedBox(height: 16),
            
            // Product Description
            _buildDescriptionSection(),
            
            const SizedBox(height: 16),
            
            // Additional Info Card
            _buildAdditionalInfoSection(),
            
            const SizedBox(height: 16),
            
            // Seller Info Card
            _buildSellerInfoSection(),
            
            // Rejection Reason Card (if applicable)
            if (status == 'rejected' && _product!['rejectionReason'] != null)
              _buildRejectionReasonSection(),
            
            const SizedBox(height: 24),
            
            // Action Buttons for Pending Products
            if (status == 'pending')
              _buildActionButtonsSection(),
              
            // Extra padding at the bottom with safe area to prevent overflow
            SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailsSection() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
        minHeight: 130,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Divider(),
              _buildDetailRow('Product Name', _product!['name'] ?? 'N/A'),
              _buildDetailRow('Price', '\$${_product!['price']?.toString() ?? 'N/A'}'),
              _buildDetailRow('Category', _product!['category'] ?? 'N/A'),
              _buildDetailRow('Quantity', '${_product!['quantity'] ?? 'N/A'}'),
              _buildDetailRow('Date Added', _product!['createdAt'] != null
                  ? _formatDate(_product!['createdAt'])
                  : 'N/A'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
        minHeight: 100,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Divider(),
              Text(
                _product!['description'] ?? 'No description provided',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 180,
        maxWidth: MediaQuery.of(context).size.width * 0.95,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Additional Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Divider(),
              // Add any additional specifications or details here
              _buildDetailRow('Brand', _product!['brand'] ?? 'N/A'),
              _buildDetailRow('Condition', _product!['condition'] ?? 'N/A'),
              _buildDetailRow('SKU', _product!['sku'] ?? 'N/A'),
              _buildDetailRow('Weight', _product!['weight'] != null
                  ? '${_product!['weight']} kg'
                  : 'N/A'),
              _buildDetailRow('Dimensions', _product!['dimensions'] ?? 'N/A'),
              _buildDetailRow('Shipping Method', _product!['shippingMethod'] ?? 'N/A'),
              _buildDetailRow('Shipping Cost', _product!['shippingCost'] != null
                  ? '\$${_product!['shippingCost']}'
                  : 'N/A'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerInfoSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('sellers')
          .doc(_product!['sellerId'])
          .get(),
      builder: (context, snapshot) {
        String sellerName = 'Unknown Seller';
        String sellerLocation = 'Location not available';
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          Map<String, dynamic> sellerData = snapshot.data!.data() as Map<String, dynamic>;
          sellerName = sellerData['name'] ?? sellerName;
          sellerLocation = sellerData['location'] ?? sellerLocation;
        }
        
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
            minHeight: 120,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Seller Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildDetailRow('Seller Name', sellerName),
                  _buildDetailRow('Location', sellerLocation),
                  _buildDetailRow('Seller ID', _product!['sellerId'] ?? 'N/A'),
                  
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRejectionReasonSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Card(
          elevation: 2,
          color: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Rejection Reason',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.red),
                Text(
                  _product!['rejectionReason'] ?? 'No reason provided',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.95,
        minHeight: 100,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        elevation: 3,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Review Decision',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _showRejectDialog,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _approveProduct,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'N/A';
      
      if (dateValue is Timestamp) {
        DateTime dateTime = dateValue.toDate();
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      } else if (dateValue is DateTime) {
        return '${dateValue.year}-${dateValue.month.toString().padLeft(2, '0')}-${dateValue.day.toString().padLeft(2, '0')}';
      } else if (dateValue is String) {
        try {
          DateTime dateTime = DateTime.parse(dateValue);
          return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
        } catch (e) {
          return dateValue;
        }
      }
      return dateValue.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _approveProduct() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      bool success = await _productService.approveProduct(widget.productId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product approved successfully')),
        );
        
        // Refresh product details
        _loadProductDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve product: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for rejection')),
                );
                return;
              }
              Navigator.pop(context);
              _rejectProductWithReason(reasonController.text.trim());
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectProductWithReason(String reason) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      bool success = await _productService.rejectProductWithReason(widget.productId, reason);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product rejected successfully')),
        );
        
        // Refresh product details
        _loadProductDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject product: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// For backward compatibility
class ProductApprovalScreen extends ProductApprovalScreenNew {
  const ProductApprovalScreen({Key? key, required String productId})
      : super(key: key, productId: productId);
}

// For backward compatibility
class ProductApprovalScreenFixed extends ProductApprovalScreenNew {
  const ProductApprovalScreenFixed({Key? key, required String productId})
      : super(key: key, productId: productId);
}
