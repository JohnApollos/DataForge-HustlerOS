// mobile_app/lib/invoicing_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // We'll use this for date formatting
import 'package:mobile_app/add_invoice_screen.dart'; 

class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key});

  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  // This Future will hold our list of invoices
  late Future<List<Map<String, dynamic>>> _invoicesFuture;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _fetchInvoices();
  }

  Future<List<Map<String, dynamic>>> _fetchInvoices() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('invoices')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false); // Show newest first

    return (response as List).cast<Map<String, dynamic>>();
  }

  // Helper to get the right color for the status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: 'KSh ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invoices'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final invoices = snapshot.data;
          if (invoices == null || invoices.isEmpty) {
            return const Center(
              child: Text(
                'You have no invoices.\nTap the + button to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // We have invoices, show them in a list
          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              final totalAmount = invoice['total_amount'].toDouble();
              final amountPaid = invoice['amount_paid'].toDouble();
              final status = invoice['status'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    invoice['client_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        invoice['description'],
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Amount Due: ${_formatCurrency(totalAmount - amountPaid)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _getStatusColor(status),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This is where we'll open the "Add Invoice" screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddInvoiceScreen()),
          ).then((value) {
            // When we come back, refresh the list of invoices
            setState(() {
              _invoicesFuture = _fetchInvoices();
            });
          });
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}