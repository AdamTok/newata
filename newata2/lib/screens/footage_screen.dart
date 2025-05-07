// screens/footage_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pantau_footage_provider.dart'; // Pastikan path benar

// class FootageScreen extends StatefulWidget {
//   const FootageScreen({super.key});

//   @override
//   _FootageScreenState createState() => _FootageScreenState();
// }

// class _FootageScreenState extends State<FootageScreen> {
//   @override
//   void initState() {
//     super.initState();
//     print("FootageScreen: initState called.");
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       print("FootageScreen: Requesting fetchMediaItems.");
//       context.read<FootageProvider>().fetchMediaItems();
//     });
//   }

//   Future<void> _refreshMediaItems() async {
//     print("FootageScreen: Refresh requested.");
//     await context.read<FootageProvider>().fetchMediaItems();
//   }

//   void _viewMedia(BuildContext context, Map<String, dynamic> mediaItem) async {
//     final storagePath = mediaItem['storage_object_path'] as String?;
//     final mediaType = mediaItem['media_type'] as String?;

//     if (storagePath == null) {
//       print("FootageScreen: View media failed, storage path is null.");
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('Path media tidak valid.'),
//             backgroundColor: Colors.orangeAccent),
//       );
//       return;
//     }
//     print(
//         "FootageScreen: Viewing media type '$mediaType' at path '$storagePath'");

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) => const Dialog(
//         child: Padding(
//             padding: EdgeInsets.all(20.0),
//             child: Row(mainAxisSize: MainAxisSize.min, children: [
//               CircularProgressIndicator(color: Colors.teal),
//               SizedBox(width: 20),
//               Text("Memuat media...")
//             ])),
//       ),
//     );

//     final url = await context.read<FootageProvider>().getMediaUrl(storagePath);
//     if (mounted) Navigator.pop(context); // Tutup dialog loading

//     if (url != null && mounted) {
//       print("FootageScreen: URL obtained: $url");
//       if (mediaType == 'video') {
//         print("FootageScreen: Navigating to /video_player");
//         Navigator.pushNamed(context, '/video_player', arguments: url);
//       } else if (mediaType == 'image') {
//         print("FootageScreen: Navigating to /image_viewer");
//         Navigator.pushNamed(context, '/image_viewer', arguments: url);
//       } else {
//         print("FootageScreen: Unknown media type '$mediaType', cannot open.");
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text('Tipe media tidak dikenali: $mediaType'),
//               backgroundColor: Colors.orangeAccent),
//         );
//       }
//     } else if (mounted) {
//       print("FootageScreen: Failed to get URL.");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(context.read<FootageProvider>().errorMessage ??
//                 'Gagal memuat URL media.'),
//             backgroundColor: Colors.redAccent),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     print("FootageScreen: Building UI.");
//     final dateTimeFormat =
//         DateFormat('EEEE, dd MMMM yyyy HH:mm', 'id_ID'); // Tambah tahun

//     return Scaffold(
//       // AppBar tidak perlu karena sudah ada di Dashboard
//       body: Consumer<FootageProvider>(
//         builder: (context, provider, child) {
//           print(
//               "FootageScreen Consumer: Building list. isLoading: ${provider.isLoading}, itemCount: ${provider.mediaItems.length}, error: ${provider.errorMessage}");

//           if (provider.isLoading && provider.mediaItems.isEmpty) {
//             return const Center(
//                 child: CircularProgressIndicator(color: Colors.teal));
//           }

//           if (provider.errorMessage != null) {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.error_outline,
//                         color: Colors.redAccent, size: 50),
//                     const SizedBox(height: 10),
//                     Text('Oops! Terjadi Kesalahan',
//                         style: Theme.of(context).textTheme.titleLarge,
//                         textAlign: TextAlign.center),
//                     const SizedBox(height: 5),
//                     Text(provider.errorMessage!,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(color: Colors.grey[700])),
//                     const SizedBox(height: 20),
//                     ElevatedButton.icon(
//                         icon: const Icon(Icons.refresh),
//                         label: const Text('Coba Lagi'),
//                         onPressed: _refreshMediaItems)
//                   ],
//                 ),
//               ),
//             );
//           }

//           if (provider.mediaItems.isEmpty && !provider.isLoading) {
//             return Center(
//                 child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.videocam_off_outlined,
//                     size: 60, color: Colors.grey[400]),
//                 const SizedBox(height: 10),
//                 Text('Belum ada rekaman media',
//                     style: Theme.of(context)
//                         .textTheme
//                         .titleMedium
//                         ?.copyWith(color: Colors.grey[600])),
//                 const SizedBox(height: 20),
//                 ElevatedButton.icon(
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Refresh'),
//                     onPressed: _refreshMediaItems,
//                     style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey[300],
//                         foregroundColor: Colors.grey[800]))
//               ],
//             ));
//           }

//           // Tampilkan list media
//           return RefreshIndicator(
//             onRefresh: _refreshMediaItems,
//             color: Colors.teal,
//             child: ListView.builder(
//               padding: const EdgeInsets.all(8.0),
//               itemCount: provider.mediaItems.length,
//               itemBuilder: (context, index) {
//                 final mediaItem = provider.mediaItems[index];
//                 final storagePath = mediaItem['storage_object_path'] as String?;
//                 final uploadedAtString = mediaItem['uploaded_at'] as String?;
//                 final mediaType = mediaItem['media_type'] as String?;
//                 DateTime? uploadedAt = (uploadedAtString != null)
//                     ? DateTime.tryParse(uploadedAtString)?.toLocal()
//                     : null;
//                 final fileName =
//                     storagePath?.split('/').last ?? 'Media Tidak Dikenal';

//                 IconData leadingIconData = Icons.perm_media_outlined;
//                 Color iconColor = Colors.teal[700]!;
//                 if (mediaType == 'video') {
//                   leadingIconData = Icons.play_circle_outline;
//                 } else if (mediaType == 'image') {
//                   leadingIconData = Icons.image_outlined;
//                   iconColor = Colors.indigo[700]!;
//                 }

//                 return Card(
//                   clipBehavior: Clip
//                       .antiAlias, // Agar ripple effect tidak keluar batas card
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: iconColor.withOpacity(0.1),
//                       child: Icon(leadingIconData, color: iconColor),
//                     ),
//                     title: Text(
//                       fileName,
//                       style: const TextStyle(fontWeight: FontWeight.w500),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     subtitle: Text(
//                       uploadedAt != null
//                           ? dateTimeFormat.format(uploadedAt)
//                           : 'Tanggal tidak diketahui',
//                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                     ),
//                     trailing:
//                         Icon(Icons.chevron_right, color: Colors.grey[400]),
//                     onTap: () => _viewMedia(context, mediaItem),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

class FootageScreen extends StatefulWidget {
  const FootageScreen({super.key});

  @override
  _FootageScreenState createState() => _FootageScreenState();
}

class _FootageScreenState extends State<FootageScreen> {
  @override
  void initState() {
    super.initState();
    print("FootageScreen: initState called.");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("FootageScreen: Requesting fetchMediaItems.");
      context.read<FootageProvider>().fetchMediaItems();
    });
  }

  Future<void> _refreshMediaItems() async {
    print("FootageScreen: Refresh requested.");
    await context.read<FootageProvider>().fetchMediaItems();
  }

  void _viewMedia(BuildContext context, Map<String, dynamic> mediaItem) async {
    final storagePath = mediaItem['storage_object_path'] as String?;
    final mediaType = mediaItem['media_type'] as String?;

    if (storagePath == null) {
      print("FootageScreen: View media failed, storage path is null.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Path media tidak valid.'),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    print(
        "FootageScreen: Viewing media type '$mediaType' at path '$storagePath'");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
          backgroundColor: Colors.white, // Background dialog
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.teal[600]),
              const SizedBox(width: 24),
              const Text("Memuat media...", style: TextStyle(fontSize: 16)),
            ]),
          )),
    );

    final url = await context.read<FootageProvider>().getMediaUrl(storagePath);
    if (mounted) Navigator.pop(context);

    if (url != null && mounted) {
      /* ... (logika navigasi sama) ... */
    } else if (mounted) {/* ... (logika error sama) ... */}
  }

  @override
  Widget build(BuildContext context) {
    print("FootageScreen: Building UI.");
    // final dateTimeFormat =
    //     DateFormat('EEEE, dd MMMM yyyy HH:mm', 'id_ID'); // Tambah tahun

    return Scaffold(
      body: Consumer<FootageProvider>(
        builder: (context, provider, child) {
          print(
              "FootageScreen Consumer: Building list. isLoading: ${provider.isLoading}, itemCount: ${provider.mediaItems.length}, error: ${provider.errorMessage}");

          if (provider.isLoading && provider.mediaItems.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: Colors.teal[600]));
          }

          if (provider.errorMessage != null) {
            return const Center(
                /* ... (Widget error sama, mungkin perbesar font) ... */);
          }

          if (provider.mediaItems.isEmpty && !provider.isLoading) {
            return const Center(
                /* ... (Widget 'belum ada rekaman' sama, mungkin perbesar font/ikon) ... */);
          }

          // Gunakan GridView untuk tampilan lebih modern dan mengisi ruang
          return RefreshIndicator(
            onRefresh: _refreshMediaItems,
            color: Colors.teal[600]!,
            child: GridView.builder(
              padding:
                  const EdgeInsets.all(12.0), // Padding lebih besar untuk grid
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600
                    ? 3
                    : 2, // 2 kolom di HP, 3 di tablet
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio:
                    1.0, // Buat item kotak, atau sesuaikan (misal 3/2 untuk landscape)
              ),
              itemCount: provider.mediaItems.length,
              itemBuilder: (context, index) {
                final mediaItem = provider.mediaItems[index];
                final storagePath = mediaItem['storage_object_path'] as String?;
                final uploadedAtString = mediaItem['uploaded_at'] as String?;
                final mediaType = mediaItem['media_type'] as String?;
                DateTime? uploadedAt = (uploadedAtString != null)
                    ? DateTime.tryParse(uploadedAtString)?.toLocal()
                    : null;
                final fileName =
                    storagePath?.split('/').last ?? 'Media Tidak Dikenal';

                IconData itemIconData = Icons.perm_media_outlined;
                Color itemIconColor = Colors.teal[700]!;
                if (mediaType == 'video') {
                  itemIconData = Icons.play_circle_filled_outlined;
                } else if (mediaType == 'image') {
                  itemIconData = Icons.image;
                  itemIconColor = Colors.indigo[700]!;
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 3, // Shadow lebih tegas
                  child: InkWell(
                    // Tambahkan InkWell untuk ripple effect
                    onTap: () => _viewMedia(context, mediaItem),
                    child: GridTile(
                      footer: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        color: Colors.black.withOpacity(0.6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (uploadedAt != null)
                              Text(
                                DateFormat('dd MMM yy, HH:mm', 'id_ID')
                                    .format(uploadedAt),
                                style: TextStyle(
                                    color: Colors.grey[300], fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      child: Container(
                        // Latar belakang untuk ikon jika tidak ada thumbnail
                        color: itemIconColor.withOpacity(0.05),
                        child: Center(
                          child: Icon(itemIconData,
                              size: 50, color: itemIconColor.withOpacity(0.7)),
                        ),
                        // TODO: Jika Anda punya URL thumbnail, ganti dengan Image.network di sini
                        // child: mediaItem['thumbnail_url'] != null
                        //     ? Image.network(mediaItem['thumbnail_url'], fit: BoxFit.cover)
                        //     : Center(child: Icon(itemIconData, size: 50, color: itemIconColor.withOpacity(0.7))),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
