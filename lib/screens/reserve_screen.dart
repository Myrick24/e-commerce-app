import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import 'cart_screen.dart';

class ReserveScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;
  
  const ReserveScreen({
    Key? key,
    required this.product,
    required this.productId,
  }) : super(key: key);

  @override
  State<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends State<ReserveScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  int _quantity = 1;
  bool _isLoading = false;
  String? _selectedPickupOption = 'On Available Date';
  final List<String> _pickupOptions = ['On Available Date', 'Custom Date'];
  DateTime? _customPickupDate;
  
  double _calculateTotal() {
    double price = widget.product['price'] is int 
        ? (widget.product['price'] as int).toDouble() 
        : widget.product['price'] as double;
    return price * _quantity;
  }
  
  Future<void> _selectCustomDate(BuildContext context) async {
    // Get availableDate from product
    DateTime availableDate = DateTime.now().add(const Duration(days: 1));
    if (widget.product['availableDate'] != null) {
      try {
        availableDate = DateTime.parse(widget.product['availableDate']);
      } catch (e) {
        // Use default
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customPickupDate ?? availableDate,
      firstDate: availableDate, // Can't pick before availability
      lastDate: availableDate.add(const Duration(days: 30)), // Allow up to 30 days after availability
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _customPickupDate = picked;
      });
    }
  }
  
  String _getFormattedDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }
  
  void _addToCart() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart')),
      );
      return;
    }
    
    if (_selectedPickupOption == 'Custom Date' && _customPickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup date')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final cartService = Provider.of<CartService>(context, listen: false);
      
      // Get product available date
      DateTime availableDate = DateTime.now().add(const Duration(days: 1));
      if (widget.product['availableDate'] != null) {
        try {
          availableDate = DateTime.parse(widget.product['availableDate']);
        } catch (e) {
          // Use default
        }
      }
      
      // Determine pickup date based on selection
      DateTime pickupDate = _selectedPickupOption == 'Custom Date' && _customPickupDate != null
          ? _customPickupDate!
          : availableDate;
      
      // Create cart item
      final cartItem = CartItem(
        id: 'reservation_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        sellerId: widget.product['sellerId'],
        productName: widget.product['name'],
        price: widget.product['price'] is int 
            ? (widget.product['price'] as int).toDouble() 
            : widget.product['price'] as double,
        quantity: _quantity,
        unit: widget.product['unit'] ?? 'piece',
        isReservation: true,
        pickupDate: pickupDate,
      );
      
      // Add to cart
      final success = await cartService.addItem(cartItem);
      
      if (success) {
        // Save to database if user is logged in
        if (_auth.currentUser != null) {
          await cartService.saveCartToDatabase(_auth.currentUser!.uid);
        }
        
        // Show confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reserved $_quantity ${widget.product['unit']} to cart'),
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
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot reserve more than available quantity')),
          );
        }
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
  
  Future<void> _reserveNow() async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to continue with reservation')),
      );
      return;
    }
    
    if (_selectedPickupOption == 'Custom Date' && _customPickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup date')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get product available date
      DateTime availableDate = DateTime.now().add(const Duration(days: 1));
      if (widget.product['availableDate'] != null) {
        try {
          availableDate = DateTime.parse(widget.product['availableDate']);
        } catch (e) {
          // Use default
        }
      }
      
      // Determine pickup date based on selection
      DateTime pickupDate = _selectedPickupOption == 'Custom Date' && _customPickupDate != null
          ? _customPickupDate!
          : availableDate;
      
      // Create cart item
      final cartService = Provider.of<CartService>(context, listen: false);
      final cartItem = CartItem(
        id: 'reservation_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        sellerId: widget.product['sellerId'],
        productName: widget.product['name'],
        price: widget.product['price'] is int 
            ? (widget.product['price'] as int).toDouble() 
            : widget.product['price'] as double,
        quantity: _quantity,
        unit: widget.product['unit'] ?? 'piece',
        isReservation: true,
        pickupDate: pickupDate,
      );
      
      // Clear cart first so only this reservation is in cart
      await cartService.clearCart();
      
      // Add to cart
      final success = await cartService.addItem(cartItem);
      
      if (success) {
        // Save to database if user is logged in
        if (_auth.currentUser != null) {
          await cartService.saveCartToDatabase(_auth.currentUser!.uid);
        }
        
        // Navigate to cart for checkout
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot reserve more than available quantity')),
          );
        }
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
    final double quantity = widget.product['quantity'] is int
        ? (widget.product['quantity'] as int).toDouble()
        : widget.product['quantity'] as double;
        
    final double currentReserved = widget.product['reserved'] is int 
        ? (widget.product['reserved'] as int).toDouble() 
        : (widget.product['reserved'] as double? ?? 0.0);
    
    // Calculate available quantity for reservation
    final double availableForReservation = quantity - currentReserved;
    final int maxQuantity = availableForReservation.toInt();
    
    // Availability date
    DateTime availableDate = DateTime.now().add(const Duration(days: 1));
    String availableDateString = 'Tomorrow';
    
    if (widget.product['availableDate'] != null) {
      try {
        availableDate = DateTime.parse(widget.product['availableDate']);
        availableDateString = DateFormat('MM/dd/yyyy').format(availableDate);
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
                      // Weight/Quantity - Updated to show real-time available quantity
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
                                // Default to the initial values from the product
                                double totalQuantity = quantity;
                                double reservedAmount = currentReserved;
                                
                                // Update with live data if available
                                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                                  if (data != null) {
                                    if (data['quantity'] != null) {
                                      totalQuantity = data['quantity'] is int
                                          ? (data['quantity'] as int).toDouble()
                                          : data['quantity'] as double;
                                    }
                                    if (data['reserved'] != null) {
                                      reservedAmount = data['reserved'] is int
                                          ? (data['reserved'] as int).toDouble()
                                          : data['reserved'] as double;
                                    }
                                  }
                                }
                                
                                final availableForReserve = totalQuantity - reservedAmount;
                                
                                return Text(
                                  '${availableForReserve.toStringAsFixed(0)} $unit reservable',
                                  style: TextStyle(
                                    color: availableForReserve > 0 ? Colors.green : Colors.red,
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
                              availableDateString,
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
                  
                  // Reservation Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reservation Notice',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This product will be available on $availableDateString. By reserving, you agree to pick up the product on the selected date.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reservation Options
                  const Text(
                    'Reservation Options',
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
                  
                  // Pickup Date Options
                  const Text(
                    'Pickup Date Options',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Pickup Radio Buttons
                  ...List.generate(_pickupOptions.length, (index) {
                    return RadioListTile<String>(
                      title: Text(_pickupOptions[index]),
                      subtitle: _pickupOptions[index] == 'On Available Date' 
                          ? Text('Pick up on $availableDateString')
                          : (_customPickupDate != null 
                              ? Text('Pick up on ${_getFormattedDate(_customPickupDate!)}')
                              : const Text('Select a custom date')),
                      value: _pickupOptions[index],
                      groupValue: _selectedPickupOption,
                      onChanged: (value) {
                        setState(() {
                          _selectedPickupOption = value;
                          if (value == 'Custom Date') {
                            _selectCustomDate(context);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  
                  if (_selectedPickupOption == 'Custom Date')
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: TextButton.icon(
                        onPressed: () => _selectCustomDate(context),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Change Pickup Date'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                  
                  const Divider(height: 32),
                  
                  // Reservation Summary
                  const Text(
                    'Reservation Summary',
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pickup Date:'),
                      Text(_selectedPickupOption == 'On Available Date' 
                          ? availableDateString 
                          : (_customPickupDate != null 
                              ? _getFormattedDate(_customPickupDate!) 
                              : 'Not selected')),
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
                  
                  // Reserve Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (_selectedPickupOption == 'Custom Date' && _customPickupDate == null) || _isLoading
                          ? null
                          : _reserveNow,
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
                              'Reserve Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _addToCart,
                      child: const Text(
                        'Add to Cart',
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
      
    );
  }
}