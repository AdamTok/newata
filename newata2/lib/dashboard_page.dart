// =================================================================
// DASHBOARD PAGE & COMPONENTS
// =================================================================

import 'package:CCTV_App/login_page.dart';
import 'package:CCTV_App/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
