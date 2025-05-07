// screens/splash_screen.dart (Sudah Lengkap)
import 'package:CCTV_App/main.dart';
import 'package:flutter/material.dart';


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print("SplashScreen: initState called.");
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    print("SplashScreen: Starting redirection check...");

    try {
      final session = supabase.auth.currentSession;
      print("SplashScreen: Current session: ${session?.user.id ?? 'null'}");

      if (session != null) {
        print("SplashScreen: Session found, redirecting to /dashboard");
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        print("SplashScreen: No session found, redirecting to /login");
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print("SplashScreen: Error during redirection check: $e");
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    print("SplashScreen: Building UI.");
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 20),
            Text("Memuat...", style: TextStyle(color: Colors.teal)),
          ],
        ),
      ),
    );
  }
}
