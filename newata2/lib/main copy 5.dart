import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      home: const AuthWrapper(), // Menggunakan AuthWrapper untuk logika awal
      debugShowCheckedModeBanner: false,
    );
  }
}

// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

class AppState extends ChangeNotifier {
  bool _isLoading = false;
  String? _deviceId;
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _deviceStatus;
  User? _currentUser;

  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _deviceStatusChannel;

  bool get isLoading => _isLoading;
  String? get deviceId => _deviceId;
  List<Map<String, dynamic>> get events => _events;
  Map<String, dynamic>? get deviceStatus => _deviceStatus;
  User? get currentUser => _currentUser;

  AppState() {
    _currentUser = supabase.auth.currentUser;
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      _currentUser = session?.user;
      if (_currentUser == null) {
        clearState();
      }
      notifyListeners();
    });
  }

  void _unsubscribeFromChannels() {
    if (_eventsChannel != null) {
      supabase.removeChannel(_eventsChannel!);
      _eventsChannel = null;
    }
    if (_deviceStatusChannel != null) {
      supabase.removeChannel(_deviceStatusChannel!);
      _deviceStatusChannel = null;
    }
  }

  void clearState() {
    _deviceId = null;
    _events.clear();
    _deviceStatus = null;
    _unsubscribeFromChannels();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> setDeviceIdAndFetchData(String deviceId) async {
    _setLoading(true);
    try {
      final response = await supabase
          .from('device_status')
          .select('device_id')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) {
        _setLoading(false);
        return false;
      }

      _deviceId = deviceId;
      await fetchInitialData();
      _listenToRealtimeChanges();
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      print('Error validating device ID: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> fetchInitialData() async {
    if (_deviceId == null) return;
    _setLoading(true);
    await Future.wait([
      fetchEvents(),
      fetchDeviceStatus(),
    ]);
    _setLoading(false);
  }

  Future<void> fetchEvents() async {
    if (_deviceId == null) return;
    try {
      final response = await supabase
          .from('events')
          .select()
          .eq('device_id', _deviceId!)
          .order('timestamp', ascending: false);
      _events = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching events: $e');
      _events = [];
    }
    notifyListeners();
  }

  Future<void> fetchDeviceStatus() async {
    if (_deviceId == null) return;
    try {
      final response = await supabase
          .from('device_status')
          .select()
          .eq('device_id', _deviceId!)
          .single();
      _deviceStatus = response;
    } catch (e) {
      print('Error fetching device status: $e');
      _deviceStatus = null;
    }
    notifyListeners();
  }

  void _listenToRealtimeChanges() {
    if (_deviceId == null) return;
    _unsubscribeFromChannels();

    _eventsChannel = supabase.channel('public:events:device_id=$_deviceId');
    _eventsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'events',
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

    _deviceStatusChannel =
        supabase.channel('public:device_status:device_id=$_deviceId');
    _deviceStatusChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'device_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: _deviceId!,
          ),
          callback: (payload) {
            _deviceStatus = payload.newRecord;
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> signOut() async {
    _setLoading(true);
    await supabase.auth.signOut();
    // clearState() akan dipanggil oleh listener onAuthStateChange
    _setLoading(false);
  }

  Future<String?> setSleepSchedule(int durationMicroseconds) async {
    if (_deviceId == null) {
      return "Device not identified.";
    }
    _setLoading(true);

    try {
      await supabase.from('device_status').update({
        'schedule_duration_microseconds': durationMicroseconds,
        'last_update': DateTime.now().toIso8601String(),
      }).eq('device_id', _deviceId!);

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
    if (!_formKey.currentState!.validate()) return;

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
            'Registrasi berhasil! Silakan periksa email untuk verifikasi & login.'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.redAccent,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error: ${e.toString()}"),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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
                              strokeWidth: 2, color: Colors.black))
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

class LoginPage extends StatefulWidget {
  final bool showLogoutSuccess;

  const LoginPage({super.key, this.showLogoutSuccess = false});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // PERBAIKAN: Menambahkan initState untuk menampilkan snackbar jika diperlukan.
  @override
  void initState() {
    super.initState();
    if (widget.showLogoutSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda telah berhasil logout.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) {
        throw 'Login gagal, pengguna tidak ditemukan.';
      }

      final deviceIdIsValid = await appState
          .setDeviceIdAndFetchData(_deviceIdController.text.trim());

      if (!mounted) return;

      if (deviceIdIsValid) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Login berhasil, tetapi Device ID tidak terdaftar.'),
          backgroundColor: Colors.orange,
        ));
        await appState.signOut();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email;
    if (userEmail != null && _emailController.text.isEmpty) {
      _emailController.text = userEmail;
    }

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
                              strokeWidth: 2, color: Colors.black))
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
                        backgroundColor: Colors.transparent),
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
    final user = Provider.of<AppState>(context, listen: false).currentUser;
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
            onPressed: () async {
              final bool? confirmLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF2c2c2c),
                    title: const Text('Konfirmasi Logout',
                        style: TextStyle(color: Colors.white)),
                    content: const Text('Apakah Anda yakin ingin keluar?',
                        style: TextStyle(color: Colors.white70)),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Batal',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  );
                },
              );

              if (!context.mounted) return;

              if (confirmLogout == true) {
                // PERBAIKAN: Navigasi dulu, baru proses logout di latar belakang.
                final appState = Provider.of<AppState>(context, listen: false);

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) =>
                          const LoginPage(showLogoutSuccess: true)),
                  (route) => false,
                );

                await appState.signOut();
              }
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
        final statusData = appState.deviceStatus;

        if (statusData == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
                child: Text("Mencari status perangkat...",
                    style: TextStyle(color: Colors.white24))),
          );
        }

        final deviceId = statusData['device_id'] ?? 'N/A';
        final deviceStatus = statusData['status'] ?? 'unknown';
        final isOnline = deviceStatus == 'active';
        final lastUpdateString =
            statusData['last_update'] ?? DateTime.now().toIso8601String();
        final lastUpdate = DateTime.parse(lastUpdateString).toLocal();
        final formattedLastUpdate =
            DateFormat('dd MMM, HH:mm:ss', 'id_ID').format(lastUpdate);

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
                          Text(isOnline ? 'Active' : 'Inactive',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last update: $formattedLastUpdate',
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
    final imageUrl = event['image_ref'] as String?;
    final location = event['location'] ?? 'Unknown Location';
    final eventType = event['event_type'] ?? 'Unknown Event';
    final timestampString =
        event['timestamp'] ?? DateTime.now().toIso8601String();
    final timestamp = DateTime.parse(timestampString);

    final formattedTime = DateFormat('EEEE, dd MMMM yyyy, HH:mm:ss', 'id_ID')
        .format(timestamp.toLocal());

    String displayEventType = 'Unknown';
    Color eventColor = Colors.grey;
    if (eventType == 'motion') {
      displayEventType = 'Motion Detected';
      eventColor = Colors.orange.shade800;
    } else if (eventType == 'vibration') {
      displayEventType = 'Vibration Detected';
      eventColor = Colors.purple.shade800;
    }

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
            if (imageUrl != null && imageUrl.isNotEmpty)
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
              )
            else
              Container(
                height: 100,
                color: Colors.black12,
                child: const Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.videocam,
                        size: 30, color: Colors.white24),
                    SizedBox(height: 8),
                    Text("No image captured",
                        style: TextStyle(color: Colors.white24))
                  ],
                )),
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
                        color: eventColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      displayEventType,
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
