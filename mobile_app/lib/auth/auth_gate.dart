// mobile_app/lib/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/auth/login_screen.dart';
import 'package:mobile_app/auth/pin_unlock_screen.dart';
import 'package:mobile_app/auth/set_pin_screen.dart';
import 'package:mobile_app/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _storage = const FlutterSecureStorage();

  // We will check two things:
  // 1. Has the user seen the one-time welcome screen?
  // 2. Does the user have a PIN saved?
  // This logic runs every time the app opens.
  Future<String> _getInitialRoute() async {
    // 1. Check for the old 'seenWelcome' flag
    final prefs = await SharedPreferences.getInstance();
    final bool seenWelcome = prefs.getBool('seenWelcome') ?? false;

    if (!seenWelcome) {
      // If they've never even seen the welcome screen, show it.
      return '/welcome';
    }

    // 2. If they HAVE seen the welcome screen, check for a user session
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged into Supabase. Show the full login screen.
      return '/login';
    }

    // 3. They are logged in. Now, check if they have a PIN saved.
    final pin = await _storage.read(key: 'user_pin');
    if (pin == null) {
      // Logged in, but no PIN. Force them to create one.
      return '/set_pin';
    } else {
      // Logged in AND have a PIN. Show the unlock screen.
      return '/pin_unlock';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getInitialRoute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a blank screen or a loading spinner
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final initialRoute = snapshot.data ?? '/welcome';

        return StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            // This stream listens for logins/logouts
            // If the user logs in on the LoginScreen, this stream
            // will fire, and we can check if they need to set a PIN.
            final session = snapshot.data?.session;

            if (session != null) {
              // User is logged in.
              // Now we do a one-time check for the PIN.
              return FutureBuilder<String?>(
                future: _storage.read(key: 'user_pin'),
                builder: (context, pinSnapshot) {
                  if (pinSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (pinSnapshot.hasData) {
                    // PIN exists, show unlock screen
                    return const PinUnlockScreen();
                  } else {
                    // No PIN, force them to set one
                    return const SetPinScreen();
                  }
                },
              );
            }

            // No session. Show the correct "logged out" screen
            // based on our initial route logic.
            if (initialRoute == '/welcome') {
              return const WelcomeScreen();
            } else {
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}