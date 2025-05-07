// providers/auth_provider.dart (Sudah Lengkap)
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  User? _currentUser;
  User? get currentUser => _currentUser;

  AuthProvider() {
    print("AuthProvider: Initializing...");
    _currentUser = _supabase.auth.currentUser;
    print("AuthProvider: Initial user state: ${_currentUser?.id ?? 'null'}");

    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      print(
          "AuthProvider: onAuthStateChange event: $event, session: ${session?.user.id ?? 'null'}");
      _currentUser = session?.user;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    });
    print("AuthProvider: Listener attached.");
  }

  void _setState({bool? loading, String? error}) {
    bool changed = false;
    final prevLoading = _isLoading;
    final prevError = _errorMessage;

    if (loading != null && _isLoading != loading) {
      _isLoading = loading;
      changed = true;
    }
    if (_errorMessage != error) {
      _errorMessage = error;
      changed = true;
    }
    if (changed) {
      print(
          "AuthProvider: State changed - isLoading: $prevLoading -> $_isLoading, error: '$prevError' -> '$_errorMessage'");
      notifyListeners();
    }
  }

  Future<bool> signUp(String email, String password) async {
    print("AuthProvider: signUp called with email: $email");
    _setState(loading: true, error: null);
    try {
      final AuthResponse res =
          await _supabase.auth.signUp(email: email, password: password);
      print(
          "AuthProvider: signUp successful for ${res.user?.email}. User: ${res.user?.id}, Session: ${res.session?.accessToken ?? 'null'}");
      _setState(loading: false, error: null);
      return true;
    } on AuthException catch (e) {
      print('AuthProvider: signUp AuthException: ${e.message}');
      _setState(loading: false, error: 'Registrasi gagal: ${e.message}');
      return false;
    } catch (e) {
      print('AuthProvider: signUp Unknown Error: $e');
      _setState(loading: false, error: 'Terjadi kesalahan tidak diketahui.');
      return false;
    }
  }

  Future<void> signIn(String email, String password) async {
    print("AuthProvider: signIn called with email: $email");
    _setState(loading: true, error: null);
    try {
      final AuthResponse res = await _supabase.auth
          .signInWithPassword(email: email, password: password);
      print(
          "AuthProvider: signIn successful for ${res.user?.email}. User: ${res.user?.id}, Session: ${res.session?.accessToken ?? 'null'}");
      _setState(loading: false, error: null);
    } on AuthException catch (e) {
      print('AuthProvider: signIn AuthException: ${e.message}');
      _setState(loading: false, error: 'Login gagal: ${e.message}');
    } catch (e) {
      print('AuthProvider: signIn Unknown Error: $e');
      _setState(loading: false, error: 'Terjadi kesalahan tidak diketahui.');
    }
  }

  Future<void> signOut() async {
    print("AuthProvider: signOut called for user: ${_currentUser?.id}");
    _setState(loading: true, error: null);
    try {
      await _supabase.auth.signOut();
      print("AuthProvider: signOut successful.");
      _setState(loading: false, error: null);
    } catch (e) {
      print('AuthProvider: signOut Error: $e');
      _setState(loading: false, error: 'Logout gagal: ${e.toString()}');
    }
  }
}
