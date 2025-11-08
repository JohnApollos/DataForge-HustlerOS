// mobile_app/lib/auth/pin_unlock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/main.dart'; // To Dashboard
import 'package:mobile_app/auth/login_screen.dart'; // To Login
import 'package:supabase_flutter/supabase_flutter.dart'; // For logging out

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _enteredPin = "";
  final _storage = const FlutterSecureStorage();
  int _failedAttempts = 0;
  bool _isChecking = false;

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += number);
      if (_enteredPin.length == 4) {
        _checkPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _checkPin() async {
    setState(() => _isChecking = true);
    final savedPin = await _storage.read(key: 'user_pin');

    if (savedPin == _enteredPin) {
      // Success!
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false, // Remove all routes behind
        );
      }
    } else {
      // Failure
      setState(() {
        _failedAttempts++;
        _enteredPin = "";
        _isChecking = false;
      });

      if (_failedAttempts >= 3) {
        // Too many attempts. Log them out.
        await _storage.delete(key: 'user_pin');
        if (mounted) {
          // Send to full login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(bodyKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Too many attempts. Please sign in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Show "wrong PIN" error
        ScaffoldMessenger.of(bodyKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Wrong PIN. ${3 - _failedAttempts} attempts left.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // A key to show SnackBars from async methods
  final bodyKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: bodyKey,
      appBar: AppBar(
        title: const Text('Unlock Hustler OS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Your 4-Digit PIN',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: index < _enteredPin.length ? Colors.black : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            if (_isChecking) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: 48),
            // Numpad
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index < 9) {
                    return _buildNumberButton('${index + 1}');
                  } else if (index == 10) {
                    return _buildNumberButton('0');
                  } else if (index == 9) {
                    // "Forgot PIN" button
                    return TextButton(
                      onPressed: _forgotPin,
                      child: const Text(
                        'Forgot PIN?',
                        style: TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    );
                  } else {
                    // Backspace/Delete
                    return _buildActionButton(
                      icon: Icons.backspace,
                      onPressed: _onDeletePressed,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forgotPin() async {
    // Log them out fully
    await _storage.delete(key: 'user_pin');
    // We also need to log them out of Supabase
    await Supabase.instance.client.auth.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(bodyKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('PIN reset. Please sign in to set a new one.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Widget _buildNumberButton(String number) {
    return OutlinedButton(
      onPressed: () => _onNumberPressed(number),
      style: OutlinedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(
        number,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      color: Colors.black,
    );
  }
}