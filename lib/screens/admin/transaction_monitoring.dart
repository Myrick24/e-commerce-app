import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/transaction_service.dart';

class TransactionMonitoring extends StatefulWidget {
  const TransactionMonitoring({Key? key}) : super(key: key);

  @override
  State<TransactionMonitoring> createState() => _TransactionMonitoringState();
}

class _TransactionMonitoringState extends State<TransactionMonitoring> with SingleTickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _pendingTransactions = [];
  List<Map<String, dynamic>> _completedTransactions = [];
  List<Map<String, dynamic>> _canceledTransactions = [];
  
  // For date filtering
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedUserId = '';
  bool _isFilterActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Reset filters when changing tabs
        _resetFilters();
      }
      _loadTransactionsByTab(_tabController.index);
    });
    _loadTransactionsByTab(0); // Load All Transactions initially
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedUserId = '';
      _isFilterActive = false;
    });
  }

  Future<void> _loadTransactionsByTab(int tabIndex) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      List<Map<String, dynamic>> transactions;
      
      // Apply date filter if active
      if (_isFilterActive && _startDate != null && _endDate != null) {
        transactions = await _transactionService.getTransactionsByDateRange(
          _startDate!,
          _endDate!,
        );
        
        // Apply user filter if selected
        if (_selectedUserId.isNotEmpty) {
          transactions = transactions.where((t) => t['userId'] == _selectedUserId).toList();
        }
        
        // Apply status filter based on tab
        switch (tabIndex) {
          case 1: // Pending
            transactions = transactions.where((t) => t['status'] == 'pending').toList();
            break;
          case 2: // Completed
            transactions = transactions.where((t) => t['status'] == 'completed').toList();
            break;
          case 3: // Canceled
            transactions = transactions.where((t) => t['status'] == 'canceled').toList();
            break;
        }
      } else {
        // No filter, just get by status
        switch (tabIndex) {
          case 0: // All Transactions
            transactions = await _transactionService.getAllTransactions();
            break;
          case 1: // Pending Transactions
            transactions = await _transactionService.getTransactionsByStatus('pending');
            break;
          case 2: // Completed Transactions
            transactions = await _transactionService.getTransactionsByStatus('completed');
            break;
          case 3: // Canceled Transactions
            transactions = await _transactionService.getTransactionsByStatus('canceled');
            break;
          default:
            transactions = await _transactionService.getAllTransactions();
        }
      }
      
      if (mounted) {
        setState(() {
          switch (tabIndex) {
            case 0:
              _allTransactions = transactions;
              break;
            case 1:
              _pendingTransactions = transactions;
              break;
            case 2:
              _completedTransactions = transactions;
              break;
            case 3:
              _canceledTransactions = transactions;
              break;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isFilterActive = true;
      });
      _loadTransactionsByTab(_tabController.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
              Tab(text: 'Canceled'),
            ],
          ),
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(_allTransactions),
                _buildTransactionList(_pendingTransactions),
                _buildTransactionList(_completedTransactions),
                _buildTransactionList(_canceledTransactions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MM/dd/yyyy').format(_startDate!)} - ${DateFormat('MM/dd/yyyy').format(_endDate!)}'
                          : 'Filter by date',
                      style: TextStyle(
                        color: _startDate != null ? Colors.black : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isFilterActive)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () {
                _resetFilters();
                _loadTransactionsByTab(_tabController.index);
              },
              tooltip: 'Clear filters',
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _isFilterActive
                  ? 'No transactions found with the selected filters'
                  : 'No transactions found',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadTransactionsByTab(_tabController.index),
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    String status = transaction['status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'canceled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${transaction['id']?.substring(0, 8) ?? 'Unknown'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buyer: ${transaction['buyerName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seller: ${transaction['sellerName'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Date: ${_formatDate(transaction['createdAt'])}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  '\$${transaction['amount']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // View transaction details
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MM/dd/yyyy HH:mm').format(dateTime);
  }
}
