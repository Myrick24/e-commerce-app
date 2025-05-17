import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

/// A utility tool for generating sample data to test the admin dashboard
class SampleDataGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Random _random = Random();
  
  // Sample product categories
  final List<String> _categories = [
    'Vegetables',
    'Fruits',
    'Dairy',
    'Meat',
    'Grains',
    'Herbs',
    'Organic',
    'Seeds',
  ];
  
  // Sample product statuses
  final List<String> _productStatuses = [
    'pending',
    'approved',
    'rejected',
  ];
  
  // Sample transaction statuses
  final List<String> _transactionStatuses = [
    'pending',
    'completed',
    'cancelled',
    'refunded',
  ];
  
  // Sample user data
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'John Farmer',
      'email': 'john.farmer@example.com',
      'role': 'seller',
      'status': 'approved',
    },
    {
      'name': 'Lisa Green',
      'email': 'lisa.green@example.com',
      'role': 'seller',
      'status': 'pending',
    },
    {
      'name': 'Mike Brown',
      'email': 'mike.brown@example.com',
      'role': 'customer',
      'status': 'active',
    },
    {
      'name': 'Sarah White',
      'email': 'sarah.white@example.com',
      'role': 'customer',
      'status': 'active',
    },
    {
      'name': 'Robert Garcia',
      'email': 'robert.garcia@example.com',
      'role': 'seller',
      'status': 'approved',
    },
  ];
  
  // Generate a random date within the last 30 days
  DateTime _randomDate() {
    return DateTime.now().subtract(Duration(days: _random.nextInt(30)));
  }
  
  // Generate a random price between min and max
  double _randomPrice(double min, double max) {
    return min + (_random.nextDouble() * (max - min));
  }
  
  // Generate a random integer between min and max
  int _randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  // Create sample users
  Future<List<String>> createSampleUsers({required String password}) async {
    List<String> userIds = [];
    
    for (var userData in _users) {
      try {
        // Create user in authentication
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: userData['email'],
          password: password,
        );
        
        // Add user data to Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': userData['name'],
          'email': userData['email'],
          'role': userData['role'],
          'status': userData['status'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        userIds.add(userCredential.user!.uid);
      } catch (e) {
        print('Error creating sample user ${userData['email']}: $e');
      }
    }
    
    return userIds;
  }

  // Create sample products
  Future<List<String>> createSampleProducts(List<String> sellerIds) async {
    List<String> productIds = [];
    
    // Product names and descriptions
    final List<Map<String, String>> products = [
      {
        'name': 'Fresh Tomatoes',
        'description': 'Locally grown organic tomatoes, perfect for salads and cooking.',
      },
      {
        'name': 'Organic Carrots',
        'description': 'Sweet and crunchy carrots, freshly harvested from our farm.',
      },
      {
        'name': 'Farm Fresh Eggs',
        'description': 'Free-range eggs from happy chickens. Rich in flavor and nutrition.',
      },
      {
        'name': 'Honey',
        'description': 'Raw, unfiltered honey collected from local flower fields.',
      },
      {
        'name': 'Kale Bunches',
        'description': 'Nutrient-rich kale, perfect for smoothies and healthy recipes.',
      },
      {
        'name': 'Apples',
        'description': 'Crisp and juicy apples picked at the peak of ripeness.',
      },
      {
        'name': 'Potatoes',
        'description': 'Versatile potatoes perfect for baking, mashing, or frying.',
      },
      {
        'name': 'Bell Peppers',
        'description': 'Colorful bell peppers that add flavor and nutrition to any dish.',
      },
      {
        'name': 'Strawberries',
        'description': 'Sweet and juicy strawberries, perfect for desserts or eating fresh.',
      },
      {
        'name': 'Fresh Herbs Mix',
        'description': 'Assortment of fresh herbs including basil, thyme, and rosemary.',
      },
    ];
    
    // For each seller, create a few products
    for (String sellerId in sellerIds) {
      // Get seller data
      DocumentSnapshot sellerDoc = await _firestore.collection('users').doc(sellerId).get();
      Map<String, dynamic> sellerData = sellerDoc.data() as Map<String, dynamic>;
      
      // Only create products for approved sellers
      if (sellerData['role'] == 'seller' && sellerData['status'] == 'approved') {
        int numProducts = _randomInt(2, 4);
        
        for (int i = 0; i < numProducts; i++) {
          Map<String, String> productInfo = products[_random.nextInt(products.length)];
          String category = _categories[_random.nextInt(_categories.length)];
          String status = _productStatuses[_random.nextInt(_productStatuses.length)];
          double price = _randomPrice(1.5, 25.0);
          int inventory = _randomInt(5, 100);
          
          // Create product document
          DocumentReference productRef = await _firestore.collection('products').add({
            'name': '${productInfo['name']} by ${sellerData['name']}',
            'description': productInfo['description'],
            'category': category,
            'price': price,
            'inventory': inventory,
            'sellerId': sellerId,
            'sellerName': sellerData['name'],
            'status': status,
            'createdAt': FieldValue.serverTimestamp(),
            'images': ['https://via.placeholder.com/400x300?text=${productInfo['name']}'],
          });
          
          productIds.add(productRef.id);
        }
      }
    }
    
    return productIds;
  }
  
  // Create sample transactions
  Future<List<String>> createSampleTransactions(List<String> userIds, List<String> productIds) async {
    List<String> transactionIds = [];
    
    // Get all customers
    List<String> customerIds = [];
    for (String userId in userIds) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      if (userData['role'] == 'customer') {
        customerIds.add(userId);
      }
    }
    
    // Get all approved products
    List<String> approvedProductIds = [];
    for (String productId in productIds) {
      DocumentSnapshot productDoc = await _firestore.collection('products').doc(productId).get();
      Map<String, dynamic> productData = productDoc.data() as Map<String, dynamic>;
      
      if (productData['status'] == 'approved') {
        approvedProductIds.add(productId);
      }
    }
    
    // Create 10 random transactions
    for (int i = 0; i < 10; i++) {
      if (customerIds.isEmpty || approvedProductIds.isEmpty) {
        break;
      }
      
      // Select random customer
      String customerId = customerIds[_random.nextInt(customerIds.length)];
      DocumentSnapshot customerDoc = await _firestore.collection('users').doc(customerId).get();
      Map<String, dynamic> customerData = customerDoc.data() as Map<String, dynamic>;
      
      // Select random product
      String productId = approvedProductIds[_random.nextInt(approvedProductIds.length)];
      DocumentSnapshot productDoc = await _firestore.collection('products').doc(productId).get();
      Map<String, dynamic> productData = productDoc.data() as Map<String, dynamic>;
      
      // Get product seller
      String sellerId = productData['sellerId'];
      
      // Create transaction with random status
      String status = _transactionStatuses[_random.nextInt(_transactionStatuses.length)];
      int quantity = _randomInt(1, 5);
      double amount = productData['price'] * quantity;
      
      // Create transaction document
      DocumentReference transactionRef = await _firestore.collection('transactions').add({
        'productId': productId,
        'productName': productData['name'],
        'productImage': productData['images'][0],
        'quantity': quantity,
        'amount': amount,
        'status': status,
        'buyerId': customerId,
        'buyerName': customerData['name'],
        'sellerId': sellerId,
        'sellerName': productData['sellerName'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      transactionIds.add(transactionRef.id);
    }
    
    return transactionIds;
  }
  
  // Create sample announcements
  Future<List<String>> createSampleAnnouncements() async {
    List<String> announcementIds = [];
    
    List<Map<String, String>> announcements = [
      {
        'title': 'Welcome to our new platform!',
        'body': 'We are excited to launch our new e-commerce platform for farm products. Thank you for being part of our community.',
        'type': 'general'
      },
      {
        'title': 'Holiday Schedule Update',
        'body': 'Please note that we will have modified delivery schedules during the upcoming holiday season. Check the app for details.',
        'type': 'general'
      },
      {
        'title': 'New Feature: Rating System',
        'body': 'We\'ve added a new rating system for products and sellers. Your feedback helps our community!',
        'type': 'feature'
      },
      {
        'title': 'Seasonal Produce Available',
        'body': 'Don\'t miss out on our seasonal fruits and vegetables! Limited quantities available.',
        'type': 'promotion'
      },
      {
        'title': 'Maintenance Notice',
        'body': 'The app will be undergoing maintenance on Sunday from 2 AM to 4 AM. Some features may be temporarily unavailable.',
        'type': 'system'
      },
    ];
    
    for (var announcement in announcements) {
      DocumentReference announcementRef = await _firestore.collection('announcements').add({
        'title': announcement['title'],
        'body': announcement['body'],
        'type': announcement['type'],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'system',
        'active': true,
      });
      
      announcementIds.add(announcementRef.id);
    }
    
    return announcementIds;
  }
  
  // Generate all sample data
  Future<Map<String, List<String>>> generateAllSampleData({required String password}) async {
    Map<String, List<String>> results = {};
    
    print('Creating sample users...');
    List<String> userIds = await createSampleUsers(password: password);
    results['users'] = userIds;
    
    print('Creating sample products...');
    List<String> productIds = await createSampleProducts(userIds);
    results['products'] = productIds;
    
    print('Creating sample transactions...');
    List<String> transactionIds = await createSampleTransactions(userIds, productIds);
    results['transactions'] = transactionIds;
    
    print('Creating sample announcements...');
    List<String> announcementIds = await createSampleAnnouncements();
    results['announcements'] = announcementIds;
    
    print('Sample data generation complete!');
    return results;
  }
}
