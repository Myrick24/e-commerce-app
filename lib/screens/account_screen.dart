import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'product_screen.dart';
import 'sellerproduct_screen.dart';
import 'checkout_screen.dart'; // Import the checkout screen instead of cart screen
import 'virtual_wallet_screen.dart'; // Import the digital wallet screen
import 'notifications/account_notifications.dart';
import '../services/notification_service.dart'; // Import our notification service

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String? _userName;
  bool _isLoading = true;
  bool _isRegisteredSeller = false;
  String? _sellerId;
  String _sellerStatus = 'pending'; // Default status for sellers
  bool _isSellerApproved = false; // Flag to track if seller is approved

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
    _getCurrentUser();
  }
  
  // Load notification state using NotificationService
  // We don't need this method anymore since we're using specific notification keys
  // This is kept as a stub for backward compatibility
  Future<void> _loadNotificationState() async {
    // No implementation needed - we're using specific notification keys now
  }

  Future<void> _getCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    // Reset notification flag if user changes
    final oldUser = _currentUser;
    _currentUser = _auth.currentUser;
    
    // If the user changed, reset the notification flag
    if (_currentUser != null && (oldUser == null || oldUser.uid != _currentUser!.uid)) {
      _loadNotificationState(); // Load notification state for the new user
    }
    
    if (_currentUser != null) {
      try {
        // Try to get user data from Firestore
        final userDocRef = _firestore.collection('users').doc(_currentUser!.uid);
        
        try {
          final userDoc = await userDocRef.get();
          if (userDoc.exists) {
            // Get the user name from Firestore
            final userData = userDoc.data();
            if (userData != null && userData.containsKey('name')) {
              setState(() {
                _userName = userData['name'];
              });
            }
          }
          
          // Check if user is already registered as a seller
          try {
            final sellerQuery = await _firestore
                .collection('sellers')
                .where('email', isEqualTo: _currentUser!.email)
                .limit(1)
                .get();
            
            if (sellerQuery.docs.isNotEmpty) {
              final sellerData = sellerQuery.docs.first.data();
              String sellerStatus = sellerData['status'] ?? 'pending';
              bool isApproved = sellerStatus == 'active' || sellerStatus == 'approved';
              bool previousApprovalStatus = _isSellerApproved;
              
              setState(() {
                _isRegisteredSeller = true;
                _sellerId = sellerData['id'];
                _sellerStatus = sellerStatus;
                _isSellerApproved = isApproved;
              });
              
              // Always check notifications - our updated methods will ensure they only show once
              // If seller status has changed since last check, show an appropriate notification
              if (_isSellerApproved && !previousApprovalStatus) {
                await _showStatusChangeNotification(isApproved: true);
              } else if (!_isSellerApproved && previousApprovalStatus) {
                await _showStatusChangeNotification(isApproved: false);
              } else if (!_isSellerApproved && sellerStatus == 'pending') {
                // Show pending status notification
                await _showPendingStatusReminder();
              }
            }
          } catch (sellerQueryError) {
            print('Firestore seller query error: $sellerQueryError');
          }
        } catch (error) {
          print('Firestore error: $error');
          // Handle the Firestore permission error based on the memory
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }
  
  // Method to show status change notification
  Future<void> _showStatusChangeNotification({required bool isApproved}) async {
    if (!mounted) return;
    
    // Create a unique notification key that includes the approval status
    final statusKey = isApproved ? 'approved' : 'changed';
    final notificationKey = 'seller_status_$statusKey';
    
    // Check if we've already shown this specific notification
    bool alreadyShown = await NotificationService.hasShownSpecificNotification(notificationKey);
    
    // Only proceed if we haven't shown this notification yet
    if (!alreadyShown) {
      // Mark this specific notification type as shown
      await NotificationService.markSpecificNotificationAsShown(notificationKey);
      
      // Add to notification screen via static method
      if (_sellerId != null) {
        String message = isApproved 
          ? 'Your seller account has been approved! You can now add products.'
          : 'Your seller account status has changed. Please check details.';
        
        NotificationService.addSellerStatusNotification(
          sellerId: _sellerId!,
          isApproved: isApproved,
          message: message,
        );
        
        // Show the snackbar notification
        if (mounted) {
          Future.delayed(Duration(milliseconds: 500), () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: isApproved ? Colors.green : Colors.red,
                content: Text(
                  isApproved 
                    ? 'Your seller account has been approved! You can now add products.'
                    : 'Your seller account status has changed. Please check details.',
                  style: TextStyle(color: Colors.white),
                ),
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to notification details or seller settings
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AccountNotifications()),
                    );
                  },
                ),
              ),
            );
          });
        }
      }
    }
  }
  
  // Method to show pending status reminder
  Future<void> _showPendingStatusReminder() async {
    if (!mounted) return;
    
    // Create a unique key for pending status notification
    final notificationKey = 'seller_status_pending';
    
    // Check if we've already shown this specific notification
    bool alreadyShown = await NotificationService.hasShownSpecificNotification(notificationKey);
    
    // Only proceed if we haven't shown this notification yet
    if (!alreadyShown) {
      // Mark this specific notification type as shown
      await NotificationService.markSpecificNotificationAsShown(notificationKey);
      
      // Add to notification screen via static method
      if (_sellerId != null) {
        NotificationService.addSellerStatusNotification(
          sellerId: _sellerId!,
          isApproved: false,
          message: 'Your seller account is pending approval. We\'ll notify you once it\'s approved.',
        );
        
        // Show the snackbar notification
        if (mounted) {
          Future.delayed(Duration(milliseconds: 500), () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.amber,
                content: Text(
                  'Your seller account is pending approval. We\'ll notify you once it\'s approved.',
                  style: TextStyle(color: Colors.black87),
                ),
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      }
    }
  }

  Future<void> _logout() async {
    try {
      await NotificationService.resetNotificationState();
      await _auth.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  // Helper method to reset all seller status notification flags
  Future<void> resetAllSellerNotificationFlags() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = _auth.currentUser?.uid;
    
    if (userId != null) {
      // Remove all specific notification flags for seller status
      await prefs.remove('seller_notification_shown_${userId}_seller_status_approved');
      await prefs.remove('seller_notification_shown_${userId}_seller_status_changed');
      await prefs.remove('seller_notification_shown_${userId}_seller_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    // If user is not logged in, show login prompt
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
         backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please login to view your account',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    // User is logged in, show account info
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account header with name and email
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName ?? 'Account Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentUser?.email ?? 'example@email.com',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Sell farm products banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_isRegisteredSeller) {
                              if (_isSellerApproved) {
                                // Navigate to product screen if registered and approved
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductScreen(sellerId: _sellerId),
                                  ),
                                );
                              } else {
                                // Show a message that approval is pending
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your seller account is pending approval from an admin. You\'ll be notified when approved.'),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
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
                                    _sellerStatus = result['status'] ?? 'pending';
                                    _isSellerApproved = _sellerStatus == 'active' || _sellerStatus == 'approved';
                                  });
                                }
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(_isRegisteredSeller 
                            ? (_isSellerApproved ? 'Sell Now' : 'Pending Approval') 
                            : 'Register Now'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 40,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Your Products button for registered sellers
            if (_isRegisteredSeller)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Your Products',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!_isSellerApproved)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Check if seller is approved
                              if (!_isSellerApproved) {
                                // Show message about pending approval
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your seller account is awaiting approval. You\'ll be notified when you can manage products.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                            
                              // Proceed with normal flow if approved
                              if (_sellerId == null) {
                                // If seller ID is null for some reason, refresh seller status before continuing
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Refreshing seller information...')),
                                );
                                _getCurrentUser().then((_) {
                                  if (_sellerId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SellerProductScreen(sellerId: _sellerId),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Error: Seller ID not found. Please log out and log back in.')),
                                    );
                                  }
                                });
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SellerProductScreen(sellerId: _sellerId),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('View Products'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.list,
                        size: 40,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            // My Orders banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Orders',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckoutScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('View Orders'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 40,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Account Settings section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Settings options
            _buildSettingsItem(
              icon: Icons.account_balance_wallet,
              title: 'Digital Wallet',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VirtualWalletScreen(),
                  ),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.security,
              title: 'Security Settings',
              onTap: () {
                // Navigate to security settings
              },
            ),
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
              onTap: () {
                // Navigate to notifications screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountNotifications(),
                  ),
                );
              },
            ),
            
            // Only show status update check for registered sellers
            if (_isRegisteredSeller)
              _buildSettingsItem(
                icon: Icons.update,
                title: 'Check for Status Updates',
                onTap: () async {
                  // Reset notification flags to force check
                  await NotificationService.resetNotificationState();
                  
                  // Reset specific notification flags for all status types
                  await resetAllSellerNotificationFlags();
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for status updates...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  
                  // Re-fetch user data which will trigger notification checks
                  await _getCurrentUser();
                  
                  // Notify user
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status updated. Check notifications for any changes.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                trailing: _isSellerApproved 
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.pending, color: Colors.orange),
              ),
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                // Navigate to help and support
              },
            ),

            // Logout button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
