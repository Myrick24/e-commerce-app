import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_screen.dart';
import 'edit_product_screen.dart'; // Import the new edit product screen

class SellerProductScreen extends StatefulWidget {
  final String? sellerId;
  
  const SellerProductScreen({Key? key, this.sellerId}) : super(key: key);

  @override
  State<SellerProductScreen> createState() => _SellerProductScreenState();
}

class _SellerProductScreenState extends State<SellerProductScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _sellerName;
  
  @override
  void initState() {
    super.initState();
    _getSellerInfo();
  }
  
  Future<void> _getSellerInfo() async {
    if (widget.sellerId != null) {
      try {
        final sellerDoc = await _firestore.collection('sellers').doc(widget.sellerId).get();
        if (sellerDoc.exists) {
          final sellerData = sellerDoc.data();
          if (sellerData != null) {
            setState(() {
              _sellerName = sellerData['fullName'] ?? 'Seller';
            });
          }
        }
      } catch (e) {
        print('Error fetching seller info: $e');
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Products'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductScreen(sellerId: widget.sellerId),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller info header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green.withOpacity(0.1),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sellerName ?? 'Your Store',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'Manage your products',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Products list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('products')
                        .where('sellerId', isEqualTo: widget.sellerId)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        // Extract and show Firestore index creation URL from error
                        String errorMessage = snapshot.error.toString();
                        if (errorMessage.contains('cloud_firestore/failed-precondition') && 
                            errorMessage.contains('https://')) {
                          // Extract the URL
                          final RegExp urlRegex = RegExp(r'https://[^\s]+');
                          final Match? match = urlRegex.firstMatch(errorMessage);
                          if (match != null) {
                            String indexUrl = match.group(0) ?? '';
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'This query requires an index.',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Please create the index in the Firebase console:',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    indexUrl,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      final products = snapshot.data?.docs ?? [];
                      
                      if (products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No products added yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductScreen(sellerId: widget.sellerId),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index].data() as Map<String, dynamic>;
                          final productId = product['id'] as String;
                          
                          double price = 0.0;
                          if (product['price'] != null) {
                            price = product['price'] is int
                                ? (product['price'] as int).toDouble()
                                : product['price'] as double;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),                              leading: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: product['isOrganic'] == true
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  image: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(product['imageUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: product['imageUrl'] == null || product['imageUrl'].toString().isEmpty
                                    ? Icon(
                                        Icons.shopping_basket,
                                        color: product['isOrganic'] == true
                                            ? Colors.green
                                            : Colors.orange,
                                      )
                                    : null,
                              ),
                              title: Text(
                                product['name'] ?? 'Unknown Product',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₱${price.toString()}',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  const SizedBox(height: 4),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            product['category'] ?? 'Other',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: product['allowsReservation'] == true
                                                ? Colors.blue.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            product['allowsReservation'] == true
                                                ? 'Reservable'
                                                : 'No Reservation',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: product['allowsReservation'] == true
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProductScreen(
                                          productId: productId,
                                          sellerId: widget.sellerId,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    // Show confirmation dialog before deleting
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Product'),
                                        content: const Text(
                                            'Are you sure you want to delete this product?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteProduct(productId);
                                            },
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}