import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin_service.dart';
import '../../services/user_service.dart';
import 'dashboard_home.dart';
import 'user_management.dart';
import 'product_listings_fixed_final.dart'; // Updated to use the fixed version
import 'transaction_monitoring.dart';
import 'announcements.dart';
import 'admin_settings.dart';
import '../login_screen.dart'; // Import for login screen

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final AdminService _adminService = AdminService();
  final UserService _userService = UserService();
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await _adminService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    }
  }

  final List<Widget> _adminPages = [
    const DashboardHome(),
    const UserManagement(),
    const ProductListings(),
    const TransactionMonitoring(),
    const AnnouncementsScreen(),
    const AdminSettings(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'User Management',
    'Products',
    'Transactions',
    'Announcements',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have admin privileges.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        backgroundColor: Colors.green,
      ),
      body: _adminPages[_selectedIndex],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.green,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _userService.getUserData(_userService.currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox();
                      }
                      String name = snapshot.data?['name'] ?? 'Admin';
                      return Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
              index: 0,
            ),
            _buildDrawerItem(
              icon: Icons.people,
              title: 'User Management',
              index: 1,
            ),
            _buildDrawerItem(
              icon: Icons.inventory,
              title: 'Products',
              index: 2,
            ),
            _buildDrawerItem(
              icon: Icons.receipt_long,
              title: 'Transactions',
              index: 3,
            ),
            _buildDrawerItem(
              icon: Icons.announcement,
              title: 'Announcements',
              index: 4,
            ),
            _buildDrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              index: 5,
            ),            const Divider(),            ListTile(
              leading: const Icon(Icons.data_array),
              title: const Text(
                'Generate Sample Data',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onTap: () {
                Navigator.pushNamed(context, '/sample-data');
              },
            ),            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Exit Admin', 
                style: TextStyle(color: Colors.red),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onTap: () async {
                // Close the drawer
                Navigator.pop(context);
                // Show loading indicator with a message
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    content: Row(
                      children: [
                        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),
                        const SizedBox(width: 20),
                        const Text("Signing out..."),
                      ],
                    ),
                  ),
                );
                // Sign out from Firebase Auth
                try {
                  await FirebaseAuth.instance.signOut();
                  // Dismiss the loading dialog if still mounted
                  if (mounted) Navigator.pop(context);
                  // Navigate to login screen, removing all previous routes
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  // Dismiss the loading dialog if still mounted
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error signing out: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? Colors.green : null),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex == index ? Colors.green : null,
          fontWeight: _selectedIndex == index ? FontWeight.bold : null,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}
