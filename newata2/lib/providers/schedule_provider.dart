// providers/schedule_provider.dart (Sudah Lengkap)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class ScheduleProvider extends ChangeNotifier {
  final String? userId;
  ScheduleProvider(this.userId) {
    print("ScheduleProvider: Initialized with userId: $userId");
  }

  TimeOfDay? _startTime;
  TimeOfDay? get startTime => _startTime;

  TimeOfDay? _endTime;
  TimeOfDay? get endTime => _endTime;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final _dbTimeFormat = DateFormat('HH:mm:ss');

  Future<void> fetchSchedule() async {
    print("ScheduleProvider: fetchSchedule called for userId: $userId");
    if (userId == null) {
      print("ScheduleProvider: fetchSchedule aborted, userId is null.");
      _errorMessage = "User tidak terautentikasi.";
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await supabase
          .from('device_schedule')
          .select('inactive_start_time, inactive_end_time')
          .eq('user_id', userId!)
          .maybeSingle();

      if (response != null) {
        final data = response;
        final startTimeString = data['inactive_start_time'] as String?;
        final endTimeString = data['inactive_end_time'] as String?;

        _startTime = (startTimeString != null)
            ? TimeOfDay.fromDateTime(_dbTimeFormat.parse(startTimeString))
            : null;
        _endTime = (endTimeString != null)
            ? TimeOfDay.fromDateTime(_dbTimeFormat.parse(endTimeString))
            : null;
        print(
            "ScheduleProvider: fetchSchedule successful. Start: $_startTime, End: $_endTime");
      } else {
        _startTime = null;
        _endTime = null;
        print("ScheduleProvider: fetchSchedule - No schedule found.");
      }
    } catch (e) {
      print('ScheduleProvider: Error fetching schedule: $e');
      _errorMessage = 'Gagal memuat jadwal: ${e.toString()}';
      _startTime = null;
      _endTime = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSchedule(
      TimeOfDay newStartTime, TimeOfDay newEndTime) async {
    print(
        "ScheduleProvider: saveSchedule called. Start: $newStartTime, End: $newEndTime");
    if (userId == null) {
      print("ScheduleProvider: saveSchedule aborted, userId is null.");
      _errorMessage = "User tidak terautentikasi.";
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDateTime = DateTime(
          now.year, now.month, now.day, newStartTime.hour, newStartTime.minute);
      final endDateTime = DateTime(
          now.year, now.month, now.day, newEndTime.hour, newEndTime.minute);
      final startTimeString = _dbTimeFormat.format(startDateTime);
      final endTimeString = _dbTimeFormat.format(endDateTime);

      await supabase.from('device_schedule').upsert({
        'user_id': userId!,
        'inactive_start_time': startTimeString,
        'inactive_end_time': endTimeString,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      _startTime = newStartTime;
      _endTime = newEndTime;
      _isLoading = false;
      print("ScheduleProvider: saveSchedule successful.");
      notifyListeners();
      return true;
    } catch (e) {
      print('ScheduleProvider: Error saving schedule: $e');
      _errorMessage = 'Gagal menyimpan jadwal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
