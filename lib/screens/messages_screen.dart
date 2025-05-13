import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isLoading = true;
  bool _isSeller = false;
  String? _sellerId;
  TabController? _tabController;
  Map<String, String> _userNames = {}; // Cache for user names
  Map<String, String> _sellerNames = {}; // Cache for seller names

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentUser();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
            .get();        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          setState(() {
            _isSeller = true;
            _sellerId = sellerData['id'];
          });
        }
      } catch (e) {
        print('Error checking seller status: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }
  
  // Function to get user name from Firestore
  Future<String> _getUserName(String userId) async {
    // First check if we already have this user name in cache
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Check for fullName first, then other fields
        final name = userData['fullName'] ?? 
                    userData['name'] ?? 
                    userData['displayName'] ?? 
                    userData['firstName'] ?? 
                    userData['email']?.toString().split('@').first ?? 
                    'User';
                    
        // Store in cache for future use
        _userNames[userId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    
    return 'User';
  }
  
  // Function to get seller name from Firestore
  Future<String> _getSellerName(String sellerId) async {
    // First check if we already have this seller name in cache
    if (_sellerNames.containsKey(sellerId)) {
      return _sellerNames[sellerId]!;
    }
    
    try {
      final sellerDoc = await _firestore.collection('sellers').doc(sellerId).get();
      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data() as Map<String, dynamic>;
        
        // Prioritize personal name fields (fullName)
        String? name = sellerData['fullName'];
        
        // If fullName is not available, try these fields in order
        if (name == null || name.isEmpty) {
          name = sellerData['name'] ?? 
                sellerData['displayName'] ?? 
                sellerData['firstName'];
                
          // Only if no personal name is found, use business name
          if (name == null || name.isEmpty) {
            name = sellerData['businessName'] ?? 
                  sellerData['companyName'] ?? 
                  sellerData['storeName'];
          }
        }
        
        // If still no name, try email or default to 'Seller'
        name ??= sellerData['email']?.toString().split('@').first ?? 
                'Seller';
                     
        // Store in cache for future use
        _sellerNames[sellerId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching seller name: $e');
    }
    
    return 'Seller';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please login to view messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Recent Chats'),
            Tab(text: 'All Contacts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recent Chats Tab
          _buildChatsList(recentOnly: true),
          
          // All Contacts Tab
          _buildChatsList(recentOnly: false),
        ],
      ),
    );
  }

  Widget _buildChatsList({required bool recentOnly}) {
    Query chatsQuery;
    
    if (_isSeller) {
      // Seller view - show chats where they are the seller
      chatsQuery = _firestore.collection('chats')
          .where('sellerId', isEqualTo: _sellerId)
          .orderBy('lastMessageTimestamp', descending: true);
          
      if (recentOnly) {
        // For recent chats, add a time filter (e.g., last 30 days)
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        chatsQuery = chatsQuery.where(
          'lastMessageTimestamp',
          isGreaterThan: Timestamp.fromDate(thirtyDaysAgo)
        );
      }
    } else {
      // Customer view - show chats where they are the customer
      chatsQuery = _firestore.collection('chats')
          .where('customerId', isEqualTo: _currentUser!.uid)
          .orderBy('lastMessageTimestamp', descending: true);
          
      if (recentOnly) {
        // For recent chats, add a time filter (e.g., last 30 days)
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        chatsQuery = chatsQuery.where(
          'lastMessageTimestamp',
          isGreaterThan: Timestamp.fromDate(thirtyDaysAgo)
        );
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: chatsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  recentOnly ? 'No recent messages' : 'No messages yet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatData = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            
            // Determine if we need to fetch customer or seller info
            final otherPartyId = _isSeller 
                ? chatData['customerId'] as String 
                : chatData['sellerId'] as String;
            
            final Future<String> otherPartyNameFuture = _isSeller
                ? _getUserName(otherPartyId)
                : _getSellerName(otherPartyId);

            final lastMessage = chatData['lastMessage'] as String? ?? 'No messages yet';
            final lastMessageTime = (chatData['lastMessageTimestamp'] as Timestamp?)?.toDate();
            final formattedTime = lastMessageTime != null 
                ? _formatChatTime(lastMessageTime) 
                : '';
            final unreadCount = _isSeller 
                ? chatData['unreadSellerCount'] as int? ?? 0 
                : chatData['unreadCustomerCount'] as int? ?? 0;
            
            return FutureBuilder<String>(
              future: otherPartyNameFuture,
              builder: (context, nameSnapshot) {
                if (nameSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    title: Text('Loading...'),
                  );
                }

                final userName = nameSnapshot.data ?? (_isSeller ? 'User' : 'Seller');
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0 ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            color: unreadCount > 0 ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          chatId: chatId,
                          otherPartyName: userName,
                          sellerId: chatData['sellerId'] as String,
                          customerId: chatData['customerId'] as String,
                          isSeller: _isSeller,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      // Today, show time
      return DateFormat('h:mm a').format(time);
    } else if (messageDate == yesterday) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      // Within last week, show day name
      return DateFormat('E').format(time);
    } else {
      // Older, show date
      return DateFormat('M/d/yy').format(time);
    }
  }
}