import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';

class BuyNowScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;
  
  const BuyNowScreen({
    Key? key,
    required this.product,
    required this.productId,
  }) : super(key: key);

  @override
  State<BuyNowScreen> createState() => _BuyNowScreenState();
}

class _BuyNowScreenState extends State<BuyNowScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  int _quantity = 1;
  bool _isLoading = false;
  String? _selectedDeliveryOption = 'Pick-up';
  String? _selectedPaymentOption = 'Cash on Pick-up';
  
  final List<String> _deliveryOptions = ['Pick-up', 'Meet-up'];
  final List<String> _paymentOptions = ['Cash on Pick-up', 'Cash on Meet-up', 'GCash'];
  
  double _calculateTotal() {
    double price = widget.product['price'] is int 
        ? (widget.product['price'] as int).toDouble() 
        : widget.product['price'] as double;
    return price * _quantity;
  }
  
  void _addToCart() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final cartService = Provider.of<CartService>(context, listen: false);
    
    try {
      // Create cart item
      final cartItem = CartItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        sellerId: widget.product['sellerId'],
        productName: widget.product['name'],
        price: widget.product['price'] is int 
            ? (widget.product['price'] as int).toDouble() 
            : widget.product['price'] as double,
        quantity: _quantity,
        unit: widget.product['unit'] ?? 'piece',
        isReservation: false,
      );
      
      // Add to cart - this will update the database stock
      final success = await cartService.addItem(cartItem);
      
      if (success) {
        // Save to database if user is logged in
        if (_auth.currentUser != null) {
          await cartService.saveCartToDatabase(_auth.currentUser!.uid);
        }
        
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $_quantity ${widget.product['unit']} to cart'),
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough stock available')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _buyNow() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue with purchase')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create cart item
      final cartService = Provider.of<CartService>(context, listen: false);
      final cartItem = CartItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        sellerId: widget.product['sellerId'],
        productName: widget.product['name'],
        price: widget.product['price'] is int 
            ? (widget.product['price'] as int).toDouble() 
            : widget.product['price'] as double,
        quantity: _quantity,
        unit: widget.product['unit'] ?? 'piece',
        isReservation: false,
      );
      
      // Clear cart first so only this item is in cart
      await cartService.clearCart();
      
      // Add to cart - this will update the database stock
      final success = await cartService.addItem(cartItem);
      
      if (success) {
        // Save to database if user is logged in
        if (_auth.currentUser != null) {
          await cartService.saveCartToDatabase(_auth.currentUser!.uid);
        }
        
        // Navigate to cart with checkout option selected
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough stock available')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract product data
    final isOrganic = widget.product['isOrganic'] ?? false;
    final productName = widget.product['name'] ?? 'Product Name';
    final description = widget.product['description'] ?? 'No description available';
    final unit = widget.product['unit'] ?? 'unit';
    final double price = widget.product['price'] is int
        ? (widget.product['price'] as int).toDouble()
        : widget.product['price'] as double;
    
    // Get current stock information
    final double currentStock = widget.product['currentStock'] is int
        ? (widget.product['currentStock'] as int).toDouble()
        : (widget.product['currentStock'] as double? ?? 0.0);
        
    // Set max quantity to available stock
    final int maxQuantity = currentStock.toInt();
    
    // Availability date
    String availableDate = 'Now';
    if (widget.product['availableDate'] != null) {
      try {
        final date = DateTime.parse(widget.product['availableDate']);
        availableDate = DateFormat('MM/dd/yyyy').format(date);
      } catch (e) {
        // Use default
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
              // Show badge if cart has items
              Consumer<CartService>(
                builder: (context, cart, child) {
                if (cart.itemCount == 0) return const SizedBox();
                return Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[200],
              child: Image.asset(
                'assets/images/rice.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.shopping_basket,
                    size: 80,
                    color: isOrganic ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Organic Label
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ORGANIC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Product Description
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quantity and Availability
                  Row(
                    children: [
                      // Weight/Quantity - Updated to show current stock
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            StreamBuilder<DocumentSnapshot>(
                              stream: _firestore.collection('products').doc(widget.productId).snapshots(),
                              builder: (context, snapshot) {
                                // Default to the initial value from the product
                                double stockDisplay = currentStock;
                                
                                // Update with live data if available
                                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                                  if (data != null && data['currentStock'] != null) {
                                    stockDisplay = data['currentStock'] is int
                                        ? (data['currentStock'] as int).toDouble()
                                        : data['currentStock'] as double;
                                  }
                                }
                                
                                return Text(
                                  '${stockDisplay.toStringAsFixed(0)} $unit available',
                                  style: TextStyle(
                                    color: stockDisplay > 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Availability Date
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              availableDate,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Seller Information
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 16,
                        child: Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('sellers').doc(widget.product['sellerId']).get(),
                            builder: (context, snapshot) {
                              String sellerName = 'Seller';
                              String location = 'Location';
                              
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final data = snapshot.data!.data() as Map<String, dynamic>?;
                                if (data != null) {
                                  sellerName = data['fullName'] ?? 'Seller';
                                  location = data['location'] ?? 'Location';
                                }
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sellerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    location,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            '4.8',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const Divider(height: 32),
                  
                  // Order Options
                  const Text(
                    'Order Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quantity Selector
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: _quantity > 1 ? () {
                                setState(() {
                                  _quantity--;
                                });
                              } : null,
                            ),
                            Text(
                              _quantity.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: _quantity < maxQuantity ? () {
                                setState(() {
                                  _quantity++;
                                });
                              } : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Delivery Options
                  const Text(
                    'Delivery Options',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Delivery Radio Buttons
                  ...List.generate(_deliveryOptions.length, (index) {
                    return RadioListTile<String>(
                      title: Text(_deliveryOptions[index]),
                      value: _deliveryOptions[index],
                      groupValue: _selectedDeliveryOption,
                      onChanged: (value) {
                        setState(() {
                          _selectedDeliveryOption = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  
                  // Payment Options
                  const Text(
                    'Payment Options',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Payment Radio Buttons
                  ...List.generate(_paymentOptions.length, (index) {
                    return RadioListTile<String>(
                      title: Text(_paymentOptions[index]),
                      value: _paymentOptions[index],
                      groupValue: _selectedPaymentOption,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentOption = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                  
                  const Divider(height: 32),
                  
                  // Order Summary
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price:'),
                      Text('₱${price.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity:'),
                      Text('$_quantity'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₱${_calculateTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _addToCart,
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Buy Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _buyNow,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Buy Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}