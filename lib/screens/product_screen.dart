import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
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
- imageUrl (string): URL to the product image stored in Firebase Storage
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
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  
  // Form controllers
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _availableDateController = TextEditingController();
  
  // Image file
  File? _imageFile;
  String? _imageUrl;
  bool _isUploading = false;
  double _uploadProgress = 0;
  
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
  
  Future<void> _pickImage() async {
    // Show a modal bottom sheet with options for camera or gallery
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85, // Adjust quality to balance file size and image quality
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: ${e.toString()}')),
      );
    }
  }

  Future<void> _uploadImage({int retryCount = 0}) async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Generate a unique filename
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}';
      final ref = _storage.ref().child('product_images/$fileName');
      
      // Show upload progress in debug console
      // Determine file type based on extension
      String contentType = 'image/jpeg'; // Default
      if (_imageFile!.path.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (_imageFile!.path.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (_imageFile!.path.toLowerCase().endsWith('.webp')) {
        contentType = 'image/webp';
      }
      
      final uploadTask = ref.putFile(
        _imageFile!,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
            'uploadDate': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        setState(() {
          _uploadProgress = progress;
        });
      });
      
      // Wait for the upload to complete with timeout
      await uploadTask.timeout(
        const Duration(seconds: 60), // Set a reasonable timeout
        onTimeout: () {
          throw TimeoutException('Image upload timed out');
        },
      );
      
      // Get download URL
      _imageUrl = await ref.getDownloadURL();
      print('Image uploaded successfully. URL: $_imageUrl');
    } catch (e) {
      print('Error uploading image: $e');
      
      // Try to recover if the error might be temporary (network issues)
      if (retryCount < 2 && (e.toString().contains('network') || 
                            e.toString().contains('timeout') ||
                            e.toString().contains('socket'))) {
        // Wait before retrying
        await Future.delayed(Duration(seconds: 2));
        return _uploadImage(retryCount: retryCount + 1);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed: ${e.toString()}'),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _uploadImage(),
          ),
          duration: Duration(seconds: 10),
        ),
      );
      
      // Set _imageUrl to null so we know upload failed
      _imageUrl = null;
    } finally {
      setState(() {
        _isUploading = false;
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
      // Upload image if available
      if (_imageFile != null) {
        await _uploadImage();
      }

      // Generate a unique ID for the product
      final String productId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Get seller ID (either passed in or use current user ID)
      final String sellerId = widget.sellerId ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      
      // Parse numeric values as doubles
      final double price = double.parse(_priceController.text.trim());
      final double quantity = double.parse(_quantityController.text.trim());
      
      // Calculate 3% commission
      final double totalValue = price * quantity;
      final double commissionRate = 0.03; // 3%
      final double commissionAmount = totalValue * commissionRate;
      
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
        'imageUrl': _imageUrl, // Add image URL
        'commission': commissionAmount, // Add commission amount
      }).catchError((error) {
        // Handle Firestore permission error based on the memory
        print('Firestore error: $error');
        throw error;
      });
      
      // Process the commission
      // First, check if the wallet exists for the user, otherwise create it
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final walletDoc = await _firestore.collection('wallets').doc(user.uid).get();
        
        if (walletDoc.exists) {
          // Update wallet balance
          await _firestore.collection('wallets').doc(user.uid).update({
            'balance': FieldValue.increment(commissionAmount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new wallet
          await _firestore.collection('wallets').doc(user.uid).set({
            'balance': commissionAmount,
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Record the transaction
        await _firestore.collection('walletTransactions').add({
          'userId': user.uid,
          'amount': commissionAmount,
          'productId': productId,
          'productName': _productNameController.text.trim(),
          'description': '3% Commission for product: ${_productNameController.text.trim()}',
          'type': 'commission',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product added successfully! Commission (3%): ₱${commissionAmount.toStringAsFixed(2)}'
            ),
            duration: const Duration(seconds: 4),
          ),
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
          _imageFile = null;
          _imageUrl = null;
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
                  child: _imageFile == null
                      ? Center(
                          child: IconButton(
                            icon: const Icon(Icons.add_a_photo, size: 40),
                            onPressed: _pickImage,
                          ),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _imageFile = null;
                                  });
                                },
                              ),
                            ),
                            // Show upload progress if uploading
                            if (_isUploading)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 5,
                                  child: LinearProgressIndicator(
                                    value: _uploadProgress,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                ),
                              ),
                          ],
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
