// mobile_app/lib/transactions_screen.dart
import 'package:flutter/material.dart'; // <-- TYPO FIXED HERE
import 'package:intl/intl.dart'; // We need this package to format dates

class TransactionsScreen extends StatelessWidget {
  final List<dynamic> transactions;
  final String period; // 'all', 'month', 'week'

  const TransactionsScreen({
    super.key,
    required this.transactions,
    required this.period,
  });

  // --- NEW: Helper function to parse date string ---
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  // --- NEW: Helper function to format date for display ---
  String _formatDate(DateTime? date) {
    if (date == null) return "No date";
    // Format to "28 Oct, 8:01 AM"
    return DateFormat('d MMM, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    
    // --- NEW: Filter the list based on the period ---
    DateTime? startDate;
    if (period == "week") {
      startDate = DateTime.now().subtract(const Duration(days: 7));
    } else if (period == "month") {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    }

    final filteredList = transactions.where((tx) {
      final txType = tx['type'];
      final txDate = _parseDate(tx['date']);
      
      // Basic filter: must have a type and a date
      if (txType == null || txDate == null) return false;

      // Date filter: if a start date is set, check it
      if (startDate != null && txDate.isBefore(startDate)) {
        return false;
      }
      
      return true; // Keep the transaction
    }).toList();
    
    // Sort the filtered list by date, newest first
    filteredList.sort((a, b) => _parseDate(b['date'])!.compareTo(_parseDate(a['date'])!));
    // ---------------------------------------------

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtered Transactions'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final tx = filteredList[index];
          final type = tx['type']!;
          
          final isCredit = type == 'Credit';
          final color = isCredit ? Colors.green : Colors.red;
          final icon = isCredit ? Icons.arrow_upward : Icons.arrow_downward;
          
          final date = _parseDate(tx['date']);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                tx['party'] ?? 'Unknown Transaction',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              // --- MODIFIED: Show the formatted date ---
              subtitle: Text(
                _formatDate(date),
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Text(
                'KSh ${tx['amount'] ?? 0}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}