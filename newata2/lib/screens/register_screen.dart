// screens/register_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Pastikan path benar

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _performRegister() async {
    print("RegisterScreen: _performRegister called.");
    setState(() {
      _successMessage = null;
    });
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      print("RegisterScreen: Form is valid.");
      final authProvider = context.read<AuthProvider>();
      final bool success = await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted && success) {
        print("RegisterScreen: SignUp reported success from provider.");
        setState(() {
          _successMessage =
              "Registrasi berhasil! Jika konfirmasi email aktif, silakan cek email Anda sebelum login.";
        });
        _formKey.currentState?.reset();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else if (mounted) {
        print("RegisterScreen: SignUp reported failure from provider.");
      }
    } else {
      print("RegisterScreen: Form is invalid.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("RegisterScreen: Building UI.");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.teal[800],
        iconTheme: IconThemeData(color: Colors.teal[800]), // Warna ikon back
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_outlined,
                    size: 60, color: Colors.teal[400]),
                const SizedBox(height: 15),
                Text(
                  'Buat Akun Anda',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.teal[800]),
                ),
                const SizedBox(height: 25),

                // Input Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Masukkan email Anda',
                      prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Email tidak boleh kosong';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                      return 'Masukkan format email yang valid';
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Input Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible))),
                  obscureText: !_isPasswordVisible,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Password tidak boleh kosong';
                    if (value.length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Input Konfirmasi Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      hintText: 'Ulangi password',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      suffixIcon: IconButton(
                          icon: Icon(_isConfirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() =>
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible))),
                  obscureText: !_isConfirmPasswordVisible,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Konfirmasi password tidak boleh kosong';
                    if (value != _passwordController.text)
                      return 'Password tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Tampilkan Pesan Sukses jika ada
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Tombol Daftar & Loading Indicator
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (_successMessage != null) {
                      // Jika sukses, tampilkan tombol kembali ke login
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: BorderSide(color: Colors.teal[200]!),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Kembali ke Login'),
                        ),
                      );
                    }
                    return authProvider.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child:
                                CircularProgressIndicator(color: Colors.teal),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: _performRegister,
                              child: const Text('Daftar',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          );
                  },
                ),
                const SizedBox(height: 15),

                // Tampilkan Pesan Error (Hanya jika tidak ada pesan sukses)
                if (_successMessage == null)
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      if (auth.errorMessage != null && !auth.isLoading) {
                        print(
                            "RegisterScreen Consumer: Displaying error message: ${auth.errorMessage}");
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
