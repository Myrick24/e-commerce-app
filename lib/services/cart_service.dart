import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartItem {
  final String id;
  final String productId;
  final String sellerId;
  final String productName;
  final double price;
  final int quantity;
  final String unit;
  final bool isReservation;
  final DateTime? pickupDate;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.isReservation,
    this.pickupDate,
    this.imageUrl,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'sellerId': sellerId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'isReservation': isReservation,
      'pickupDate': pickupDate?.toIso8601String(),
      'addedAt': DateTime.now().toIso8601String(),
      'imageUrl': imageUrl,
    };
  }
  factory CartItem.fromMap(Map<String, dynamic> map) {
    DateTime? pickupDate;
    if (map['pickupDate'] != null) {
      try {
        pickupDate = DateTime.parse(map['pickupDate']);
      } catch (_) {}
    }

    return CartItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] as double),
      quantity: map['quantity'] ?? 1,
      unit: map['unit'] ?? '',
      isReservation: map['isReservation'] ?? false,
      pickupDate: pickupDate,
      imageUrl: map['imageUrl'],
    );
  }
}

class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _cartItems = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CartItem> get cartItems => _cartItems;
  int get itemCount => _cartItems.length;
  
  double get totalPrice {
    double total = 0;
    for (var item in _cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  // Check if adding the item would exceed available stock
  Future<bool> checkStock(String productId, int quantity) async {
    try {
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) return false;
      
      final productData = productDoc.data()!;
      double currentStock = productData['currentStock'] is int
          ? (productData['currentStock'] as int).toDouble()
          : productData['currentStock'] as double;
      
      // Check if existing cart items already contain this product
      int existingQuantity = 0;
      for (var item in _cartItems) {
        if (item.productId == productId && !item.isReservation) {
          existingQuantity += item.quantity;
        }
      }
      
      // Return true if there's enough stock (current stock ≥ requested quantity + existing quantity)
      return currentStock >= (quantity + existingQuantity);
    } catch (e) {
      print('Error checking stock: $e');
      return false;
    }
  }

  // Add item to cart and temporarily hold the stock
  Future<bool> addItem(CartItem item) async {
    try {
      // Skip stock check for reservation items
      if (!item.isReservation) {
        // Check if there's enough stock
        bool hasStock = await checkStock(item.productId, item.quantity);
        if (!hasStock) {
          return false;
        }

        // Update the stock in database temporarily (this will be reflected in UI)
        await _firestore.collection('products').doc(item.productId).update({
          'currentStock': FieldValue.increment(-item.quantity),
        });
      }
      
      // Check if the item already exists in cart
      final existingIndex = _cartItems.indexWhere((cartItem) => 
        cartItem.productId == item.productId && 
        cartItem.isReservation == item.isReservation
      );

      if (existingIndex >= 0) {
        // Update quantity of existing item
        final existingItem = _cartItems[existingIndex];
        final updatedItem = CartItem(
          id: existingItem.id,
          productId: existingItem.productId,
          sellerId: existingItem.sellerId,
          productName: existingItem.productName,
          price: existingItem.price,
          quantity: existingItem.quantity + item.quantity,
          unit: existingItem.unit,
          isReservation: existingItem.isReservation,
          pickupDate: item.isReservation ? item.pickupDate : null,
        );
        _cartItems[existingIndex] = updatedItem;
      } else {
        // Add new item
        _cartItems.add(item);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding item to cart: $e');
      return false;
    }
  }

  // Remove item from cart and return the stock to inventory
  Future<void> removeItem(String id) async {
    try {
      final index = _cartItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        final item = _cartItems[index];
        
        // Only update stock for regular purchases, not reservations
        if (!item.isReservation) {
          // Return the stock to the product
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(item.quantity),
          });
        }
        
        _cartItems.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      print('Error removing item from cart: $e');
    }
  }

  // Update item quantity and adjust stock accordingly
  Future<void> updateQuantity(String id, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(id);
      return;
    }
    
    final index = _cartItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final item = _cartItems[index];
      
      // Skip stock updates for reservations
      if (!item.isReservation) {
        // Calculate the difference in quantity
        final quantityDiff = newQuantity - item.quantity;
        
        if (quantityDiff != 0) {
          // Check if increasing and there's enough stock
          if (quantityDiff > 0) {
            final productDoc = await _firestore.collection('products').doc(item.productId).get();
            if (!productDoc.exists) return;
            
            final currentStock = productDoc.data()?['currentStock'] is int
                ? (productDoc.data()?['currentStock'] as int).toDouble()
                : productDoc.data()?['currentStock'] as double;
            
            if (currentStock < quantityDiff) {
              // Not enough stock to increase
              return;
            }
          }
          
          // Update the stock in database
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(-quantityDiff),
          });
        }
      }
      
      // Update the item in the cart
      final updatedItem = CartItem(
        id: item.id,
        productId: item.productId,
        sellerId: item.sellerId,
        productName: item.productName,
        price: item.price,
        quantity: newQuantity,
        unit: item.unit,
        isReservation: item.isReservation,
        pickupDate: item.pickupDate,
      );
      
      _cartItems[index] = updatedItem;
      notifyListeners();
    }
  }

  // Clear cart and return all stock to inventory
  Future<void> clearCart() async {
    try {
      // Return all non-reservation items to inventory
      for (final item in _cartItems) {
        if (!item.isReservation) {
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(item.quantity),
          });
        }
      }
      
      _cartItems.clear();
      notifyListeners();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }

  // Method to save cart items to database for a specific user
  Future<void> saveCartToDatabase(String userId) async {
    try {
      // Delete existing cart items for the user
      await _firestore.collection('user_carts')
          .doc(userId)
          .collection('cart_items')
          .get()
          .then((snapshot) {
            for (DocumentSnapshot doc in snapshot.docs) {
              doc.reference.delete();
            }
          });
      
      // Add all current cart items
      for (CartItem item in _cartItems) {
        await _firestore.collection('user_carts')
            .doc(userId)
            .collection('cart_items')
            .doc(item.id)
            .set(item.toMap());
      }
    } catch (e) {
      print('Error saving cart to database: $e');
    }
  }

  // Load cart from database for a specific user
  Future<void> loadCartFromDatabase(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_carts')
          .doc(userId)
          .collection('cart_items')
          .get();
      
      _cartItems.clear();
      
      for (final doc in snapshot.docs) {
        _cartItems.add(CartItem.fromMap(doc.data()));
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading cart from database: $e');
    }
  }

  // Process all items in cart - either purchase or reserve
  Future<bool> processCart(String userId, {
    required String paymentMethod,
    required String deliveryMethod,
    String? meetupLocation,
  }) async {
    try {
      print('Starting checkout process for user: $userId');
      print('Cart items: ${_cartItems.length} items total');
      
      final batch = _firestore.batch();
      final orderTime = DateTime.now();
      
      // Create separate transactions for purchases and reservations
      final purchaseItems = _cartItems.where((item) => !item.isReservation).toList();
      final reservationItems = _cartItems.where((item) => item.isReservation).toList();
      
      print('Regular purchase items: ${purchaseItems.length}, Reservation items: ${reservationItems.length}');
      
      // Process regular purchases
      if (purchaseItems.isNotEmpty) {
        // For each item, create an individual order for better tracking
        for (final item in purchaseItems) {
          final orderId = 'order_${orderTime.millisecondsSinceEpoch}_${item.productId}';
          print('Creating order with ID: $orderId for product: ${item.productName}');
          
          // First, get current user info
          User? currentUser = FirebaseAuth.instance.currentUser;
          Map<String, dynamic> userData = {};
          
          if (currentUser != null) {
            try {
              DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
              if (userDoc.exists) {
                userData = userDoc.data() as Map<String, dynamic>;
              }
            } catch (e) {
              print('Error loading user data: $e');
            }
          }
          
          final orderRef = _firestore.collection('orders').doc(orderId);
          final orderData = {
            'id': orderId,
            'userId': userId,
            'totalAmount': item.price * item.quantity,
            'status': 'pending',
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
            'timestamp': FieldValue.serverTimestamp(),
            // Include product details directly in the order
            'productId': item.productId,
            'productName': item.productName,
            'price': item.price,
            'quantity': item.quantity,
            'unit': item.unit,
            'sellerId': item.sellerId,
            // Add meet-up location if delivery method is Meet-up
            if (deliveryMethod == 'Meet-up' && meetupLocation != null && meetupLocation.isNotEmpty)
              'meetupLocation': meetupLocation,
            // Add customer info
            'customerName': userData['name'] ?? userData['fullName'] ?? currentUser?.displayName ?? 'Customer',
            'userEmail': currentUser?.email,
            'customerContact': userData['phone'] ?? userData['phoneNumber'] ?? 'No contact information',
          };
          
          print('Order data: $orderData');
          batch.set(orderRef, orderData);
          
          // Store order items details in subcollection for reference
          final orderItemRef = orderRef.collection('items').doc(item.id);
          batch.set(orderItemRef, item.toMap());
          
          // Create notification for the seller
          final notificationId = 'notification_${DateTime.now().millisecondsSinceEpoch}_${item.sellerId}';
          final notificationRef = _firestore.collection('seller_notifications').doc(notificationId);
          batch.set(notificationRef, {
            'id': notificationId,
            'sellerId': item.sellerId,
            'orderId': orderId,
            'productId': item.productId,
            'productName': item.productName,
            'quantity': item.quantity,
            'totalAmount': item.price * item.quantity,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'unread',
            'type': 'new_order',
            'message': 'New order for ${item.productName} (${item.quantity} ${item.unit}) needs approval',
            'needsApproval': true, // Add this flag to indicate approval is needed
            'customerName': orderData['customerName'] ?? 'Customer',
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
            'meetupLocation': meetupLocation,
          });
          
          // Add reference to the order document
          final productOrderRef = _firestore.collection('product_orders')
              .doc(item.productId)
              .collection('orders')
              .doc(orderId);
          
          batch.set(productOrderRef, {
            'orderId': orderId,
            'sellerId': item.sellerId,
            'productId': item.productId,
            'quantity': item.quantity,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          // Update the actual product quantity in the database
          // This permanently reduces the total product quantity, not just the currentStock
          final productRef = _firestore.collection('products').doc(item.productId);
          batch.update(productRef, {
            'quantity': FieldValue.increment(-item.quantity),
            // Ensure currentStock matches the new quantity
            'currentStock': FieldValue.increment(-item.quantity),
          });
        }
      }
      
      // Process reservations
      if (reservationItems.isNotEmpty) {
        // For each item create an individual reservation
        for (final item in reservationItems) {
          final reservationId = 'reservation_${orderTime.millisecondsSinceEpoch}_${item.productId}';
          print('Creating reservation with ID: $reservationId for product: ${item.productName}');
          
          // Create reservation document with embedded product details
          final reservationRef = _firestore.collection('reservations').doc(reservationId);
          batch.set(reservationRef, {
            'id': reservationId,
            'userId': userId,
            'totalAmount': item.price * item.quantity,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            // Include product details directly in the reservation
            'productId': item.productId,
            'productName': item.productName,
            'price': item.price,
            'quantity': item.quantity,
            'unit': item.unit,
            'sellerId': item.sellerId,
            'pickupDate': item.pickupDate?.toIso8601String(),
          });
          
          // Store reservation items in subcollection for reference
          final reservationItemRef = reservationRef.collection('items').doc(item.id);
          batch.set(reservationItemRef, item.toMap());
          
          // Create notification for the seller
          final notificationId = 'notification_${DateTime.now().millisecondsSinceEpoch}_${item.sellerId}';
          final notificationRef = _firestore.collection('seller_notifications').doc(notificationId);
          batch.set(notificationRef, {
            'id': notificationId,
            'sellerId': item.sellerId,
            'reservationId': reservationId,
            'productId': item.productId,
            'productName': item.productName,
            'quantity': item.quantity,
            'totalAmount': item.price * item.quantity,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'unread',
            'type': 'new_reservation',
            'pickupDate': item.pickupDate?.toIso8601String(),
            'message': 'New reservation for ${item.productName} (${item.quantity} ${item.unit})',
          });
          
          // Update product reserved count
          final productRef = _firestore.collection('products').doc(item.productId);
          batch.update(productRef, {
            'reserved': FieldValue.increment(item.quantity),
          });
        }
      }
      
      // Execute the batch
      print('Committing batch write to Firestore...');
      await batch.commit();
      print('Batch committed successfully');
      
      // Clear the cart after successful processing
      clearCart();
      
      return true;
    } catch (e) {
      print('Error processing cart: $e');
      return false;
    }
  }
}