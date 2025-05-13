import 'package:flutter/material.dart';
import 'registration_screen.dart';
import 'account_screen.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_screen.dart';
import 'sellerproduct_screen.dart';
import 'buy_now_screen.dart';
import 'reserve_screen.dart';
import 'cart_screen.dart';
import 'notification_screen.dart';
import 'messages_screen.dart'; // Keep import for messages screen
import 'package:provider/provider.dart';
import '../services/cart_service.dart';  // Fixed import path

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isRegisteredSeller = false;
  String? _sellerId;
  bool _isLoading = true;
  int _unreadNotificationsCount = 0;
  int _unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      try {
        // Check if user is already registered as a seller
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: _currentUser!.email)
            .limit(1)
            .get();          if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          setState(() {
            _isRegisteredSeller = true;
            _sellerId = sellerData['id']; // Use the 'id' field from the seller document
          });
          
          // If user is a seller, check for unread notifications
          if (_sellerId != null) {
            _checkForUnreadNotifications(_sellerId!);
            _checkForUnreadMessages(_sellerId!);
          }
        } else {
          // If not a seller, still check unread messages as customer
          _checkForUnreadMessages(_currentUser!.uid);
        }
      } catch (e) {
        print('Error checking seller status: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _checkForUnreadNotifications(String sellerId) async {
    try {
      // Use a single where clause instead of two to avoid index requirements
      final unreadNotificationsQuery = await _firestore
          .collection('seller_notifications')
          .where('sellerId', isEqualTo: sellerId)
          .get();
      
      // Filter the results in code instead of in the query
      int unreadCount = 0;
      for (var doc in unreadNotificationsQuery.docs) {
        if (doc.data()['status'] == 'unread') {
          unreadCount++;
        }
      }
      
      setState(() {
        _unreadNotificationsCount = unreadCount;
      });
      
      // Set up a real-time listener for new notifications
      _firestore
          .collection('seller_notifications')
          .where('sellerId', isEqualTo: sellerId)
          .snapshots()
          .listen((snapshot) {
            // Filter the results in code
            int count = 0;
            for (var doc in snapshot.docs) {
              if (doc.data()['status'] == 'unread') {
                count++;
              }
            }
            
            setState(() {
              _unreadNotificationsCount = count;
            });
          });
      
    } catch (e) {
      print('Error checking unread notifications: $e');
    }
  }
  
  Future<void> _checkForUnreadMessages(String userId) async {
    try {
      final String fieldName = _isRegisteredSeller ? 'unreadSellerCount' : 'unreadCustomerCount';
      final String idField = _isRegisteredSeller ? 'sellerId' : 'customerId';
      
      // Query chats collection for unread messages
      final unreadChatsQuery = await _firestore
          .collection('chats')
          .where(idField, isEqualTo: userId)
          .get();
      
      // Calculate total unread messages
      int unreadCount = 0;
      for (var doc in unreadChatsQuery.docs) {
        unreadCount += (doc.data()[fieldName] as int? ?? 0);
      }
      
      setState(() {
        _unreadMessagesCount = unreadCount;
      });
      
      // Set up a real-time listener for unread messages
      _firestore
          .collection('chats')
          .where(idField, isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
            int count = 0;
            for (var doc in snapshot.docs) {
              count += (doc.data()[fieldName] as int? ?? 0);
            }
            
            setState(() {
              _unreadMessagesCount = count;
            });
          });
      
    } catch (e) {
      print('Error checking unread messages: $e');
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      // Profile tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountScreen()),
      );
      return;
    } else if (index == 2) {
      // Notifications tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationScreen()),
      );
      return;
    } else if (index == 1) {
      // Messages tab - navigate to MessagesScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MessagesScreen()),
      );
      return;
    }

    // Only home tab remains, set as selected
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Harvest',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Shopping cart icon with badge counter
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
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
                },
              ),
            ],
          ),
        ],
      ),
      body: _buildHomeContent(), // Always show home content
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                if (_unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _unreadMessagesCount > 9 ? '9+' : '$_unreadMessagesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
  
  Widget _buildHomeContent() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      icon: Icon(Icons.search),
                      hintText: 'Search for farm products',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sell your farm products',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Connect directly with buyers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start, // Align to start
                              children: [
                                Container(
                                  width: 150, // Fixed width instead of Expanded
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // Check if user is logged in
                                      if (_currentUser == null) {
                                        // Navigate to login if not logged in
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const LoginScreen(),
                                          ),
                                        );
                                      } else if (_isRegisteredSeller) {
                                        // Navigate to product screen if already registered
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ProductScreen(sellerId: _sellerId),
                                          ),
                                        );
                                      } else {
                                        // Navigate to registration screen if not registered
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const RegistrationScreen(),
                                          ),
                                        ).then((result) {
                                          // Handle result from registration screen
                                          if (result != null && result is Map<String, dynamic> && result['success'] == true) {
                                            setState(() {
                                              _isRegisteredSeller = true;
                                              _sellerId = result['sellerId'];
                                            });
                                            
                                            // Check for notifications for the new seller
                                            if (_sellerId != null) {
                                              _checkForUnreadNotifications(_sellerId!);
                                              _checkForUnreadMessages(_sellerId!);
                                            }
                                          }
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.green,
                                    ),
                                    child: Text(_currentUser == null
                                        ? 'Login to Sell'
                                        : (_isRegisteredSeller ? 'Sell Now' : 'Register Now')),
                                  ),
                                ),
                                // Rest of row remains empty since we removed the second button
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.smartphone,
                          size: 40,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Categories Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All >'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Categories Icons
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCategoryItem(Icons.apple, 'Fruits', Colors.orange),
                      _buildCategoryItem(Icons.set_meal, 'Vegetables', Colors.green),
                      _buildCategoryItem(Icons.grain, 'Grains', Colors.amber),
                      _buildCategoryItem(Icons.store, 'Shops', Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Featured Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All >'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          // Products grid as a separate sliver
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('products')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  // Error handling
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                final products = snapshot.data?.docs ?? [];

                if (products.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Icon(
                            Icons.inventory,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No products available yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.575, 
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index].data() as Map<String, dynamic>;

                      // Determine product color based on organic status
                      final Color productColor = product['isOrganic'] == true
                          ? Colors.green
                          : Colors.orange;

                      // Format price with peso sign
                      final double price = product['price'] is int
                          ? (product['price'] as int).toDouble()
                          : product['price'] as double;
                      final String priceDisplay = '₱${price.toString()}';

                      // Handle quantity and stock
                      final double quantity = product['quantity'] is int
                          ? (product['quantity'] as int).toDouble()
                          : product['quantity'] as double;

                      final double? currentStock = product['currentStock'] != null
                          ? (product['currentStock'] is int
                              ? (product['currentStock'] as int).toDouble()
                              : product['currentStock'] as double)
                          : quantity;

                      // Display the product card with current stock information
                      return _buildProductCard(
                        product['name'] ?? 'Product Name',
                        priceDisplay,
                        Icons.shopping_basket,
                        productColor,
                        '4.5', // Default rating
                        // Show remaining stock in the weight/unit field
                        '${currentStock?.toStringAsFixed(0) ?? quantity.toStringAsFixed(0)} ${product['unit'] ?? ''} left',
                        allowsReservation: product['allowsReservation'] ?? true,
                        currentStock: currentStock,
                        product: product,
                        productId: products[index].id,
                      );
                    },
                    childCount: products.length,
                  ),
                );
              },
            ),
          ),
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    String title,
    String price,
    IconData icon,
    Color color,
    String rating,
    String weight,
    {bool? allowsReservation, double? currentStock, required Map<String, dynamic> product, required String productId}
  ) {
    bool hasStock = currentStock != null && currentStock > 0;
    bool canReserve = allowsReservation ?? false;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with Stock Indicator
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 50,
                    color: color,
                  ),
                ),
              ),

              // Stock Status Indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasStock ? Colors.green : Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasStock ? 'In Stock' : 'Out of Stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Product Details
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Status Labels (Stock and Reservation)
                Row(
                  mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
                  children: [
                    // Stock status label
                    Flexible(  // Wrap in Flexible to allow text to shrink if needed
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),  // Reduce horizontal padding
                        decoration: BoxDecoration(
                          color: hasStock ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: hasStock ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasStock ? Icons.check_circle : Icons.cancel,
                              size: 10,
                              color: hasStock ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              hasStock ? 'In Stock' : 'Out',  // Shortened text for Out of Stock
                              style: TextStyle(
                                fontSize: 8,  // Slightly reduced font size
                                fontWeight: FontWeight.bold,
                                color: hasStock ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 3),  // Reduced spacing between labels
                    
                    // Reservation status label
                    Flexible(  // Wrap in Flexible to allow text to shrink if needed
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),  // Reduce horizontal padding
                        decoration: BoxDecoration(
                          color: canReserve ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: canReserve ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              canReserve ? Icons.event_available : Icons.event_busy,
                              size: 10,
                              color: canReserve ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              canReserve ? 'Reservable' : 'No Resv.',  // Shortened text
                              style: TextStyle(
                                fontSize: 8,  // Slightly reduced font size
                                fontWeight: FontWeight.bold,
                                color: canReserve ? Colors.blue : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),

                // Rating and Weight
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        weight,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(rating),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
                  children: [
                    // Buy Now button
                    SizedBox(
                      width: 62.5, // Fixed width instead of Expanded
                      child: ElevatedButton(
                        onPressed: hasStock
                            ? () {
                                // Direct navigation without Provider.value wrapper
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BuyNowScreen(
                                      product: product,
                                      productId: productId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Reserve button
                    SizedBox(
                      width: 62.5,
                      child: ElevatedButton(
                        onPressed: canReserve
                            ? () {
                                // Direct navigation without Provider.value wrapper
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReserveScreen(
                                      product: product,
                                      productId: productId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: canReserve ? Colors.green : Colors.grey),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          disabledForegroundColor: Colors.grey.shade400,
                        ),
                        child: Text(
                          'Reserve',
                          style: TextStyle(
                            color: canReserve ? Colors.green : Colors.grey.shade400,
                            fontSize: 12
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}