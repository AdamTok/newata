// screens/video_player_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print("VideoPlayerScreen: initState called with URL: ${widget.videoUrl}");
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.videoUrl.isEmpty || !Uri.tryParse(widget.videoUrl)!.isAbsolute) {
      print("VideoPlayerScreen: Invalid URL provided.");
      setState(() {
        _isLoading = false;
        _errorMessage = "URL Video tidak valid.";
      });
      return;
    }
    try {
      print("VideoPlayerScreen: Initializing video controller...");
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController!.initialize();
      print("VideoPlayerScreen: Video controller initialized.");

      print("VideoPlayerScreen: Initializing Chewie controller...");
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.teal,
          handleColor: Colors.teal[300]!,
          bufferedColor: Colors.teal[100]!,
          backgroundColor:
              Colors.blueGrey[600]!, // Sesuaikan warna background progress
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(
                  color: Colors.white70)), // Buat lebih redup
        ),
        autoInitialize: true,
        // Opsi tambahan:
        // showControlsOnInitialize: false,
        // allowedScreenSleep: false, // Jaga layar tetap nyala
        errorBuilder: (context, errorMessage) {
          print(
              "VideoPlayerScreen: Chewie errorBuilder: $errorMessage"); // Log error Chewie
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white70, size: 40),
                const SizedBox(height: 8),
                const Text('Gagal memutar video',
                    style: TextStyle(color: Colors.white70)),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      );
      print("VideoPlayerScreen: Chewie controller initialized.");
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print("VideoPlayerScreen: Error initializing video player: $e");
      print(stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = "Gagal memuat video.";
      });
    }
  }

  @override
  void dispose() {
    print("VideoPlayerScreen: dispose called.");
    _videoPlayerController?.dispose();
    _chewieController?.dispose(); // Chewie controller juga perlu di-dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        "VideoPlayerScreen: Building UI. isLoading: $_isLoading, error: $_errorMessage");
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pemutar Video'),
        backgroundColor:
            Colors.black.withOpacity(0.7), // AppBar sedikit transparan
        elevation: 0,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  )
                // Pastikan chewieController tidak null SEBELUM menampilkannya
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const Column(
                        // Fallback jika chewie controller gagal dibuat
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.white70, size: 40),
                          SizedBox(height: 10),
                          Text("Gagal menyiapkan pemutar video.",
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
      ),
    );
  }
}
