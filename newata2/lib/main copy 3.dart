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
          error: Colors.redAccent,
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

class AppState extends ChangeNotifier {
  bool _isLoading = false;
  User? _currentUser;

  List<Map<String, dynamic>> _userDevices = [];
  Map<String, dynamic>? _selectedDevice;

  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _deviceStatus;

  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _deviceStatusChannel;

  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  List<Map<String, dynamic>> get userDevices => _userDevices;
  Map<String, dynamic>? get selectedDevice => _selectedDevice;
  List<Map<String, dynamic>> get events => _events;
  Map<String, dynamic>? get deviceStatus => _deviceStatus;

  String? get selectedDeviceId => _selectedDevice?['device_id'];

  AppState() {
    _currentUser = supabase.auth.currentUser;
    if (_currentUser != null) {
      fetchUserDevices();
    }

    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      _currentUser = session?.user;
      if (_currentUser != null) {
        fetchUserDevices();
      } else {
        clearState();
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _unsubscribeFromChannels() {
    _eventsChannel?.unsubscribe();
    _deviceStatusChannel?.unsubscribe();
    _eventsChannel = null;
    _deviceStatusChannel = null;
  }

  void clearState() {
    _userDevices.clear();
    _selectedDevice = null;
    _events.clear();
    _deviceStatus = null;
    _unsubscribeFromChannels();
    notifyListeners();
  }

  Future<void> fetchUserDevices() async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      final response = await supabase
          .from('user_devices')
          .select()
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: true);
      _userDevices = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user devices: $e');
      _userDevices = [];
    }
    _setLoading(false);
  }

  Future<String?> addUserDevice(String deviceId, String deviceName) async {
    if (_currentUser == null) return "User not logged in.";
    _setLoading(true);
    try {
      final deviceExists = await supabase
          .from('device_status')
          .select('device_id')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (deviceExists == null) {
        _setLoading(false);
        return "Device ID tidak ditemukan. Pastikan perangkat Anda sudah online setidaknya sekali.";
      }

      await supabase.from('user_devices').insert({
        'user_id': _currentUser!.id,
        'device_id': deviceId,
        'device_name': deviceName,
      });

      await fetchUserDevices();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return "Perangkat ini sudah ada di dalam daftar Anda.";
      }
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan tidak terduga.';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> removeUserDevice(int id) async {
    if (_currentUser == null) return "User not logged in.";
    _setLoading(true);
    try {
      await supabase.from('user_devices').delete().eq('id', id);
      await fetchUserDevices();
      return null;
    } catch (e) {
      return "Gagal menghapus perangkat.";
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectDevice(Map<String, dynamic> device) async {
    _setLoading(true);
    _selectedDevice = device;
    await fetchInitialDataForSelectedDevice();
    _listenToRealtimeChanges();
    _setLoading(false);
  }

  void deselectDevice() {
    _selectedDevice = null;
    _events.clear();
    _deviceStatus = null;
    _unsubscribeFromChannels();
    notifyListeners();
  }

  Future<void> fetchInitialDataForSelectedDevice() async {
    if (selectedDeviceId == null) return;
    _setLoading(true);
    await Future.wait([
      fetchEvents(),
      fetchDeviceStatus(),
    ]);
    _setLoading(false);
  }

  Future<void> fetchEvents() async {
    if (selectedDeviceId == null) return;
    try {
      final response = await supabase
          .from('events')
          .select()
          .eq('device_id', selectedDeviceId!)
          .order('timestamp', ascending: false)
          .limit(50); // Batasi jumlah event awal
      _events = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching events: $e');
      _events = [];
    }
    notifyListeners();
  }

  Future<void> fetchDeviceStatus() async {
    if (selectedDeviceId == null) return;
    try {
      final response = await supabase
          .from('device_status')
          .select()
          .eq('device_id', selectedDeviceId!)
          .single();
      _deviceStatus = response;
    } catch (e) {
      print('Error fetching device status: $e');
      _deviceStatus = null;
    }
    notifyListeners();
  }

  void _listenToRealtimeChanges() {
    if (selectedDeviceId == null) return;
    _unsubscribeFromChannels();

    _eventsChannel =
        supabase.channel('public:events:device_id=$selectedDeviceId');
    _eventsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: selectedDeviceId!,
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
        supabase.channel('public:device_status:device_id=$selectedDeviceId');
    _deviceStatusChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent
              .all, // Dengarkan semua perubahan (insert/update)
          schema: 'public',
          table: 'device_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: selectedDeviceId!,
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
    _setLoading(false);
  }

  Future<String?> setSleepSchedule(int durationMicroseconds) async {
    if (selectedDeviceId == null) return "Device not identified.";
    _setLoading(true);
    try {
      await supabase.from('device_status').update({
        'schedule_duration': durationMicroseconds,
        'last_update': DateTime.now().toIso8601String(),
      }).eq('device_id', selectedDeviceId!);
      await fetchDeviceStatus();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred.';
    } finally {
      _setLoading(false);
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
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading && appState.currentUser == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (appState.currentUser == null) {
          return const AuthPage();
        } else {
          return const DeviceManagementPage();
        }
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await supabase.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            data: {'full_name': _fullNameController.text.trim()});
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('An unexpected error occurred.'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
    if (mounted) setState(() => _isLoading = false);
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
                Icon(CupertinoIcons.shield_lefthalf_fill,
                    size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
                Text(_isLogin ? 'Welcome Back' : 'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Sign in to continue' : 'Join us today!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),
                if (!_isLogin)
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter your full name' : null,
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter an email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => value!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.black),
                        child: Text(_isLogin ? 'LOGIN' : 'SIGN UP',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                      _isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Login',
                      style: const TextStyle(color: Colors.white70)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================
// HALAMAN DEVICE MANAGEMENT
// =================================================================

class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});
  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppState>().fetchUserDevices());
  }

  void _showAddDeviceDialog() {
    final formKey = GlobalKey<FormState>();
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Add New Device'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: deviceIdController,
                    decoration: const InputDecoration(labelText: 'Device ID'),
                    validator: (value) =>
                        value!.isEmpty ? 'Device ID cannot be empty' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: deviceNameController,
                    decoration: const InputDecoration(
                        labelText: 'Device Name (e.g., Teras Rumah)'),
                    validator: (value) =>
                        value!.isEmpty ? 'Device Name cannot be empty' : null),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final appState = context.read<AppState>();
                    final result = await appState.addUserDevice(
                        deviceIdController.text.trim(),
                        deviceNameController.text.trim());
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(result ?? 'Device added successfully!'),
                          backgroundColor: result == null
                              ? Colors.green
                              : Theme.of(context).colorScheme.error));
                    }
                  }
                },
                child: const Text('Add')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async => await context.read<AppState>().signOut())
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading && appState.userDevices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (appState.userDevices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.camera_viewfinder,
                        size: 60, color: Colors.white38),
                    SizedBox(height: 16),
                    Text('No Devices Found',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 8),
                    Text(
                        'Click the + button to add your first ESP32-CAM device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => appState.fetchUserDevices(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: appState.userDevices.length,
              itemBuilder: (context, index) {
                final device = appState.userDevices[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    leading: const Icon(CupertinoIcons.camera_fill,
                        color: Colors.tealAccent),
                    title: Text(device['device_name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(device['device_id'],
                        style: const TextStyle(color: Colors.white70)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: Text(
                                      'Are you sure you want to remove ${device['device_name']}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.redAccent))),
                                  ],
                                ));
                        if (confirm == true) {
                          await appState.removeUserDevice(device['id']);
                        }
                      },
                    ),
                    onTap: () async {
                      await appState.selectDevice(device);
                      if (mounted) {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const HomePage()));
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _showAddDeviceDialog,
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add, color: Colors.black)),
    );
  }
}

// =================================================================
// HALAMAN UTAMA (MONITORING)
// =================================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final deviceName = appState.selectedDevice?['device_name'] ?? 'Device';

    return Scaffold(
      appBar: AppBar(
        title: Text('Monitor: $deviceName'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<AppState>().deselectDevice();
            Navigator.of(context).pop();
          },
        ),
      ),
      // === PERUBAHAN: MENGGUNAKAN RefreshIndicator ===
      body: RefreshIndicator(
        onRefresh: () => appState.fetchInitialDataForSelectedDevice(),
        child: appState.isLoading && appState.events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                // Menggunakan ListView agar bisa di-scroll
                children: [
                  const DeviceStatusCard(),
                  if (appState.events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Center(
                          child: Text('No events recorded for this device yet.',
                              style: TextStyle(color: Colors.white70))),
                    ),
                  ...appState.events.map((event) => EventCard(event: event)),
                ],
              ),
      ),
    );
  }
}

// === PERUBAHAN: DESAIN ULANG DeviceStatusCard ===
class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({super.key});

  void _showSleepScheduleDialog(BuildContext context) {
    TimeOfDay? selectedTime;
    String? durationText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: const Text('Set Deep Sleep Timer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Device will sleep until the selected time."),
                  const SizedBox(height: 20),
                  ListTile(
                    onTap: () async {
                      final time = await showTimePicker(
                          context: context, initialTime: TimeOfDay.now());
                      if (time != null) {
                        setState(() {
                          selectedTime = time;
                          final now = DateTime.now();
                          var scheduledTime = DateTime(now.year, now.month,
                              now.day, time.hour, time.minute);
                          if (scheduledTime.isBefore(now) ||
                              scheduledTime.isAtSameMomentAs(now)) {
                            scheduledTime =
                                scheduledTime.add(const Duration(days: 1));
                          }
                          final duration = scheduledTime.difference(now);
                          durationText = _formatDuration(duration);
                        });
                      }
                    },
                    leading: const Icon(CupertinoIcons.clock_fill),
                    title: Text(
                        selectedTime?.format(context) ?? 'Select End Time',
                        style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(durationText ?? "Tap to choose time"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedTime == null
                      ? null
                      : () async {
                          final now = DateTime.now();
                          var scheduledTime = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              selectedTime!.hour,
                              selectedTime!.minute);
                          if (scheduledTime.isBefore(now) ||
                              scheduledTime.isAtSameMomentAs(now)) {
                            scheduledTime =
                                scheduledTime.add(const Duration(days: 1));
                          }
                          final durationInMicroseconds =
                              scheduledTime.difference(now).inMicroseconds;
                          final appState = context.read<AppState>();
                          final result = await appState
                              .setSleepSchedule(durationInMicroseconds);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(result ?? 'Sleep schedule updated!'),
                              backgroundColor: result == null
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ));
                          }
                        },
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    return "Duration: $hours hours, $minutes minutes";
  }

  String _formatSleepDuration(int microseconds) {
    if (microseconds <= 0) return 'Timer is off';
    final duration = Duration(microseconds: microseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final status = appState.deviceStatus?['status'] as String? ?? 'unknown';
        final lastUpdateStr = appState.deviceStatus?['last_update'] as String?;
        final lastUpdate = lastUpdateStr != null
            ? DateTime.parse(lastUpdateStr).toLocal()
            : null;
        final formattedTime = lastUpdate != null
            ? DateFormat('d MMM, HH:mm:ss', 'id_ID').format(lastUpdate)
            : 'N/A';
        final scheduleMicroseconds =
            appState.deviceStatus?['schedule_duration'] as int? ?? 0;

        final isSleeping = status == 'sleeping';
        final sleepDurationText = _formatSleepDuration(scheduleMicroseconds);
        final hasActiveTimer = scheduleMicroseconds > 0;

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (isSleeping) {
          statusColor = Colors.lightBlueAccent;
          statusIcon = CupertinoIcons.zzz;
          statusText = 'SLEEPING';
        } else if (status == 'active') {
          statusColor = Colors.greenAccent;
          statusIcon = CupertinoIcons.checkmark_shield_fill;
          statusText = 'ACTIVE';
        } else {
          statusColor = Colors.redAccent;
          statusIcon = CupertinoIcons.xmark_shield_fill;
          statusText = 'OFFLINE';
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Menggeser status ke tengah
                  children: [
                    Icon(statusIcon, color: statusColor, size: 28),
                    const SizedBox(width: 12),
                    Text(statusText,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last Update: $formattedTime',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                            hasActiveTimer
                                ? sleepDurationText
                                : 'Sleep timer is off',
                            style: TextStyle(
                                color: hasActiveTimer
                                    ? Colors.lightBlueAccent
                                    : Colors.white70)),
                      ],
                    ),
                    // === PERUBAHAN: Tombol Set Timer dengan UI Lock ===
                    ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.timer, size: 16),
                      label: const Text('Set Timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSleeping
                            ? Colors.grey.shade800
                            : Theme.of(context).primaryColor,
                        foregroundColor:
                            isSleeping ? Colors.grey.shade400 : Colors.black,
                      ),
                      onPressed: isSleeping
                          ? null
                          : () => _showSleepScheduleDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// === PERUBAHAN: Perbaikan pada EventCard ===
class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventCard({super.key, required this.event});

  String _getImageUrl(String imageRef) {
    return supabase.storage.from('captured').getPublicUrl(imageRef);
  }

  @override
  Widget build(BuildContext context) {
    // === PERBAIKAN: Menggunakan type casting untuk keamanan ===
    final eventType = event['event_type'] as String?;
    final location = event['location'] as String? ?? 'Unknown Location';
    final timestampStr = event['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.parse(timestampStr).toLocal()
        : DateTime.now();
    final formattedTime =
        DateFormat('EEEE, d MMMM yyyy, HH:mm:ss', 'id_ID').format(timestamp);
    final imageRef = event['image_ref'] as String?;
    final imageUrl =
        imageRef != null && imageRef.isNotEmpty ? _getImageUrl(imageRef) : null;

    final String displayEventType;
    final Color eventColor;
    if (eventType == 'motion_detected') {
      displayEventType = 'Motion Detected';
      eventColor = Colors.orange;
    } else if (eventType == 'vibration_detected') {
      displayEventType = 'Vibration Detected';
      eventColor = Colors.purpleAccent;
    } else {
      displayEventType = 'Unknown Event';
      eventColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            InkWell(
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: InteractiveViewer(
                          child: Image.network(imageUrl,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator()),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error,
                                      color: Colors.red, size: 50))))),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.black26,
                  child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white30, size: 40)),
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
                      color: eventColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(displayEventType,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(CupertinoIcons.location_solid,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(location,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(CupertinoIcons.time_solid,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(formattedTime,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
