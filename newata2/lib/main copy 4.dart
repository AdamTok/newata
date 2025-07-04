import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// =================================================================
// MAIN.DART & SETUP
// =================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await initializeDateFormatting('id_ID', null);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MyApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Security Monitor',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.tealAccent,
        scaffoldBackgroundColor: const Color(0xFF1a1a1a),
        cardColor: const Color(0xFF2c2c2c),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
          surface: Color(0xFF2c2c2c),
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            labelStyle: const TextStyle(color: Colors.white54)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

class AppState extends ChangeNotifier {
  // State variables
  bool _isLoading = false;
  String? _deviceId;
  List<Map<String, dynamic>> _events = [];
  // PENYESUAIAN: Nama variabel diubah agar lebih jelas
  Map<String, dynamic>? _scheduleStatus;
  User? _currentUser;

  // Realtime channel subscriptions
  RealtimeChannel? _sensorEventsChannel;
  RealtimeChannel? _scheduleStatusChannel; // PENYESUAIAN: Nama channel diubah

  // Getters
  bool get isLoading => _isLoading;
  String? get deviceId => _deviceId;
  List<Map<String, dynamic>> get events => _events;
  // PENYESUAIAN: Nama getter diubah
  Map<String, dynamic>? get scheduleStatus => _scheduleStatus;
  User? get currentUser => _currentUser;

  // Constructor
  AppState() {
    _currentUser = supabase.auth.currentUser;
    supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      if (_currentUser == null) {
        clearState();
      }
      notifyListeners();
    });
  }

  void _unsubscribeFromChannels() {
    if (_sensorEventsChannel != null) {
      supabase.removeChannel(_sensorEventsChannel!);
      _sensorEventsChannel = null;
    }
    // PENYESUAIAN: Channel yang di-unsubscribe disesuaikan
    if (_scheduleStatusChannel != null) {
      supabase.removeChannel(_scheduleStatusChannel!);
      _scheduleStatusChannel = null;
    }
  }

  void clearState() {
    _deviceId = null;
    _events.clear();
    _scheduleStatus = null;
    _unsubscribeFromChannels();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // PENYESUAIAN: Fungsi ini sekarang menangani validasi device ID
  // dan mengembalikan boolean yang menandakan keberhasilan.
  Future<bool> setDeviceIdAndFetchData(String deviceId) async {
    // FITUR BARU: Validasi Device ID
    try {
      final response = await supabase
          .from('devices')
          .select('id')
          .eq('id', deviceId)
          .maybeSingle(); // maybeSingle() mengembalikan null jika tidak ditemukan

      if (response == null) {
        return false; // Device ID tidak valid
      }

      // Jika valid, lanjutkan seperti biasa
      _deviceId = deviceId;
      await fetchInitialData();
      _listenToRealtimeChanges();
      notifyListeners();
      return true; // Sukses
    } catch (e) {
      print('Error validating device ID: $e');
      return false;
    }
  }

  Future<void> fetchInitialData() async {
    if (_deviceId == null) return;
    _setLoading(true);
    await Future.wait([
      fetchEvents(),
      fetchScheduleStatus(), // PENYESUAIAN: Nama fungsi diubah
    ]);
    _setLoading(false);
  }

  Future<void> fetchEvents() async {
    if (_deviceId == null) return;
    try {
      final response = await supabase
          .from('sensor_events')
          .select()
          .eq('device_id', _deviceId!)
          .order('created_at', ascending: false); // Kolom diubah ke created_at
      _events = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching events: $e');
      _events = [];
    }
    notifyListeners();
  }

  // PENYESUAIAN: Nama fungsi diubah dan logika disederhanakan
  Future<void> fetchScheduleStatus() async {
    try {
      // Mengambil dari tabel 'device_schedules' dengan id=1
      final response = await supabase
          .from('device_schedules')
          .select()
          .eq('id', 1)
          .single();
      _scheduleStatus = response;
    } catch (e) {
      print('Error fetching schedule status: $e');
      _scheduleStatus = null;
    }
    notifyListeners();
  }
  
  // DIHAPUS: Fungsi fetchSetterUserDetails tidak lagi diperlukan
  // karena nama sudah ada di tabel device_schedules.

  void _listenToRealtimeChanges() {
    if (_deviceId == null) return;
    _unsubscribeFromChannels();

    // Channel untuk sensor_events tetap sama
    _sensorEventsChannel = supabase.channel('public:sensor_events');
    _sensorEventsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sensor_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: _deviceId!,
          ),
          callback: (payload) {
            final newEvent = payload.newRecord;
            if (!_events.any((e) => e['id'] == newEvent['id'])) {
              _events.insert(0, newEvent);
              notifyListeners();
            }
          },
        )
        .subscribe();
    
    // PENYESUAIAN: Channel untuk mendengarkan perubahan jadwal
    _scheduleStatusChannel = supabase.channel('public:device_schedules');
    _scheduleStatusChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update, // Cukup dengarkan UPDATE
          schema: 'public',
          table: 'device_schedules',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id', // Filter berdasarkan ID baris
            value: 1,      // Hanya baris dengan id=1
          ),
          callback: (payload) {
            // Logika disederhanakan, langsung update status
            _scheduleStatus = payload.newRecord;
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> signOut() async {
    _setLoading(true);
    await supabase.auth.signOut();
    // clearState() akan dipanggil otomatis oleh listener onAuthStateChange
    _setLoading(false);
  }

  // PENYESUAIAN: Fungsi ini sekarang mengirim nama lengkap pengguna
  Future<String?> setSleepSchedule(int durationMicroseconds) async {
    if (_currentUser == null) {
      return "User not identified.";
    }
    _setLoading(true);
    
    final fullName = _currentUser!.userMetadata?['full_name'] ?? 'Unknown User';

    try {
      // Update tabel 'device_schedules' baris id=1
      await supabase.from('device_schedules').update({
        'schedule_duration_microseconds': durationMicroseconds,
        'setter_user_id': _currentUser!.id,
        'setter_full_name': fullName, // FITUR BARU: Kirim nama lengkap
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      
      _setLoading(false);
      return null;
    } on PostgrestException catch (e) {
      _setLoading(false);
      print('Error setting sleep schedule: ${e.message}');
      return e.message;
    } catch (e) {
      _setLoading(false);
      print('Generic error setting sleep schedule: $e');
      return 'An unexpected error occurred.';
    }
  }
}

// =================================================================
// SPLASH SCREEN, AUTH WRAPPER, REGISTER PAGE (Tidak ada perubahan signifikan)
// =================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      final session = supabase.auth.currentSession;
      final deviceId = Provider.of<AppState>(context, listen: false).deviceId;

      // Jika ada sesi DAN deviceId sudah di-set, langsung ke Dashboard
      if (session != null && deviceId != null && deviceId.isNotEmpty) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()));
      } else {
        // Jika tidak, ke halaman login
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.lock_shield_fill,
                size: 120, color: Colors.tealAccent),
            SizedBox(height: 24),
            Text('Security Monitor',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 80),
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    // Disederhanakan: Logika redirect kini ditangani di SplashScreen dan LoginPage
    // AuthWrapper bisa dihapus atau disederhanakan jika mau,
    // tapi kita biarkan untuk potensi routing di masa depan.
    final appState = Provider.of<AppState>(context);
    if (appState.currentUser != null && appState.deviceId != null) {
      return const DashboardPage();
    } else {
      return const LoginPage();
    }
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'full_name': _fullNameController.text.trim()},
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Registrasi berhasil! Silakan periksa email Anda untuk verifikasi dan kemudian login.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      } on AuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(CupertinoIcons.person_add_solid,
                    size: 80, color: Colors.tealAccent),
                const SizedBox(height: 16),
                const Text('Buat Akun Baru',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (value) =>
                      value!.isEmpty ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.isEmpty ? 'Email tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) =>
                      value!.length < 6 ? 'Password minimal 6 karakter' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ))
                      : const Text('Register',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================
// LOGIN PAGE
// =================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // PENYESUAIAN: Logika sign in diubah total untuk validasi Device ID
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Coba login dengan email dan password
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) {
        // Ini seharusnya tidak terjadi jika tidak ada AuthException, tapi sebagai penjaga
        throw 'Login failed unexpectedly.';
      }

      // 2. Jika login berhasil, validasi Device ID
      final appState = Provider.of<AppState>(context, listen: false);
      final deviceIdIsValid = await appState.setDeviceIdAndFetchData(
        _deviceIdController.text.trim()
      );

      if (!mounted) return;

      if (deviceIdIsValid) {
        // 3. Jika Device ID valid, navigasi ke Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        // 4. Jika Device ID TIDAK valid, tampilkan error dan logout lagi
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Login berhasil, tetapi Device ID tidak ditemukan.'),
          backgroundColor: Colors.orange,
        ));
        await supabase.auth.signOut(); // Logout untuk mencegah state aneh
      }

    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.redAccent,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Terjadi kesalahan: ${e.toString()}'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(CupertinoIcons.shield_lefthalf_fill,
                    size: 80, color: Colors.tealAccent),
                const SizedBox(height: 16),
                const Text('Security Monitor',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.isEmpty ? 'Email tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) =>
                      value!.isEmpty ? 'Password tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _deviceIdController,
                  decoration: const InputDecoration(labelText: 'Device ID'),
                  validator: (value) =>
                      value!.isEmpty ? 'Device ID tidak boleh kosong' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ))
                      : const Text('Login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterPage())),
                  child: const Text('Belum punya akun? Daftar sekarang',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// =================================================================
// DASHBOARD PAGE & COMPONENTS
// =================================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Consumer<AppState>(
              builder: (context, appState, child) {
                if (appState.isLoading && appState.events.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  onRefresh: Provider.of<AppState>(context, listen: false)
                      .fetchInitialData,
                  color: Colors.tealAccent,
                  backgroundColor: const Color(0xFF2c2c2c),
                  child: const CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: ProfileBar()),
                      SliverToBoxAdapter(child: SettingsBar()),
                      SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                          child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text("Footage Gallery",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                      )),
                      SliverToBoxAdapter(child: SizedBox(height: 10)),
                      FootageGallery(),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Consumer<AppState>(
                builder: (context, appState, child) {
                  return Visibility(
                    visible: appState.isLoading,
                    child: const LinearProgressIndicator(
                      color: Colors.tealAccent,
                      backgroundColor: Colors.transparent,
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ProfileBar extends StatelessWidget {
  const ProfileBar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fullName = user?.userMetadata?['full_name'] ?? 'No Name';
    final email = user?.email ?? 'No Email';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(email,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () {
              Provider.of<AppState>(context, listen: false).signOut();
              // Navigasi kembali ke LoginPage setelah logout
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          )
        ],
      ),
    );
  }
}


class SettingsBar extends StatelessWidget {
  const SettingsBar({super.key});

  void _showSetTimerDialog(BuildContext context, AppState appState) async {
    final now = DateTime.now();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (pickedTime != null) {
      DateTime scheduledTime = DateTime(
          now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final duration = scheduledTime.difference(now);
      // ESP32-CAM menggunakan mikrodetik untuk deep sleep
      final durationMicroseconds = duration.inMicroseconds;

      final error = await appState.setSleepSchedule(durationMicroseconds);

      if (context.mounted) {
        if (error == null) {
          final formattedTime = DateFormat.jm('id_ID').format(scheduledTime);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Jadwal deep sleep diatur hingga $formattedTime'),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal mengatur jadwal: $error'),
            backgroundColor: Colors.redAccent,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // PENYESUAIAN: Mengambil data dari 'scheduleStatus'
        final status = appState.scheduleStatus;
        final deviceId = appState.deviceId ?? 'N/A';

        if (status == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
                child: Text("Mencari status perangkat...",
                    style: TextStyle(color: Colors.white24))),
          );
        }
        
        // Asumsi perangkat online jika aplikasi bisa mengambil data.
        // Logika status on/off bisa dibuat lebih kompleks jika diperlukan.
        final bool isOnline = true; 
        
        // FITUR BARU: Mengambil nama dari kolom baru 'setter_full_name'
        final String setterName = status['setter_full_name'] ?? 'Belum pernah diatur';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device: $deviceId',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle,
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              size: 12),
                          const SizedBox(width: 8),
                          Text(isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // PENYESUAIAN: Menampilkan nama setter
                      Text(
                        'Last Setter: $setterName',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isOnline
                      ? () => _showSetTimerDialog(context, appState)
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3)),
                  child: const Text('Set Timer'),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class FootageGallery extends StatelessWidget {
  const FootageGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final events = appState.events;
        if (events.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.photo_on_rectangle,
                        size: 60, color: Colors.white24),
                    SizedBox(height: 16),
                    Text('Belum ada tangkapan',
                        style: TextStyle(color: Colors.white24, fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final event = events[index];
              return FootageCard(event: event);
            },
            childCount: events.length,
          ),
        );
      },
    );
  }
}

class FootageCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const FootageCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final imageUrl = event['image_ref'] ?? '';
    final location = event['location_name'] ?? 'Unknown Location';
    final eventType = event['event_type'] ?? 'Unknown Event';
    
    // PENYESUAIAN: Menggunakan kolom 'created_at' yang pasti ada
    final timestampString = event['created_at'] ?? DateTime.now().toIso8601String();
    final timestamp = DateTime.parse(timestampString);
    
    final formattedTime = DateFormat('EEEE, dd MMMM yyyy, HH:mm:ss', 'id_ID')
        .format(timestamp.toLocal());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 250,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    color: Colors.black12,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.tealAccent,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.black12,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle,
                            color: Colors.redAccent, size: 50),
                        SizedBox(height: 8),
                        Text("Gagal memuat gambar",
                            style: TextStyle(color: Colors.white70))
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: eventType == 'GERAKAN'
                            ? Colors.orange.shade800
                            : Colors.purple.shade800,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      eventType,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.location_solid,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(location,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.time_solid,
                          size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(formattedTime,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}























// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:intl/intl.dart';
// import 'package:intl/date_symbol_data_local.dart'; // <-- IMPORT PENTING
// import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'dart:async';

// // =================================================================
// // MAIN.DART & SETUP
// // =================================================================

// Future<void> main() async {
//   // Pastikan semua binding Flutter siap sebelum menjalankan kode async
//   WidgetsFlutterBinding.ensureInitialized();

//   // Muat environment variables dari file .env
//   await dotenv.load(fileName: ".env");

//   // Inisialisasi Supabase
//   await Supabase.initialize(
//     url: dotenv.env['SUPABASE_URL']!,
//     anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
//   );

//   // =================================================================
//   // PERBAIKAN UTAMA: Inisialisasi locale untuk package 'intl'
//   // Ini akan memuat data format tanggal untuk Bahasa Indonesia ('id_ID').
//   // Panggilan ini sangat penting untuk mencegah LocaleDataException.
//   // =================================================================
//   await initializeDateFormatting('id_ID', null);

//   runApp(
//     ChangeNotifierProvider(
//       create: (context) => AppState(),
//       child: const MyApp(),
//     ),
//   );
// }

// // Global Supabase client
// final supabase = Supabase.instance.client;

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Security Monitor',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primaryColor: Colors.tealAccent,
//         scaffoldBackgroundColor: const Color(0xFF1a1a1a),
//         cardColor: const Color(0xFF2c2c2c),
//         colorScheme: const ColorScheme.dark(
//           primary: Colors.tealAccent,
//           secondary: Colors.teal,
//           surface: Color(0xFF2c2c2c),
//           onSurface: Colors.white,
//         ),
//         textTheme: const TextTheme(
//           bodyLarge: TextStyle(color: Colors.white70),
//           bodyMedium: TextStyle(color: Colors.white70),
//           titleLarge:
//               TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           titleMedium: TextStyle(color: Colors.white),
//         ),
//         inputDecorationTheme: InputDecorationTheme(
//             filled: true,
//             fillColor: Colors.black.withOpacity(0.3),
//             border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none),
//             labelStyle: const TextStyle(color: Colors.white54)),
//         useMaterial3: true,
//       ),
//       // Set SplashScreen sebagai halaman awal
//       home: const SplashScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// // =================================================================
// // STATE MANAGEMENT (PROVIDER)
// // =================================================================

// class AppState extends ChangeNotifier {
//   // State variables
//   bool _isLoading = false;
//   String? _deviceId;
//   List<Map<String, dynamic>> _events = [];
//   Map<String, dynamic>? _deviceStatus;
//   User? _currentUser;
//   Map<String, dynamic>? _setterUserDetails;

//   // Realtime channel subscriptions
//   RealtimeChannel? _sensorEventsChannel;
//   RealtimeChannel? _deviceStatusChannel;

//   // Getters
//   bool get isLoading => _isLoading;
//   String? get deviceId => _deviceId;
//   List<Map<String, dynamic>> get events => _events;
//   Map<String, dynamic>? get deviceStatus => _deviceStatus;
//   User? get currentUser => _currentUser;
//   Map<String, dynamic>? get setterUserDetails => _setterUserDetails;

//   // Constructor
//   AppState() {
//     _currentUser = supabase.auth.currentUser;
//     supabase.auth.onAuthStateChange.listen((data) {
//       _currentUser = data.session?.user;
//       if (_currentUser == null) {
//         clearState();
//       }
//       notifyListeners();
//     });
//   }

//   void _unsubscribeFromChannels() {
//     if (_sensorEventsChannel != null) {
//       supabase.removeChannel(_sensorEventsChannel!);
//       _sensorEventsChannel = null;
//     }
//     if (_deviceStatusChannel != null) {
//       supabase.removeChannel(_deviceStatusChannel!);
//       _deviceStatusChannel = null;
//     }
//   }

//   void clearState() {
//     _deviceId = null;
//     _events.clear();
//     _deviceStatus = null;
//     _setterUserDetails = null;
//     _unsubscribeFromChannels(); // Unsubscribe saat logout
//     notifyListeners();
//   }

//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   Future<void> setDeviceIdAndFetchData(String deviceId) async {
//     _deviceId = deviceId;
//     if (_deviceId != null && _deviceId!.isNotEmpty) {
//       await fetchInitialData();
//       _listenToRealtimeChanges();
//     }
//     notifyListeners();
//   }

//   Future<void> fetchInitialData() async {
//     if (_deviceId == null) return;
//     _setLoading(true);
//     await Future.wait([
//       fetchEvents(),
//       fetchDeviceStatus(),
//     ]);
//     _setLoading(false);
//   }

//   Future<void> fetchEvents() async {
//     if (_deviceId == null) return;
//     try {
//       final response = await supabase
//           .from('sensor_events')
//           .select()
//           .eq('device_id', _deviceId!)
//           .order('event_timestamp', ascending: false);
//       _events = List<Map<String, dynamic>>.from(response);
//     } catch (e) {
//       print('Error fetching events: $e');
//       _events = [];
//     }
//     notifyListeners();
//   }

//   Future<void> fetchDeviceStatus() async {
//     if (_deviceId == null) return;
//     try {
//       final response = await supabase
//           .from('device_status')
//           .select()
//           .eq('device_id', _deviceId!)
//           .single();
//       _deviceStatus = response;
//       if (_deviceStatus != null && _deviceStatus!['setter_user_id'] != null) {
//         await fetchSetterUserDetails(_deviceStatus!['setter_user_id']);
//       } else {
//         _setterUserDetails = null;
//       }
//     } catch (e) {
//       print('Error fetching device status: $e');
//       _deviceStatus = {'device_id': _deviceId, 'is_online': false};
//     }
//     notifyListeners();
//   }

//   Future<void> fetchSetterUserDetails(String userId) async {
//     try {
//       final response = await supabase
//           .from('users')
//           .select('raw_user_meta_data')
//           .eq('id', userId)
//           .single();
//       _setterUserDetails = response['raw_user_meta_data'];
//     } catch (e) {
//       print('Error fetching setter user details: $e');
//       _setterUserDetails = {'full_name': 'Unknown', 'email': 'Unknown'};
//     }
//     notifyListeners();
//   }

//   void _listenToRealtimeChanges() {
//     if (_deviceId == null) return;

//     _unsubscribeFromChannels();

//     _sensorEventsChannel = supabase.channel('public:sensor_events:$_deviceId');
//     _sensorEventsChannel!
//         .onPostgresChanges(
//           event: PostgresChangeEvent.insert,
//           schema: 'public',
//           table: 'sensor_events',
//           filter: PostgresChangeFilter(
//             type: PostgresChangeFilterType.eq,
//             column: 'device_id',
//             value: _deviceId!,
//           ),
//           callback: (payload) {
//             final newEvent = payload.newRecord;
//             if (!_events.any((e) => e['id'] == newEvent['id'])) {
//               _events.insert(0, newEvent);
//               notifyListeners();
//             }
//           },
//         )
//         .subscribe();

//     _deviceStatusChannel = supabase.channel('public:device_status:$_deviceId');
//     _deviceStatusChannel!
//         .onPostgresChanges(
//           event: PostgresChangeEvent.all,
//           schema: 'public',
//           table: 'device_status',
//           filter: PostgresChangeFilter(
//             type: PostgresChangeFilterType.eq,
//             column: 'device_id',
//             value: _deviceId!,
//           ),
//           callback: (payload) async {
//             final newStatus = payload.newRecord;
//             _deviceStatus = newStatus;
//             if (_deviceStatus != null &&
//                 _deviceStatus!['setter_user_id'] != null) {
//               await fetchSetterUserDetails(_deviceStatus!['setter_user_id']);
//             } else {
//               _setterUserDetails = null;
//             }
//             notifyListeners();
//           },
//         )
//         .subscribe();
//   }

//   Future<void> signOut() async {
//     _setLoading(true);
//     await supabase.auth.signOut();
//     _setLoading(false);
//   }

//   Future<String?> setSleepSchedule(int durationMicroseconds) async {
//     if (_deviceId == null || _currentUser == null) {
//       return "User or Device not identified.";
//     }
//     _setLoading(true);
//     try {
//       await supabase.from('device_status').update({
//         'schedule_duration_microseconds': durationMicroseconds,
//         'setter_user_id': _currentUser!.id,
//       }).eq('device_id', _deviceId!);
//       _setLoading(false);
//       return null;
//     } on PostgrestException catch (e) {
//       _setLoading(false);
//       print('Error setting sleep schedule: ${e.message}');
//       return e.message;
//     } catch (e) {
//       _setLoading(false);
//       print('Generic error setting sleep schedule: $e');
//       return 'An unexpected error occurred.';
//     }
//   }
// }

// // =================================================================
// // SPLASH SCREEN PAGE
// // =================================================================

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(const Duration(seconds: 3), () {
//       if (mounted) {
//         Navigator.of(context).pushReplacement(
//             MaterialPageRoute(builder: (_) => const AuthWrapper()));
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(CupertinoIcons.lock_shield_fill,
//                 size: 120, color: Colors.tealAccent),
//             const SizedBox(height: 24),
//             Text(
//               'Security Monitor',
//               style: Theme.of(context)
//                   .textTheme
//                   .titleLarge
//                   ?.copyWith(fontSize: 28),
//             ),
//             const SizedBox(height: 80),
//             const CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // =================================================================
// // AUTH WRAPPER (Gatekeeper)
// // =================================================================

// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AppState>(
//       builder: (context, appState, child) {
//         if (appState.currentUser != null && appState.deviceId != null) {
//           return const DashboardPage();
//         }
//         return const LoginPage();
//       },
//     );
//   }
// }

// // =================================================================
// // LOGIN PAGE
// // =================================================================

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _deviceIdController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;

//   Future<void> _signIn() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         final authResponse = await supabase.auth.signInWithPassword(
//           email: _emailController.text.trim(),
//           password: _passwordController.text.trim(),
//         );
//         if (authResponse.user != null) {
//           if (!mounted) return;
//           await Provider.of<AppState>(context, listen: false)
//               .setDeviceIdAndFetchData(_deviceIdController.text.trim());
//         }
//       } on AuthException catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text(e.message),
//           backgroundColor: Colors.redAccent,
//         ));
//       } catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//           content: Text('An unexpected error occurred.'),
//           backgroundColor: Colors.redAccent,
//         ));
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     _deviceIdController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const Icon(CupertinoIcons.shield_lefthalf_fill,
//                     size: 80, color: Colors.tealAccent),
//                 const SizedBox(height: 16),
//                 const Text('Security Monitor',
//                     textAlign: TextAlign.center,
//                     style:
//                         TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 48),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(labelText: 'Email'),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: (value) =>
//                       value!.isEmpty ? 'Email tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   decoration: const InputDecoration(labelText: 'Password'),
//                   obscureText: true,
//                   validator: (value) =>
//                       value!.isEmpty ? 'Password tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _deviceIdController,
//                   decoration: const InputDecoration(labelText: 'Device ID'),
//                   validator: (value) =>
//                       value!.isEmpty ? 'Device ID tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 32),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _signIn,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     backgroundColor: Colors.tealAccent,
//                     foregroundColor: Colors.black,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           width: 24,
//                           height: 24,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.black,
//                           ))
//                       : const Text('Login',
//                           style: TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                 ),
//                 const SizedBox(height: 24),
//                 TextButton(
//                   onPressed: () => Navigator.push(context,
//                       MaterialPageRoute(builder: (_) => const RegisterPage())),
//                   child: const Text('Belum punya akun? Daftar sekarang',
//                       style: TextStyle(color: Colors.white70)),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // =================================================================
// // REGISTER PAGE
// // =================================================================
// class RegisterPage extends StatefulWidget {
//   const RegisterPage({super.key});

//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> {
//   final _fullNameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;

//   Future<void> _signUp() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);
//       try {
//         await supabase.auth.signUp(
//           email: _emailController.text.trim(),
//           password: _passwordController.text.trim(),
//           data: {'full_name': _fullNameController.text.trim()},
//         );
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//           content: Text(
//               'Registrasi berhasil! Silakan periksa email Anda untuk verifikasi dan kemudian login.'),
//           backgroundColor: Colors.green,
//         ));
//         Navigator.pop(context);
//       } on AuthException catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text(e.message),
//           backgroundColor: Colors.redAccent,
//         ));
//       } catch (e) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//           content: Text('An unexpected error occurred.'),
//           backgroundColor: Colors.redAccent,
//         ));
//       } finally {
//         if (mounted) {
//           setState(() => _isLoading = false);
//         }
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _fullNameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const Icon(CupertinoIcons.person_add_solid,
//                     size: 80, color: Colors.tealAccent),
//                 const SizedBox(height: 16),
//                 const Text('Buat Akun Baru',
//                     textAlign: TextAlign.center,
//                     style:
//                         TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 48),
//                 TextFormField(
//                   controller: _fullNameController,
//                   decoration: const InputDecoration(labelText: 'Nama Lengkap'),
//                   validator: (value) =>
//                       value!.isEmpty ? 'Nama tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: const InputDecoration(labelText: 'Email'),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: (value) =>
//                       value!.isEmpty ? 'Email tidak boleh kosong' : null,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   decoration: const InputDecoration(labelText: 'Password'),
//                   obscureText: true,
//                   validator: (value) =>
//                       value!.length < 6 ? 'Password minimal 6 karakter' : null,
//                 ),
//                 const SizedBox(height: 32),
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _signUp,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     backgroundColor: Colors.tealAccent,
//                     foregroundColor: Colors.black,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           width: 24,
//                           height: 24,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.black,
//                           ))
//                       : const Text('Register',
//                           style: TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // =================================================================
// // DASHBOARD PAGE
// // =================================================================
// class DashboardPage extends StatelessWidget {
//   const DashboardPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Consumer<AppState>(
//               builder: (context, appState, child) {
//                 if (appState.isLoading && appState.events.isEmpty) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 return RefreshIndicator(
//                   onRefresh: Provider.of<AppState>(context, listen: false)
//                       .fetchInitialData,
//                   color: Colors.tealAccent,
//                   backgroundColor: const Color(0xFF2c2c2c),
//                   child: const CustomScrollView(
//                     slivers: [
//                       SliverToBoxAdapter(child: ProfileBar()),
//                       SliverToBoxAdapter(child: SettingsBar()),
//                       SliverToBoxAdapter(child: SizedBox(height: 20)),
//                       SliverToBoxAdapter(
//                           child: Padding(
//                         padding: EdgeInsets.symmetric(horizontal: 16.0),
//                         child: Text("Footage Gallery",
//                             style: TextStyle(
//                                 fontSize: 22, fontWeight: FontWeight.bold)),
//                       )),
//                       SliverToBoxAdapter(child: SizedBox(height: 10)),
//                       FootageGallery(),
//                     ],
//                   ),
//                 );
//               },
//             ),
//             // Indikator loading linear di bagian atas
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Consumer<AppState>(
//                 builder: (context, appState, child) {
//                   return Visibility(
//                     visible: appState.isLoading,
//                     child: const LinearProgressIndicator(
//                       color: Colors.tealAccent,
//                       backgroundColor: Colors.transparent,
//                     ),
//                   );
//                 },
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }

// // =================================================================
// // DASHBOARD COMPONENTS: PROFILE BAR
// // =================================================================
// class ProfileBar extends StatelessWidget {
//   const ProfileBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final appState = Provider.of<AppState>(context);
//     final user = appState.currentUser;
//     final fullName = user?.userMetadata?['full_name'] ?? 'No Name';
//     final email = user?.email ?? 'No Email';

//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         children: [
//           CircleAvatar(
//             backgroundColor: Colors.teal,
//             child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
//                 style: const TextStyle(
//                     color: Colors.white, fontWeight: FontWeight.bold)),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(fullName,
//                     style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white)),
//                 Text(email,
//                     style:
//                         const TextStyle(fontSize: 14, color: Colors.white70)),
//               ],
//             ),
//           ),
//           IconButton(
//             tooltip: "Logout",
//             icon: const Icon(Icons.logout, color: Colors.white70),
//             onPressed: () {
//               Provider.of<AppState>(context, listen: false).signOut();
//             },
//           )
//         ],
//       ),
//     );
//   }
// }

// // =================================================================
// // DASHBOARD COMPONENTS: SETTINGS BAR
// // =================================================================
// class SettingsBar extends StatelessWidget {
//   const SettingsBar({super.key});

//   void _showSetTimerDialog(BuildContext context, AppState appState) async {
//     final now = DateTime.now();
//     final TimeOfDay? pickedTime = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
//     );

//     if (pickedTime != null) {
//       DateTime scheduledTime = DateTime(
//           now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
//       if (scheduledTime.isBefore(now)) {
//         scheduledTime = scheduledTime.add(const Duration(days: 1));
//       }

//       final duration = scheduledTime.difference(now);
//       final durationMicroseconds = duration.inMicroseconds;

//       final error = await appState.setSleepSchedule(durationMicroseconds);

//       if (context.mounted) {
//         if (error == null) {
//           // PERBAIKAN: Menggunakan DateFormat yang sudah diinisialisasi
//           final formattedTime = DateFormat.jm('id_ID').format(scheduledTime);
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text('Jadwal deep sleep diatur hingga $formattedTime'),
//             backgroundColor: Colors.green,
//           ));
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//             content: Text('Gagal mengatur jadwal: $error'),
//             backgroundColor: Colors.redAccent,
//           ));
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AppState>(
//       builder: (context, appState, child) {
//         final status = appState.deviceStatus;
//         if (status == null) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16.0),
//             child: Center(
//                 child: Text("Mencari status perangkat...",
//                     style: TextStyle(color: Colors.white24))),
//           );
//         }

//         final bool isOnline = status['is_online'] ?? false;
//         final String deviceId = status['device_id'] ?? 'N/A';
//         final setterName = appState.setterUserDetails?['full_name'] ?? 'N/A';
//         final setterEmail =
//             appState.setterUserDetails?['email'] ?? 'Belum pernah diatur';

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Theme.of(context).cardColor,
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Device: $deviceId',
//                           style: const TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(Icons.circle,
//                               color: isOnline
//                                   ? Colors.greenAccent
//                                   : Colors.redAccent,
//                               size: 12),
//                           const SizedBox(width: 8),
//                           Text(isOnline ? 'Online' : 'Offline',
//                               style: const TextStyle(color: Colors.white)),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Last Setter: $setterName ($setterEmail)',
//                         style: const TextStyle(
//                             fontSize: 12, color: Colors.white54),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 ElevatedButton(
//                   onPressed: isOnline
//                       ? () => _showSetTimerDialog(context, appState)
//                       : null,
//                   style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                       foregroundColor: Colors.white,
//                       disabledBackgroundColor: Colors.grey.withOpacity(0.3)),
//                   child: const Text('Set Timer'),
//                 )
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// // =================================================================
// // DASHBOARD COMPONENTS: FOOTAGE GALLERY
// // =================================================================

// class FootageGallery extends StatelessWidget {
//   const FootageGallery({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AppState>(
//       builder: (context, appState, child) {
//         final events = appState.events;
//         if (events.isEmpty) {
//           return const SliverToBoxAdapter(
//             child: Center(
//               child: Padding(
//                 padding: EdgeInsets.all(48.0),
//                 child: Column(
//                   children: [
//                     Icon(CupertinoIcons.photo_on_rectangle,
//                         size: 60, color: Colors.white24),
//                     SizedBox(height: 16),
//                     Text('Belum ada rekaman',
//                         style: TextStyle(color: Colors.white24, fontSize: 16)),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         }
//         return SliverList(
//           delegate: SliverChildBuilderDelegate(
//             (context, index) {
//               final event = events[index];
//               return FootageCard(event: event);
//             },
//             childCount: events.length,
//           ),
//         );
//       },
//     );
//   }
// }

// class FootageCard extends StatelessWidget {
//   final Map<String, dynamic> event;
//   const FootageCard({super.key, required this.event});

//   @override
//   Widget build(BuildContext context) {
//     final imageUrl = event['image_ref'] ?? '';
//     final location = event['location_name'] ?? 'Unknown Location';
//     final eventType = event['event_type'] ?? 'Unknown Event';
//     final timestamp = DateTime.parse(event['event_timestamp']);

//     // =================================================================
//     // PERBAIKAN: Menggunakan DateFormat langsung di sini.
//     // Locale 'id_ID' sudah dijamin siap karena inisialisasi di main().
//     // Format tahun (yyyy) juga sudah diperbaiki.
//     // =================================================================
//     final formattedTime = DateFormat('EEEE, dd MMMM yyyy, HH:mm:ss', 'id_ID')
//         .format(timestamp.toLocal());

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: Theme.of(context).cardColor,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.5),
//             spreadRadius: 2,
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           )
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (imageUrl.isNotEmpty)
//               Image.network(
//                 imageUrl,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 height: 250,
//                 loadingBuilder: (context, child, loadingProgress) {
//                   if (loadingProgress == null) return child;
//                   return Container(
//                     height: 250,
//                     color: Colors.black12,
//                     child: Center(
//                       child: CircularProgressIndicator(
//                         color: Colors.tealAccent,
//                         value: loadingProgress.expectedTotalBytes != null
//                             ? loadingProgress.cumulativeBytesLoaded /
//                                 loadingProgress.expectedTotalBytes!
//                             : null,
//                       ),
//                     ),
//                   );
//                 },
//                 errorBuilder: (context, error, stackTrace) => Container(
//                   height: 250,
//                   color: Colors.black12,
//                   child: const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(CupertinoIcons.exclamationmark_triangle,
//                             color: Colors.redAccent, size: 50),
//                         SizedBox(height: 8),
//                         Text("Gagal memuat gambar",
//                             style: TextStyle(color: Colors.white70))
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                         color: eventType == 'GERAKAN'
//                             ? Colors.orange.shade800
//                             : Colors.purple.shade800,
//                         borderRadius: BorderRadius.circular(8)),
//                     child: Text(
//                       eventType,
//                       style: const TextStyle(
//                           color: Colors.white, fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       const Icon(CupertinoIcons.location_solid,
//                           size: 16, color: Colors.white70),
//                       const SizedBox(width: 8),
//                       Text(location,
//                           style: const TextStyle(
//                               fontSize: 16, color: Colors.white)),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       const Icon(CupertinoIcons.time_solid,
//                           size: 16, color: Colors.white70),
//                       const SizedBox(width: 8),
//                       Text(formattedTime,
//                           style: const TextStyle(
//                               fontSize: 14, color: Colors.white70)),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
