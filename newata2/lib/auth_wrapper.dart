import 'package:CCTV_App/login_page.dart';
import 'package:CCTV_App/main.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =================================================================
// AUTH & ROUTING
// =================================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Tampilkan loading spinner selagi menunggu event auth pertama.
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Sesuai alur aplikasi, selalu mulai dari LoginPage untuk meminta Device ID,
        // terlepas dari status sesi sebelumnya.
        return const LoginPage();
      },
    );
  }
}
