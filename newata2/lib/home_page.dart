// =================================================================
// HALAMAN UTAMA (MONITORING) - DENGAN PENYESUAIAN
// =================================================================

import 'package:CCTV_App/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final deviceName = appState.selectedDevice?['device_name'] ?? 'Perangkat';

    return Scaffold(
      appBar: AppBar(
        title: Text('Sedang memantau perangkat: $deviceName'),
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
      body: RefreshIndicator(
        onRefresh: () => appState.fetchInitialDataForSelectedDevice(),
        child: appState.isLoading && appState.events.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const DeviceStatusCard(),
                  if (appState.events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Center(
                          child: Text('Belum ada ancaman yang direkam.',
                              style: TextStyle(color: Colors.white70))),
                    ),
                  ...appState.events.map((event) => EventCard(event: event)),
                ],
              ),
      ),
    );
  }
}

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
              title: const Text('Set Timer Deep Sleep'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Perangkat akan deepsleep hingga waktu yang dipilih."),
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
                        selectedTime?.format(context) ?? 'Pilih waktu selesai',
                        style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(durationText ?? "Klik untuk set timer"),
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
                                  Text(result ?? 'Deepsleep sukses terjadwal!'),
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
    return "Durasi: $hours jam, $minutes menit";
  }

  String _formatSleepDuration(int microseconds) {
    if (microseconds <= 0) return 'Timer belum di set';
    final duration = Duration(microseconds: microseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m tersisa';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final status =
            appState.deviceStatus?['status'] as String? ?? 'Tidak diketahui';
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
          statusText = 'DEEPSLEEP';
        } else if (status == 'active') {
          statusColor = Colors.greenAccent;
          statusIcon = CupertinoIcons.checkmark_shield_fill;
          statusText = 'ONLINE';
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        Text('Terakhir aktif: $formattedTime',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                            hasActiveTimer
                                ? sleepDurationText
                                : 'Timer Deepsleep belum di set',
                            style: TextStyle(
                                color: hasActiveTimer
                                    ? Colors.lightBlueAccent
                                    : Colors.white70)),
                      ],
                    ),
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

// === WIDGET DENGAN PERBAIKAN UTAMA ===
class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final eventType = event['event_type'] as String?;
    final location = event['location'] as String? ?? 'Lokasi tidak diketahui';
    final timestampStr = event['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.parse(timestampStr).toLocal()
        : DateTime.now();
    final formattedTime =
        DateFormat('EEEE, d MMMM yyyy, HH:mm:ss', 'id_ID').format(timestamp);

    // PERBAIKAN #1 (Lanjutan): Langsung gunakan 'image_ref' sebagai imageUrl.
    final imageRef = event['image_ref'] as String?;
    final imageUrl = imageRef; // Tidak perlu pemrosesan lagi

    final String displayEventType;
    final Color eventColor;

    // PERBAIKAN #2: Mencocokkan nilai 'event_type' dengan yang dikirim oleh ESP32.
    // ESP32 mengirim "motion" dan "vibration". Kode sebelumnya memeriksa "motion_detected"
    // dan "vibration_detected", yang menyebabkan selalu jatuh ke 'Unknown Event'.
    if (eventType == 'motion') {
      displayEventType = 'Gerakan Terdeteksi';
      eventColor = Colors.orange;
    } else if (eventType == 'vibration') {
      displayEventType = 'Getaran Terdeteksi';
      eventColor = Colors.purpleAccent;
    } else {
      displayEventType = 'Event tidak diketahui';
      eventColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
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
                errorBuilder: (context, error, stackTrace) {
                  // Tambahkan print untuk debugging jika gambar masih gagal dimuat
                  print("Gagal memuat image: $error");
                  print("URL Gambar: $imageUrl");
                  return Container(
                    height: 200,
                    color: Colors.black26,
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white30, size: 40)),
                  );
                },
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
