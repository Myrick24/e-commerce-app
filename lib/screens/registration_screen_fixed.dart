import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _farmDescriptionController = TextEditingController();
  
  // Product types
  bool _fruits = false;
  bool _vegetables = false;
  bool _grains = false;
  bool _dairy = false;
  bool _other = false;
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _fillCurrentUserEmail();
  }
  
  Future<void> _fillCurrentUserEmail() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.email != null && currentUser.email!.isNotEmpty) {
      setState(() {
        _emailController.text = currentUser.email!;
      });
    }
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _farmDescriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Check if user is logged in
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: You must be logged in to register as a seller')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Create a list of selected product types
      List<String> productTypes = [];
      if (_fruits) productTypes.add('Fruits');
      if (_vegetables) productTypes.add('Vegetables');
      if (_grains) productTypes.add('Grains');
      if (_dairy) productTypes.add('Dairy');
      if (_other) productTypes.add('Other');
      
      // Generate a unique ID for the seller
      final String sellerId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Use the current user's email to ensure consistency
      String sellerEmail = _emailController.text.trim();
      if (sellerEmail.isEmpty) {
        sellerEmail = currentUser.email ?? '';
      }
      
      try {
        // Create a seller document in Firestore with a specific ID
        await _firestore.collection('sellers').doc(sellerId).set({
          'id': sellerId,
          'fullName': _fullNameController.text.trim(),
          'businessName': _businessNameController.text.trim(),
          'location': _locationController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': sellerEmail,
          'farmDescription': _farmDescriptionController.text.trim(),
          'productTypes': productTypes,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending', // Set to pending for admin approval
          'verified': false,
          'userId': currentUser.uid, // Add the user ID reference
        });
        
        // Update the user's role to seller in the users collection
        await _firestore.collection('users').doc(currentUser.uid).update({
          'role': 'seller',
          'status': 'pending',
        });
        
        // Send notification to admin about new seller request (create a system notification)
        await _firestore.collection('admin_notifications').add({
          'title': 'New Seller Request',
          'message': 'A new seller registration request from ${_fullNameController.text.trim()} is waiting for approval.',
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'seller_request',
          'read': false,
          'userId': currentUser.uid,
          'sellerId': sellerId,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration submitted for approval! You\'ll be notified when approved.')),
          );
          // Return to previous screen with a result to indicate seller registration
          Navigator.pop(context, {'success': true, 'sellerId': sellerId, 'status': 'pending'});
        }
      } catch (firestoreError) {
        // Handle Firestore permission error
        print('Firestore error: $firestoreError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration failed: ${firestoreError.toString()}')),
          );
        }
      }
    } catch (e) {
      print('Error during registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
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
        title: const Text('Seller Registration'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join our community of farmers and sell your products directly to buyers.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Personal Information Section
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name*',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Business Name
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Farm/Business Name*',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your farm/business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location/Address*',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Contact Information Section
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number*',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Email Address
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true, // Make it readonly as we use the current user's email
                  decoration: const InputDecoration(
                    labelText: 'Email Address (From your account)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: 'Using your account email',
                  ),
                ),
                const SizedBox(height: 24),
                
                // Product Types Section
                const Text(
                  'Product Types',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select all that apply:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                
                // Checkboxes for product types
                CheckboxListTile(
                  title: const Text('Fruits'),
                  value: _fruits,
                  onChanged: (value) {
                    setState(() {
                      _fruits = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Vegetables'),
                  value: _vegetables,
                  onChanged: (value) {
                    setState(() {
                      _vegetables = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Grains'),
                  value: _grains,
                  onChanged: (value) {
                    setState(() {
                      _grains = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Dairy'),
                  value: _dairy,
                  onChanged: (value) {
                    setState(() {
                      _dairy = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Other'),
                  value: _other,
                  onChanged: (value) {
                    setState(() {
                      _other = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 24),
                
                // Farm Description
                const Text(
                  'Farm Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _farmDescriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Tell us about your farm and products (optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Upload Photos Section
                const Text(
                  'Upload Photos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload photos of your farm and products',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Photo upload button
                OutlinedButton(
                  onPressed: () {
                    // Photo upload functionality would go here
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Select Photos'),
                ),
                const SizedBox(height: 32),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
