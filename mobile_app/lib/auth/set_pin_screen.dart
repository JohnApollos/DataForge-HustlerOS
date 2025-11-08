// mobile_app/lib/auth/set_pin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/main.dart'; // We'll navigate to DashboardScreen

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _enteredPin = "";
  String _confirmedPin = "";
  bool _isConfirming = false;
  final _storage = const FlutterSecureStorage();

  void _onNumberPressed(String number) {
    if (_isConfirming) {
      if (_confirmedPin.length < 4) {
        setState(() => _confirmedPin += number);
      }
    } else {
      if (_enteredPin.length < 4) {
        setState(() => _enteredPin += number);
      }
    }
  }

  void _onDeletePressed() {
    if (_isConfirming) {
      if (_confirmedPin.isNotEmpty) {
        setState(() => _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1));
      }
    } else {
      if (_enteredPin.isNotEmpty) {
        setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
      }
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_enteredPin.length < 4) return;

    if (!_isConfirming) {
      setState(() => _isConfirming = true);
      return;
    }

    // Now we are in confirmation step
    if (_confirmedPin.length < 4) return;

    if (_enteredPin == _confirmedPin) {
      // PINs match! Save it securely.
      await _storage.write(key: 'user_pin', value: _confirmedPin);

      if (mounted) {
        // Navigate to the main app dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false, // Remove all routes behind
        );
      }
    } else {
      // PINs don't match
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      // Reset the flow
      setState(() {
        _enteredPin = "";
        _confirmedPin = "";
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = _isConfirming ? _confirmedPin : _enteredPin;
    final title = _isConfirming ? 'Confirm Your PIN' : 'Create a 4-Digit PIN';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                    color: index < pin.length ? Colors.black : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
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
                    // Empty space or other button
                    return const SizedBox.shrink();
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _onConfirmPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isConfirming ? 'Confirm & Save' : 'Next',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
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