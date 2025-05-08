import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final String? sellerId;
  
  const EditProductScreen({
    Key? key, 
    required this.productId,
    this.sellerId,
  }) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
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
  String _selectedCategory = 'Vegetables';
  final List<String> _categories = ['Fruits', 'Vegetables', 'Grains', 'Dairy', 'Other'];
  
  bool _isOrganic = false;
  bool _allowsReservation = true;
  bool _isLoading = true;
  bool _isUpdating = false;
  DateTime? _selectedDate;
  double _reserved = 0.0;
  String? _createdAt;
  
  @override
  void initState() {
    super.initState();
    _loadProductData();
  }
  
  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final DocumentSnapshot productDoc = 
          await _firestore.collection('products').doc(widget.productId).get();
          
      if (productDoc.exists) {
        final data = productDoc.data() as Map<String, dynamic>;
        
        // Populate form fields with existing data
        _productNameController.text = data['name'] ?? '';
        _productDescriptionController.text = data['description'] ?? '';
        
        // Handle numeric fields
        if (data['price'] != null) {
          final double price = data['price'] is int 
              ? (data['price'] as int).toDouble() 
              : data['price'] as double;
          _priceController.text = price.toString();
        }
        
        if (data['quantity'] != null) {
          final double quantity = data['quantity'] is int 
              ? (data['quantity'] as int).toDouble() 
              : data['quantity'] as double;
          _quantityController.text = quantity.toString();
        }
        
        _unitController.text = data['unit'] ?? 'kg';
        
        // Handle date
        if (data['availableDate'] != null) {
          try {
            _selectedDate = DateTime.parse(data['availableDate']);
            _updateDateText();
          } catch (e) {
            _selectedDate = DateTime.now().add(const Duration(days: 1));
            _updateDateText();
          }
        }
        
        // Handle category
        if (data['category'] != null && _categories.contains(data['category'])) {
          _selectedCategory = data['category'];
        }
        
        // Handle boolean fields
        _isOrganic = data['isOrganic'] ?? false;
        _allowsReservation = data['allowsReservation'] ?? true;
        
        // Store additional fields for update
        if (data['reserved'] != null) {
          _reserved = data['reserved'] is int 
              ? (data['reserved'] as int).toDouble() 
              : data['reserved'] as double;
        }
        
        _createdAt = data['createdAt'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product: ${e.toString()}')),
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
  
  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      // Parse numeric values as doubles
      final double price = double.parse(_priceController.text.trim());
      final double quantity = double.parse(_quantityController.text.trim());
      
      // Update existing product in Firestore
      await _firestore.collection('products').doc(widget.productId).update({
        'name': _productNameController.text.trim(),
        'description': _productDescriptionController.text.trim(),
        'price': price,
        'quantity': quantity,
        'unit': _unitController.text.trim(),
        'isOrganic': _isOrganic,
        'availableDate': _selectedDate!.toIso8601String(),
        'category': _selectedCategory,
        'allowsReservation': _allowsReservation,
        'currentStock': quantity, // Updating with new quantity value
        'reserved': _reserved,
        'createdAt': _createdAt,
        'lastUpdated': DateTime.now().toIso8601String(), // Add last updated timestamp
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
        Navigator.pop(context); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update product: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Product'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                        'Edit Mode',
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
                
                const SizedBox(height: 32),
                
                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Update Product',
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
        ),
      ),
    );
  }
}