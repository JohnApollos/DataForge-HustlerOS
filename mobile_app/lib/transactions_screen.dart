// mobile_app/lib/transactions_screen.dart
import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  // We will pass the list of transactions to this screen
  final List<dynamic> transactions;

  const TransactionsScreen({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Filter out any items that aren't parsed transactions (like "unknown" types)
    final parsedList = transactions.where((tx) => tx['type'] != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: parsedList.length,
        itemBuilder: (context, index) {
          final tx = parsedList[index];
          final type = tx['type'] ?? 'Unknown';

          // Determine color and icon based on transaction type
          final isCredit = type == 'Credit';
          final color = isCredit ? Colors.green : Colors.red;
          final icon = isCredit ? Icons.arrow_upward : Icons.arrow_downward;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                tx['party'] ?? 'Unknown Transaction',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(type, style: TextStyle(color: Colors.grey[600])),
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
