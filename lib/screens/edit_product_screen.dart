import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final _storage = FirebaseStorage.instance;
  final _imagePicker = ImagePicker();
  
  // Form controllers
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _availableDateController = TextEditingController();
  
  // Image handling
  File? _imageFile;
  String? _imageUrl;
  bool _isImageChanged = false;
  
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
        
        // Get image URL if it exists
        _imageUrl = data['imageUrl'];
        
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
          _isImageChanged = true;
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
      _isUpdating = true;
    });

    try {
      // Generate a unique filename that includes the product ID
      final fileName = 'product_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = _storage.ref().child('product_images/$fileName');
      
      // Show upload progress in debug console
      final uploadTask = ref.putFile(
        _imageFile!,
        SettableMetadata(
          contentType: 'image/jpeg', // Assuming JPEG for simplicity
          customMetadata: {
            'productId': widget.productId,
            'uploadDate': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
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
      
      // Try to recover if the error might be temporary
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
        _isUpdating = false;
      });
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
      // Upload new image if selected
      if (_isImageChanged && _imageFile != null) {
        await _uploadImage();
      }

      // Parse numeric values as doubles
      final double price = double.parse(_priceController.text.trim());
      final double quantity = double.parse(_quantityController.text.trim());
      
      // Create update data
      final Map<String, dynamic> updateData = {
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
      };
      
      // Add imageUrl to update data if it exists
      if (_imageUrl != null) {
        updateData['imageUrl'] = _imageUrl;
      }
      
      // Update existing product in Firestore
      await _firestore.collection('products').doc(widget.productId).update(updateData);
      
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
                  child: _imageFile != null
                    ? Stack(
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
                                  _isImageChanged = true;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : _imageUrl != null && _imageUrl!.isNotEmpty
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                _imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _imageUrl = null;
                                    _isImageChanged = true;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: IconButton(
                            icon: const Icon(Icons.add_a_photo, size: 40),
                            onPressed: _pickImage,
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