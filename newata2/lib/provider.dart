// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

import 'package:CCTV_App/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
