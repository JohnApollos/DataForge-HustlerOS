// mobile_app/lib/main.dart - (FINAL VERSION - With Improved Pie Chart Labels)
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'transactions_screen.dart'; // Import transactions screen
import 'package:fl_chart/fl_chart.dart'; // IMPORT PIE CHART

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
  List<dynamic> _parsedTransactions = [];
  String _selectedPeriod = "all";
  List<SmsMessage> _allSmsMessages = [];
  List<dynamic> _topExpenses = [];

  // --- NEW: For interactive pie chart to show details on touch ---
  int _touchedIndex = -1;
  // -------------------------------------------------------------

  final Telephony telephony = Telephony.instance;

  Future<void> analyzeSms({String period = "all"}) async {
    setState(() {
      _isLoading = true;
      _selectedPeriod = period;
    });

    if (_allSmsMessages.isEmpty) {
      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted != true) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      _allSmsMessages = await telephony.getInboxSms(
        columns: [SmsColumn.BODY],
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals('MPESA'),
      );
    }

    List<String> messageBodies = _allSmsMessages
        .map((m) => m.body ?? '')
        .toList();

    // -- Make sure to update your IP here --
    const String apiBaseUrl =
        'https://dataforge-hustleros-production.up.railway.app/analyze';

    try {
      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'messages': messageBodies, 'period': period}),
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
          _parsedTransactions = data['parsed_transactions'];
          _topExpenses = data['hustle_score']['top_expenses'];
          _touchedIndex = -1; // Reset touched index when new data loads
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

  // Helper to shorten long names for labels
  String _shortenName(String name) {
    if (name.length > 15) {
      return "${name.substring(0, 12)}...";
    }
    return name;
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
                    analyzeSms(period: newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 24),
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

              if (_topExpenses.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Top 5 Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250, // Increased height for better spacing
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        // <-- NEW: For interactivity
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      sections: _buildPieChartSections(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                // --- NEW: Legend for categories ---
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: List.generate(_topExpenses.length, (index) {
                    final isTouched = index == _touchedIndex;
                    final expense = _topExpenses[index];
                    final colors = [
                      Colors.red,
                      Colors.orange,
                      Colors.blue,
                      Colors.teal,
                      Colors.purple,
                    ];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _touchedIndex = isTouched ? -1 : index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors[index % colors.length].withOpacity(
                            isTouched ? 1.0 : 0.7,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isTouched
                                ? Colors.black
                                : Colors.transparent,
                            width: isTouched ? 2 : 0,
                          ),
                        ),
                        child: Text(
                          '${_shortenName(expense['name'])} (KSh ${expense['amount'].toStringAsFixed(0)})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                // ---------------------------------
              ],

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
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Analyze M-Pesa SMS'),
                onPressed: _isLoading ? () {} : () => analyzeSms(period: 'all'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
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
      Colors.grey, // Added for 'Other' if needed
    ];

    final total = _topExpenses.fold(0.0, (sum, item) => sum + item['amount']);

    return List.generate(_topExpenses.length, (index) {
      final isTouched = index == _touchedIndex;
      final expense = _topExpenses[index];
      final percentage = (expense['amount'] / total) * 100;
      final double radius = isTouched ? 90 : 80; // Make touched slice bigger
      final double fontSize = isTouched ? 16 : 14;

      // Only show percentage on the slice, names in the legend
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
        // No badgeWidget here, we'll use a separate legend
        // badgeWidget: Text(_shortenName(expense['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
        // badgePositionPercentageOffset: 1.1, // Adjusted offset
      );
    });
  }
}

// InfoCard widget (unchanged)
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
