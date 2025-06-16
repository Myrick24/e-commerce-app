import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({Key? key}) : super(key: key);

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final AdminService _adminService = AdminService();
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();
  
  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, int> _weeklyProductActivity = {};
  Map<String, double> _weeklyTransactionActivity = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic> stats = await _adminService.getDashboardStats();
      List<Map<String, dynamic>> activity = await _adminService.getRecentActivity();
      Map<String, int> productActivity = await _productService.getWeeklyProductActivity();
      Map<String, double> transactionActivity = await _transactionService.getWeeklyTransactionActivity();
      
      if (mounted) {
        setState(() {
          _dashboardStats = stats;
          _recentActivity = activity;
          _weeklyProductActivity = productActivity;
          _weeklyTransactionActivity = transactionActivity;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          _buildActivityChart(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }  Widget _buildSummaryCards() {    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
      shrinkWrap: true,
      childAspectRatio: 1.5, // Increased ratio to make cards shorter
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          title: 'Total Users',
          value: _dashboardStats['totalUsers']?.toString() ?? '0',
          icon: Icons.people,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Pending Sellers',
          value: _dashboardStats['pendingSellers']?.toString() ?? '0',
          icon: Icons.person_add_alt_1,
          color: Colors.red,
          onTap: () {
            // Navigate to the user management page with pending tab selected
            Navigator.pushNamed(context, '/admin/users');
          },
        ),
        _buildSummaryCard(
          title: 'Approved Sellers',
          value: _dashboardStats['approvedSellers']?.toString() ?? '0',
          icon: Icons.store,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'Active Listings',
          value: _dashboardStats['activeListings']?.toString() ?? '0',
          icon: Icons.shopping_bag,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Completed Transactions',
          value: _dashboardStats['completedTransactions']?.toString() ?? '0',
          icon: Icons.receipt,
          color: Colors.purple,
        ),
      ],
    );
  }  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero, // Remove default card margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0), // Increased vertical padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Use minimum space needed
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, // Allow up to 2 lines for title
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, color: color, size: 20), // Slightly smaller icon
                ],
              ),
              const SizedBox(height: 12), // Increase spacing
              // Use SizedBox with constrained height to prevent overflow
              SizedBox(
                height: 35, // Increased height for the value
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24, // Back to original size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityChart(){
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < 7) {
                            final now = DateTime.now();
                            final day = now.subtract(Duration(days: 6 - value.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E').format(day),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _generateBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    List<BarChartGroupData> barGroups = [];
    
    // Create dates for the last 7 days (including today)
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final dateString = '${date.year}-${date.month}-${date.day}';
      
      // Get activity data for this date
      final productCount = _weeklyProductActivity[dateString] ?? 0;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: productCount.toDouble(),
              color: Colors.green,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    
    return barGroups;
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_recentActivity.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No recent activity'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentActivity.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  return _buildActivityItem(_recentActivity[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    IconData icon;
    String title = '';
    String subtitle = '';
    Color color;
    
    switch (activity['type']) {
      case 'user_registration':
        icon = Icons.person_add;
        title = 'New user registered';
        subtitle = 'User: ${activity['user']['name']}';
        color = Colors.blue;
        break;
      case 'pending_seller':
        icon = Icons.store;
        title = 'New seller registration pending approval';
        subtitle = 'Seller: ${activity['user']['name']}';
        color = Colors.orange;
        break;
      case 'transaction':
        icon = Icons.receipt;
        title = 'New transaction ${activity['transaction']['status']}';
        subtitle = 'Amount: \$${activity['transaction']['amount']}';
        color = Colors.green;
        break;
      case 'product_listing':
        icon = Icons.shopping_bag;
        title = 'New product listed';
        subtitle = 'Product: ${activity['product']['name']}';
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        title = 'Activity';
        subtitle = '';
        color = Colors.grey;
    }
      return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Container(
        width: 50,
        alignment: Alignment.centerRight,
        child: Text(
          _formatTimestamp(activity['timestamp']),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    
    Duration difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
