import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all transactions
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('transactions').get();
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting all transactions: $e');
      return [];
    }
  }

  // Get transactions by status (pending, completed, canceled)
  Future<List<Map<String, dynamic>>> getTransactionsByStatus(String status) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .where('status', isEqualTo: status)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting transactions by status: $e');
      return [];
    }
  }

  // Get transactions by date range
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      // Add one day to end date to include the whole end date
      DateTime endDatePlusOne = endDate.add(const Duration(days: 1));
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThan: endDatePlusOne)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting transactions by date range: $e');
      return [];
    }
  }

  // Get transactions by user
  Future<List<Map<String, dynamic>>> getTransactionsByUser(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting transactions by user: $e');
      return [];
    }
  }
  // Get transaction stats
  Future<Map<String, int>> getTransactionStats() async {
    try {
      AggregateQuerySnapshot totalSnapshot = await _firestore.collection('transactions').count().get();
      AggregateQuerySnapshot completedSnapshot = await _firestore
          .collection('transactions')
          .where('status', isEqualTo: 'completed')
          .count()
          .get();
      
      // Handle potentially nullable counts with null-aware operators
      int totalTransactions = totalSnapshot.count ?? 0;
      int completedTransactions = completedSnapshot.count ?? 0;
      
      return {
        'totalTransactions': totalTransactions,
        'completedTransactions': completedTransactions,
      };
    } catch (e) {
      print('Error getting transaction stats: $e');
      return {
        'totalTransactions': 0,
        'completedTransactions': 0,
      };
    }
  }
  // Get weekly transaction activity (for graph)
  Future<Map<String, double>> getWeeklyTransactionActivity() async {
    try {
      // Get current date
      DateTime now = DateTime.now();
      
      // Create a map to store data for the last 7 days
      Map<String, double> weeklyActivity = {};
      
      // Populate map with last 7 days (including today)
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        String dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        weeklyActivity[dateString] = 0.0;
      }
      
      // Query transactions created in the last 7 days
      DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      QuerySnapshot querySnapshot = await _firestore
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();
          
      // Sum transaction amounts by day
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['createdAt'] != null) {
          DateTime createdAt = data['createdAt'].toDate();
          String dateString = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          // Safely convert to double, handling various types
          double amount = 0.0;
          var rawAmount = data['amount'];
          if (rawAmount is int) {
            amount = rawAmount.toDouble();
          } else if (rawAmount is double) {
            amount = rawAmount;
          } else if (rawAmount != null) {
            amount = double.tryParse(rawAmount.toString()) ?? 0.0;
          }
          
          if (weeklyActivity.containsKey(dateString)) {
            weeklyActivity[dateString] = weeklyActivity[dateString]! + amount;
          }
        }
      }
      
      return weeklyActivity;
    } catch (e) {
      print('Error getting weekly transaction activity: $e');
      return {};
    }
  }
}
