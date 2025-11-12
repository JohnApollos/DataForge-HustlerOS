// mobile_app/lib/main.dart

// 1. IMPORT ALL OUR NEW SCREENS
import 'package:mobile_app/auth/auth_gate.dart';
import 'package:mobile_app/auth/login_screen.dart';
import 'package:mobile_app/auth/pin_unlock_screen.dart';
import 'package:mobile_app/auth/set_pin_screen.dart';
import 'package:mobile_app/welcome_screen.dart';
import 'package:mobile_app/invoicing_screen.dart';

// 2. IMPORT ALL THE PACKAGES
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // We still need this for 'seenWelcome'
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'transactions_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile_app/add_transaction_screen.dart';

// 3. We must check the flag BEFORE the app runs
Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://psdmbizgatsitzlgfxxg.supabase.co', //Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzZG1iaXpnYXRzaXR6bGdmeHhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1ODUwMTMsImV4cCI6MjA3ODE2MTAxM30.loiUWYgIdE7G06cpIC04wtkf3FA1lQMGFsp2BzeBorw',
  );

  // We no longer need the 'seenWelcome' logic here.
  // The AuthGate will handle it.
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
      // 3. THE BIG CHANGE:
      // The AuthGate is now the home of our app.
      home: const AuthGate(),

      // 4. We can add "routes" so we can navigate by name
      routes: {
        '/login': (context) => const LoginScreen(),
        '/set_pin': (context) => const SetPinScreen(),
        '/pin_unlock': (context) => const PinUnlockScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// -------------------------------------------------------------------
// (DashboardScreen and InfoCard widgets are EXACTLY the same as before)
// -------------------------------------------------------------------

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
  List<dynamic> _parsedTransactions = [];
  String _selectedPeriod = "all";
  List<SmsMessage> _allSmsMessages = [];
  List<dynamic> _topExpenses = [];
  int _touchedIndex = -1;

  final Telephony telephony = Telephony.instance;

  // Function to fetch manual transactions from Supabase
  Future<List<Map<String, dynamic>>> _fetchManualTransactions(String period) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    var query = Supabase.instance.client
        .from('transactions')
        .select()
        .eq('user_id', userId);

    // Add date filter based on the period
    final now = DateTime.now();
    if (period == 'week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      query = query.gte('date', startDate.toIso8601String());
    } else if (period == 'month') {
      final startDate = DateTime(now.year, now.month, 1);
      query = query.gte('date', startDate.toIso8601String());
    }
    // For 'all', we don't add a date filter

    final response = await query;
    return (response as List).cast<Map<String, dynamic>>();
  }

  // --- NEW COMBINED DATA FUNCTION ---
  Future<void> analyzeData({String period = "all"}) async {
    setState(() {
      _isLoading = true;
      _selectedPeriod = period;
    });

    // --- 1. GET VERIFIED M-PESA DATA ---
    if (_allSmsMessages.isEmpty) {
      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted != true) {
        setState(() { _isLoading = false; });
        return;
      }
      _allSmsMessages = await telephony.getInboxSms(
        columns: [SmsColumn.BODY],
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals('MPESA'),
      );
    }
    List<String> messageBodies = _allSmsMessages.map((m) => m.body ?? '').toList();
    const String apiBaseUrl = 'https://dataforge-hustleros-production.up.railway.app/analyze';

    double mpesaIncome = 0;
    double mpesaExpenses = 0;
    List<dynamic> mpesaTransactions = [];
    List<dynamic> mpesaTopExpenses = [];

    try {
      // Get the current user's ID
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'messages': messageBodies, 'period': period, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Save the M-Pesa data
        mpesaIncome = data['hustle_score']['total_income'].toDouble();
        mpesaExpenses = data['hustle_score']['total_expenses'].toDouble();
        mpesaTransactions = data['parsed_transactions'];
        mpesaTopExpenses = data['hustle_score']['top_expenses'];

        // SET THE "VERIFIED" HUSTLE SCORE (from M-Pesa only)
        setState(() {
          _hustleScore = data['hustle_score']['score'].toString();
          _topExpenses = mpesaTopExpenses; // For now, pie chart is M-Pesa only
          _touchedIndex = -1;
        });
      }
    } catch (e) {
      // Handle M-Pesa API error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing M-Pesa: $e'), backgroundColor: Colors.red),
        );
      }
    }

    // --- 2. GET UNVERIFIED CASH DATA ---
    double manualIncome = 0;
    double manualExpenses = 0;
    List<dynamic> manualTransactions = [];

    try {
      final cashData = await _fetchManualTransactions(period);
      
      for (var tx in cashData) {
        final amount = tx['amount'].toDouble();
        if (tx['type'] == 'Income') {
          manualIncome += amount;
        } else {
          manualExpenses += amount;
        }
        // Convert manual transaction to the same format as M-Pesa transactions
        manualTransactions.add({
          'name': tx['category'], // Use category as name
          'description': tx['description'] ?? '',
          'amount': amount,
          'date': tx['date'], // This is already an ISO 8601 string
          'type': tx['type']
        });
      }
    } catch (e) {
      // Handle Supabase error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching cash data: $e'), backgroundColor: Colors.red),
        );
      }
    }

    // --- 3. COMBINE ALL DATA AND UPDATE STATE ---
    
    // Combine and sort all transactions for the "View All" screen
    final allTransactions = [...mpesaTransactions, ...manualTransactions];
    
    // --- THIS IS THE FIX ---
    // This sort function is now "null-safe" and will not crash
    allTransactions.sort((a, b) {
      // Handle potential null or invalid dates
      // DateTime.tryParse returns null if it fails (doesn't crash)
      // We use `?? DateTime(1970)` to provide a default "old" date for any nulls
      final DateTime dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
      final DateTime dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // Sort descending
    });
    // --- END OF FIX ---

    setState(() {
      // Set the new combined totals
      _totalIncome = (mpesaIncome + manualIncome).toStringAsFixed(0);
      _totalExpenses = (mpesaExpenses + manualExpenses).toStringAsFixed(0);
      
      // Save the combined list of transactions
      _parsedTransactions = allTransactions; 
      
      _isLoading = false;
    });
  }

  void _openTransactionsPage() {
    if (_parsedTransactions.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionsScreen(
            transactions: _parsedTransactions,
            period: _selectedPeriod,
          ),
        ),
      );
    }
  }
  
  String _shortenName(String name) {
    if (name.length > 15) {
      return "${name.substring(0, 12)}...";
    }
    return name;
  }

  // --- HELPER FUNCTION FOR THE AI TIP ---
  String _getInsightTip() {
    // Try to parse the score, default to 50 if it's "--"
    final int score = int.tryParse(_hustleScore) ?? 50;

    if (score > 55) {
      return "You're in the green! Your income is healthy. Keep up the great hustle.";
    } else if (score < 45) {
      return "Warning: Your expenses are higher than your income. Tap the pie chart to see where your money is going.";
    } else if (score == 50 && _totalIncome == "0") {
      return "Tap 'Analyze' to scan your M-Pesa messages and see your score.";
    } else {
      return "You're breaking even. Try to increase your income or reduce non-essential expenses.";
    }
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Hustler OS Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),

        actions: [
          // --- ADD THIS NEW BUTTON ---
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'View Invoices',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvoicingScreen()),
              );
            },
          ),
          // --- END OF NEW BUTTON ---

          IconButton(
            icon: const Icon(Icons.add_card_outlined),
            tooltip: 'Add cash transaction',
            onPressed: () {
              // This opens our new screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              SizedBox(
                height: 40,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Week')),
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'all', label: Text('All Time')),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    // --- CHANGED ---
                    analyzeData(period: newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('Your Hustle Score', style: TextStyle(fontSize: 18, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text(
                        _hustleScore,
                        style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.green),
                      ),

                      // --- AI INSIGHT WIDGET ---
                      if (_hustleScore != "--") ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          _getInsightTip(), // Get the dynamic tip
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      // ---------------------------------
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: InfoCard(title: 'Total Income', amount: 'KSh $_totalIncome', color: Colors.green, icon: Icons.arrow_upward)),
                  const SizedBox(width: 16),
                  Expanded(child: InfoCard(title: 'Total Expenses', amount: 'KSh $_totalExpenses', color: Colors.red, icon: Icons.arrow_downward)),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_topExpenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Top 5 Expenses (from M-Pesa)', // Clarified title
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: _buildPieChartSections(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: List.generate(_topExpenses.length, (index) {
                    final isTouched = index == _touchedIndex;
                    final expense = _topExpenses[index];
                    final colors = [Colors.red, Colors.orange, Colors.blue, Colors.teal, Colors.purple];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _touchedIndex = isTouched ? -1 : index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors[index % colors.length].withOpacity(isTouched ? 1.0 : 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isTouched ? Colors.black : Colors.transparent,
                            width: isTouched ? 2 : 0,
                          ),
                        ),
                        child: Text(
                          '${_shortenName(expense['name'])} (KSh ${expense['amount'].toStringAsFixed(0)})',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              
              TextButton(
                onPressed: _openTransactionsPage,
                child: const Text(
                  'View All Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: const Color(0xFFF0F2F5),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sms),
                // --- CHANGED ---
                label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Analyze Data'),
                // --- CHANGED ---
                onPressed: _isLoading ? () {} : () => analyzeData(period: 'all'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    const colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.grey,
    ];
    
    final total = _topExpenses.fold(0.0, (sum, item) => sum + item['amount']);
    if (total == 0) return []; // Avoid division by zero

    return List.generate(_topExpenses.length, (index) {
      final isTouched = index == _touchedIndex;
      final expense = _topExpenses[index];
      final percentage = (expense['amount'] / total) * 100;
      final double radius = isTouched ? 90 : 80;
      final double fontSize = isTouched ? 16 : 14;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: expense['amount'],
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    });
  }
}

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
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}