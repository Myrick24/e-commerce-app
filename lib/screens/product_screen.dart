import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/*
Firestore Collection Structure for Products:

Collection ID: 'products'

Document ID: Generated from timestamp (e.g., '1714923748123')

Fields:
- id (string): Unique product ID (same as document ID)
- sellerId (string): ID of the seller who added the product
- name (string): Product name (e.g., "Organic Red Rice")
- description (string): Detailed product description
- price (number): Product price in Philippine Pesos
- quantity (number): Available quantity
- unit (string): Unit of measurement (e.g., "kg", "g", "piece")
- isOrganic (boolean): Whether the product is organic
- availableDate (timestamp): When the product will be available
- status (string): Current status of the product (default: "available")
- createdAt (timestamp): When the product was added to the system
- category (string): Product category (e.g., "Vegetables", "Fruits")
- allowsReservation (boolean): Whether the product can be reserved
- currentStock (number): Current available stock (may be different from quantity)
- reserved (number): Amount of product currently reserved
*/

class ProductScreen extends StatefulWidget {
  final String? sellerId;
  
  const ProductScreen({Key? key, this.sellerId}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  
  // Form controllers
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _availableDateController = TextEditingController();
  
  // Product category
  String _selectedCategory = 'Vegetables'; // Default category
  final List<String> _categories = ['Fruits', 'Vegetables', 'Grains', 'Dairy', 'Other'];
  
  bool _isOrganic = false;
  bool _allowsReservation = true; // Default to allowing reservations
  bool _isLoading = false;
  DateTime? _selectedDate;
  
  @override
  void initState() {
    super.initState();
    // Set default unit to 'kg'
    _unitController.text = 'kg';
    
    // Set default date to tomorrow
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _updateDateText();
  }
  
  void _updateDateText() {
    if (_selectedDate != null) {
      _availableDateController.text = DateFormat('MM/dd/yyyy').format(_selectedDate!);
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateDateText();
      });
    }
  }
  
  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _availableDateController.dispose();
    super.dispose();
  }
  
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Generate a unique ID for the product
      final String productId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Get seller ID (either passed in or use current user ID)
      final String sellerId = widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      
      // Parse numeric values as doubles
      final double price = double.parse(_priceController.text.trim());
      final double quantity = double.parse(_quantityController.text.trim());
      
      // Create a product document in Firestore
      await _firestore.collection('products').doc(productId).set({
        'id': productId,
        'sellerId': sellerId,
        'name': _productNameController.text.trim(),
        'description': _productDescriptionController.text.trim(),
        'price': price,
        'quantity': quantity,
        'unit': _unitController.text.trim(),
        'isOrganic': _isOrganic,
        'availableDate': _selectedDate!.toIso8601String(), // Store as string
        'status': 'available',
        'createdAt': DateTime.now().toIso8601String(), // Store as string
        'category': _selectedCategory,
        'allowsReservation': _allowsReservation,
        'currentStock': quantity, // Ensure this is a double
        'reserved': 0.0, // Explicitly use 0.0 for double
      }).catchError((error) {
        // Handle Firestore permission error based on the memory
        print('Firestore error: $error');
        throw error;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        
        // Clear form for next product
        _productNameController.clear();
        _productDescriptionController.clear();
        _priceController.clear();
        _quantityController.clear();
        _unitController.text = 'kg';
        _selectedDate = DateTime.now().add(const Duration(days: 1));
        _updateDateText();
        setState(() {
          _isOrganic = false;
          _selectedCategory = 'Vegetables';
          _allowsReservation = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: ${e.toString()}')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Section
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.add_a_photo, size: 40),
                      onPressed: () {
                        // Image upload functionality
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Organic Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _isOrganic,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _isOrganic = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Organic Product',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'In Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Product Name
                TextFormField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name*',
                    hintText: 'e.g., Organic Red Rice',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Product Description
                TextFormField(
                  controller: _productDescriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Product Description*',
                    hintText: 'Describe your product, its benefits, and farming methods',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a product description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'Vegetables';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Category*',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Price and Quantity Row
                Row(
                  children: [
                    // Price
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (₱)*',
                          prefixText: '₱ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Quantity
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Quantity*',
                          suffixText: _unitController.text,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid quantity';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Unit and Available Date Row
                Row(
                  children: [
                    // Unit
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit*',
                          hintText: 'e.g., kg, g, piece',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Available Date
                    Expanded(
                      child: TextFormField(
                        controller: _availableDateController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: const InputDecoration(
                          labelText: 'Available Date*',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Reservation Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _allowsReservation,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() {
                          _allowsReservation = value ?? true;
                        });
                      },
                    ),
                    const Text(
                      'Allow Reservations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Enable this to allow customers to reserve this product before it is available',
                      child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Seller Information Section
                const Text(
                  'Seller Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Seller Card
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('sellers').doc(widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown').get(),
                  builder: (context, snapshot) {
                    // Default values
                    String sellerName = 'Unknown Seller';
                    String sellerLocation = 'Location not available';
                    
                    // If data is available, update with actual values
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      if (userData != null) {
                        sellerName = userData['fullName'] ?? 'Unknown Seller';
                        sellerLocation = userData['location'] ?? 'Location not available';
                      }
                    }
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                                sellerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                sellerLocation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Text('4.8'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                Row(
                  children: [
                    // Quantity Selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            onPressed: () {},
                          ),
                          const Text('1'),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Buy Now / Save Product Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Save Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
