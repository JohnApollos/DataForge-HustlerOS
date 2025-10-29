// mobile_app/lib/main.dart - (NOW WITH TRANSACTION LIST)
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'transactions_screen.dart'; // <-- 1. IMPORT OUR NEW SCREEN

void main() {
  runApp(const HustlerOSApp());
}

class HustlerOSApp extends StatelessWidget {
  const HustlerOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hustler OS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _hustleScore = "--";
  String _totalIncome = "0";
  String _totalExpenses = "0";
  bool _isLoading = false;

  // 2. CREATE A VARIABLE TO HOLD OUR TRANSACTIONS
  List<dynamic> _parsedTransactions = [];

  final Telephony telephony = Telephony.instance;

  Future<void> analyzeSms() async {
    setState(() {
      _isLoading = true;
      _parsedTransactions = []; // Clear old list
    });

    bool? permissionsGranted = await telephony.requestSmsPermissions;
    if (permissionsGranted != true) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    List<SmsMessage> messages = await telephony.getInboxSms(
      columns: [SmsColumn.BODY],
      filter: SmsFilter.where(SmsColumn.ADDRESS).equals('MPESA'),
    );

    List<String> messageBodies = messages.map((m) => m.body ?? '').toList();

    // -- Make sure to update your IP here --
    const String apiBaseUrl = 'http://192.168.1.106:8000/analyze';

    try {
      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'messages': messageBodies}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _hustleScore = data['hustle_score']['score'].toString();
          _totalIncome = data['hustle_score']['total_income'].toStringAsFixed(
            0,
          );
          _totalExpenses = data['hustle_score']['total_expenses']
              .toStringAsFixed(0);

          // 3. SAVE THE FULL LIST FROM THE API RESPONSE
          _parsedTransactions = data['parsed_transactions'];
        });
      }
    } catch (e) {
      print('Error calling API: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 4. FUNCTION TO OPEN THE NEW SCREEN
  void _openTransactionsPage() {
    // Only navigate if we have transactions to show
    if (_parsedTransactions.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionsScreen(transactions: _parsedTransactions),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Hustler OS Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ... (Hustle Score Card is the same) ...
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'Your Hustle Score',
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hustleScore,
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ... (Income/Expense Row is the same) ...
            Row(
              children: [
                Expanded(
                  child: InfoCard(
                    title: 'Total Income',
                    amount: 'KSh $_totalIncome',
                    color: Colors.green,
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InfoCard(
                    title: 'Total Expenses',
                    amount: 'KSh $_totalExpenses',
                    color: Colors.red,
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. ADD THE NEW "VIEW TRANSACTIONS" BUTTON
            TextButton(
              onPressed: _openTransactionsPage,
              child: const Text(
                'View All Transactions',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.sms),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Analyze M-Pesa SMS'),
              onPressed: _isLoading ? null : analyzeSms,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ... (InfoCard widget is the same) ...
class InfoCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
