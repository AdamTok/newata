// screens/dashboard_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Pastikan path benar
import 'footage_screen.dart'; // Pastikan path benar
import 'control_screen.dart'; // Pastikan path benar

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const FootageScreen(),
    const ControlScreen(),
  ];

  void _onItemTapped(int index) {
    print("DashboardScreen: Tab tapped, index: $index");
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("DashboardScreen: Building UI.");
    // Gunakan watch agar UI rebuild jika user berubah (meski tidak mungkin di screen ini)
    final userIdentifier =
        context.watch<AuthProvider>().currentUser?.email ?? 'Pengguna';
    print("DashboardScreen: Current user identifier: $userIdentifier");

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, $userIdentifier!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              print("DashboardScreen: Logout button pressed.");
              await context.read<AuthProvider>().signOut();
              if (mounted && context.read<AuthProvider>().currentUser == null) {
                print(
                    "DashboardScreen: User is null after sign out, navigating to /login");
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        // Pertahankan state tiap halaman saat ganti tab
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Tipe agar label selalu terlihat
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            activeIcon: Icon(Icons.video_library),
            label: 'Footage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote_outlined),
            activeIcon: Icon(Icons.settings_remote),
            label: 'Kontrol Alat',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
