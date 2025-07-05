// =================================================================
// HALAMAN BARU: DEVICE MANAGEMENT
// =================================================================

import 'package:CCTV_App/home_page.dart';
import 'package:CCTV_App/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          title: const Text('Tambah perangkat baru'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: deviceIdController,
                    decoration: const InputDecoration(labelText: 'Device ID'),
                    validator: (value) =>
                        value!.isEmpty ? 'Device ID wajib diisi' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: deviceNameController,
                    decoration: const InputDecoration(
                        labelText: 'Nama perangkat (e.g., Teras Rumah)'),
                    validator: (value) =>
                        value!.isEmpty ? 'Perangkat harus diberi nama' : null),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal')),
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
                          content:
                              Text(result ?? 'Perangkat berhasil ditambahkan!'),
                          backgroundColor: result == null
                              ? Colors.green
                              : Theme.of(context).colorScheme.error));
                    }
                  }
                },
                child: const Text('Tambah')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Perangkat Tertaut'),
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
                    Text('Perangkat tidak ditermukan',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 8),
                    Text(
                        'Klik [+] dipojok kanan bawah untuk menambahkan perangkat.',
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
                                      'Apakah anda yakin untuk menghapus perangkat ${device['device_name']}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Batal')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Hapus',
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
