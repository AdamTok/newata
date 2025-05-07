// screens/image_viewer_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    print("ImageViewerScreen: Building UI with URL: $imageUrl");
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Penampil Gambar'),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (BuildContext context, Widget child,
                ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (BuildContext context, Object exception,
                StackTrace? stackTrace) {
              print("ImageViewerScreen: Error loading image: $exception");
              return Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined,
                      color: Colors.grey[600], size: 60),
                  const SizedBox(height: 10),
                  Text('Gagal memuat gambar',
                      style: TextStyle(color: Colors.grey[400])),
                ],
              ));
            },
          ),
        ),
      ),
    );
  }
}
