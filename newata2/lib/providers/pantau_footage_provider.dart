// providers/footage_provider.dart (Sudah Lengkap)
import 'package:flutter/foundation.dart';

import '../constant.dart';
import '../main.dart';

class FootageProvider extends ChangeNotifier {
  final String? userId;
  FootageProvider(this.userId) {
    print("FootageProvider: Initialized with userId: $userId");
  }

  List<Map<String, dynamic>> _mediaItems = [];
  List<Map<String, dynamic>> get mediaItems => _mediaItems;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMediaItems() async {
    print("FootageProvider: fetchMediaItems called for userId: $userId");
    if (userId == null) {
      print("FootageProvider: fetchMediaItems aborted, userId is null.");
      _errorMessage = "User tidak terautentikasi.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await supabase
          .from('videos')
          .select(
              'id, user_id, storage_object_path, uploaded_at, media_type, metadata')
          .eq('user_id', userId!)
          .order('uploaded_at', ascending: false);

      _mediaItems = List<Map<String, dynamic>>.from(response as List);
      print(
          "FootageProvider: fetchMediaItems successful, found ${_mediaItems.length} items.");
    } catch (e) {
      print('FootageProvider: Error fetching media items: $e');
      _errorMessage = 'Gagal memuat daftar media: ${e.toString()}';
      _mediaItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getMediaUrl(String storagePath) async {
    print("FootageProvider: getMediaUrl called for path: $storagePath");
    try {
      final signedUrlResponse = await supabase.storage
          .from(AppConstants.footageBucket)
          .createSignedUrl(storagePath, 60 * 5); // Expire dalam 5 menit
      print("FootageProvider: Signed URL generated successfully.");
      return signedUrlResponse;
    } catch (e) {
      print('FootageProvider: Error getting media URL: $e');
      _errorMessage = 'Gagal mendapatkan URL media.';
      notifyListeners();
      return null;
    }
  }
}
