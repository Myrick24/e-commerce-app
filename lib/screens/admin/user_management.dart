import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import 'seller_request_detail.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({Key? key}) : super(key: key);

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _buyers = [];
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _pendingSellers = [];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _loadUsersByTab(_tabController.index);
    });
    // Start with the Pending Sellers tab active
    _tabController.animateTo(3);
    _loadUsersByTab(3); // Load Pending Sellers initially
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadUsersByTab(int tabIndex) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      switch (tabIndex) {
        case 0: // All Users
          _allUsers = await _userService.getAllUsers();
          print('Loaded ${_allUsers.length} users sorted by ID');
          break;
        case 1: // Buyers
          _buyers = await _userService.getUsersByRole('buyer');
          print('Loaded ${_buyers.length} buyers sorted by ID');
          break;
        case 2: // Sellers
          _sellers = await _userService.getUsersByRole('seller');
          // Filter to only show approved sellers
          _sellers = _sellers.where((seller) => seller['status'] == 'approved').toList();
          print('Loaded ${_sellers.length} approved sellers sorted by ID');
          break;
        case 3: // Pending Sellers
          _pendingSellers = await _userService.getPendingSellers();
          print('Loaded ${_pendingSellers.length} pending sellers');
          
          // Debug information to help troubleshoot
          for (var seller in _pendingSellers) {
            print('Pending seller found: ${seller['name']} (${seller['id']})');
            print('Status: ${seller['status']}');
            print('Role: ${seller['role']}');
            print('------');
          }
          
          // If there are no pending sellers, check manually for sellers with pending status
          if (_pendingSellers.isEmpty) {
            print('No pending sellers found using getPendingSellers. Trying alternate approach...');
            List<Map<String, dynamic>> allSellers = await _userService.getUsersByRole('seller');
            _pendingSellers = allSellers.where((seller) => seller['status'] == 'pending').toList();
            print('Alternate check found ${_pendingSellers.length} pending sellers');
          }
          break;
      }
    } catch (e) {
      print('Error loading users: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveSellerDirectly(String userId, String userName) async {
    try {
      bool success = await _userService.approveSeller(userId);
      if (success) {
        // Send notification to the seller
        await _notificationService.sendNotificationToUser(
          userId: userId,
          title: 'Seller Approval',
          message: 'Congratulations! You have been approved as a seller. You can now start listing your products.',
          type: 'seller_approval',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller approved successfully')),
        );
        
        // Refresh the list
        _loadUsersByTab(_tabController.index);
      }
    } catch (e) {
      print('Error approving seller: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve seller')),
      );
    }
  }

  Future<void> _rejectSellerDirectly(String userId) async {
    try {
      bool success = await _userService.rejectSeller(userId);
      if (success) {
        // Send notification to the seller
        await _notificationService.sendNotificationToUser(
          userId: userId,
          title: 'Seller Application',
          message: 'Your application to become a seller has been rejected. Please contact support for more information.',
          type: 'seller_rejection',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seller rejected')),
        );
        
        // Refresh the list
        _loadUsersByTab(_tabController.index);
      }
    } catch (e) {
      print('Error rejecting seller: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject seller')),
      );
    }
  }

  Future<void> _updateUserStatus(String userId, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'active' ? 'suspended' : 'active';
      bool success = await _userService.updateUserStatus(userId, newStatus);
      
      if (success) {
        // Send notification to the user
        await _notificationService.sendNotificationToUser(
          userId: userId,
          title: 'Account Status Updated',
          message: 'Your account has been ${newStatus.toUpperCase()}.',
          type: 'account_status_update',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User status updated to $newStatus')),
        );
        
        // Refresh the list
        _loadUsersByTab(_tabController.index);
      }
    } catch (e) {
      print('Error updating user status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update user status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(      appBar: AppBar(
        title: const Text('Account Management'),
        backgroundColor: Colors.green,
        actions: [          // Information about sorting
          Center(
            child: Text(
              'Sorted by ID',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsersByTab(_tabController.index);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: 'All Users'),
              Tab(text: 'Buyers'),
              Tab(text: 'Sellers'),
              Tab(text: 'Pending Sellers'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_allUsers, 'all'),
                _buildUserList(_buyers, 'buyers'),
                _buildUserList(_sellers, 'sellers'),
                _buildPendingSellerList(),
              ],
            ),
          ),
        ],
      ),
    );
  }  Widget _buildUserList(List<Map<String, dynamic>> users, String type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    
    
    return RefreshIndicator(
      onRefresh: () => _loadUsersByTab(_tabController.index),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          (user['name'] as String).isNotEmpty 
                              ? (user['name'] as String)[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user['email'] ?? 'No email',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${user['id'] ?? 'Unknown ID'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildRoleBadge(user['role'] ?? 'buyer'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusChip(user['status'] ?? 'active'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue),
                            onPressed: () {
                              // View profile action
                            },
                            tooltip: 'View Profile',
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.green),
                            onPressed: () {
                              // Message action
                            },
                            tooltip: 'Message',
                          ),
                          IconButton(
                            icon: Icon(
                              user['status'] == 'suspended' ? Icons.check_circle : Icons.block,
                              color: user['status'] == 'suspended' ? Colors.green : Colors.red,
                            ),
                            onPressed: () {
                              _updateUserStatus(user['id'], user['status'] ?? 'active');
                            },
                            tooltip: user['status'] == 'suspended' ? 'Activate' : 'Suspend',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingSellerList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_pendingSellers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No pending seller requests',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When sellers register, their requests will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadUsersByTab(3),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _pendingSellers.length,
        itemBuilder: (context, index) {
          final seller = _pendingSellers[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.shade200,
                        child: Text(
                          (seller['name'] as String).isNotEmpty 
                              ? (seller['name'] as String)[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seller['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),                            Text(
                              seller['email'] ?? 'No email',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${seller['id'] ?? 'Unknown ID'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Chip(
                        label: Text('PENDING'),
                        backgroundColor: Colors.orange,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),                  
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Applied: ${_formatTimestamp(seller['createdAt'])}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),                      
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.visibility, size: 14),                              
                              label: const Text(
                                'View',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                print('Navigating to seller details: ${seller['id']}');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SellerRequestDetailPage(sellerId: seller['id']),
                                  ),
                                ).then((_) {
                                  // Refresh the list when returning from details page
                                  _loadUsersByTab(3);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 14),                              
                              label: const Text(
                                'Approve',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _approveSellerDirectly(seller['id'], seller['name']);
                              },
                            ),
                          ),                          const SizedBox(width: 6),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.close, size: 14),
                              label: const Text(
                                'Reject',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _rejectSellerDirectly(seller['id']);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    IconData icon;
    
    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.red;
        icon = Icons.admin_panel_settings;
        break;
      case 'seller':
        color = Colors.green;
        icon = Icons.store;
        break;
      case 'buyer':
      default:
        color = Colors.blue;
        icon = Icons.person;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'suspended':
        color = Colors.red;
        break;
      case 'rejected':
        color = Colors.grey;
        break;
      default:
        color = Colors.blue;
    }
    
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.5)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
