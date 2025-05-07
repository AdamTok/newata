// screens/login_screen.dart (Sudah Lengkap)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Pastikan path benar

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performLogin() async {
    print("LoginScreen: _performLogin called.");
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      print("LoginScreen: Form is valid.");
      final authProvider = context.read<AuthProvider>();
      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      print("LoginScreen: Form is invalid.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("LoginScreen: Building UI.");
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cut_outlined, size: 80, color: Colors.teal[400]),
                const SizedBox(height: 20),
                Text(
                  'Selamat Datang Kembali!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.teal[800]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk ke akun Anda',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Input Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Masukkan email Anda', // Tambah hint
                    prefixIcon:
                        Icon(Icons.email_outlined, color: Colors.grey[600]),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Validasi saat interaksi
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
                    hintText: 'Masukkan password Anda', // Tambah hint
                    prefixIcon:
                        Icon(Icons.lock_outline, color: Colors.grey[600]),
                    suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible)),
                  ),
                  obscureText: !_isPasswordVisible,
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Validasi saat interaksi
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Password tidak boleh kosong';
                    if (value.length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Tombol Login & Loading Indicator
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.currentUser != null &&
                        !authProvider.isLoading) {
                      print(
                          "LoginScreen Consumer: User detected (${authProvider.currentUser!.id}), navigating to dashboard.");
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.pushReplacementNamed(context, '/dashboard');
                        }
                      });
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: CircularProgressIndicator(color: Colors.teal),
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
                                  padding: const EdgeInsets.symmetric(
                                      vertical:
                                          14)), // Buat tombol lebih tinggi
                              child: const Text('Login',
                                  style: TextStyle(fontSize: 16)),
                              onPressed: _performLogin,
                            ),
                          );
                  },
                ),
                const SizedBox(height: 15),

                // Link ke Halaman Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Belum punya akun?",
                        style: TextStyle(color: Colors.grey[700])),
                    TextButton(
                      child: const Text('Daftar di sini'),
                      onPressed: () {
                        print("LoginScreen: Navigating to /register");
                        Navigator.pushNamed(context, '/register');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tampilkan Pesan Error
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    if (auth.errorMessage != null && !auth.isLoading) {
                      print(
                          "LoginScreen Consumer: Displaying error message: ${auth.errorMessage}");
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
