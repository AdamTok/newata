// =================================================================
// STATE MANAGEMENT (PROVIDER)
// =================================================================

import 'package:CCTV_App/main.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
