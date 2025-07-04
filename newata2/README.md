# newata2

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

----------------------------------------------------------------------------------------------------------------------------------------------------------

Penjelasan Detail per Bagian Kode
1. main.dart
Ini adalah titik masuk (entry point) dari aplikasi Anda.

Future<void> main() async: Fungsi main dibuat async karena kita perlu menunggu proses inisialisasi selesai sebelum aplikasi berjalan.

WidgetsFlutterBinding.ensureInitialized(): Baris ini wajib ada ketika Anda ingin menjalankan kode sebelum runApp(), memastikan semua binding Flutter siap.

await dotenv.load(...): Memuat semua variabel dari file .env Anda (seperti URL dan Kunci Supabase) ke dalam memori.

await Supabase.initialize(...): Menginisialisasi koneksi ke proyek Supabase Anda. Ini adalah langkah krusial.

ChangeNotifierProvider(...): Ini berasal dari library provider. Ini "membungkus" seluruh aplikasi Anda dengan AppState, sehingga semua halaman di bawahnya dapat "mendengarkan" dan bereaksi terhadap perubahan data di AppState.

MyApp: Widget utama yang mengatur tema global aplikasi dan mendefinisikan halaman awal.

2. AppState (lib/provider/app_state.dart)
Ini adalah "otak" dari aplikasi Anda. Kelas ini mengelola semua data dan logika bisnis aplikasi (state management).

class AppState extends ChangeNotifier: ChangeNotifier adalah kelas dari Flutter yang memungkinkan AppState untuk "memberi tahu" para pendengarnya (widget) ketika ada data yang berubah, menggunakan notifyListeners().

Variabel State (_): Variabel yang diawali dengan _ (contoh: _isLoading) bersifat private. Data ini hanya bisa diubah dari dalam kelas AppState itu sendiri. Widget lain hanya bisa membacanya melalui getters (contoh: isLoading).

Constructor AppState(): Di sini kita mengatur pendengar onAuthStateChange. Ini adalah pendengar realtime dari Supabase yang aktif setiap kali ada perubahan status login (login, logout). Jika pengguna logout (_currentUser == null), kita memanggil clearState() untuk membersihkan semua data sesi sebelumnya.

_setLoading(bool value): Fungsi internal untuk mengontrol tampilan CircularProgressIndicator di seluruh aplikasi.

setDeviceIdAndFetchData(...): Fungsi ini dipanggil setelah login berhasil. Ia menyimpan deviceId, kemudian memanggil fungsi lain untuk mengambil data awal dan mulai mendengarkan perubahan realtime.

fetchEvents() & fetchDeviceStatus(): Fungsi ini mengambil data dari tabel Supabase (sensor_events dan device_status) menggunakan select(). Data ini kemudian disimpan dalam variabel state.

_listenToRealtimeChanges() (PERBAIKAN ERROR):

Fungsi ini sekarang menggunakan sintaks baru dari supabase_flutter v2.

supabase.channel(...): Membuat channel komunikasi realtime.

.onPostgresChanges(...): Ini adalah fungsi spesifik untuk mendengarkan perubahan pada database PostgreSQL Anda.

event: PostgresChangeEvent.insert: Hanya mendengarkan event INSERT (ketika ada data baru masuk).

schema: 'public', table: '...': Menentukan tabel mana yang ingin dipantau.

filter: ...: Filter tambahan agar kita hanya mendapatkan notifikasi untuk deviceId yang sedang dipantau.

.listen((payload) { ... }): Callback yang akan dieksekusi ketika ada data baru. payload.new berisi data baris yang baru saja ditambahkan.

setSleepSchedule(...): Fungsi ini dipanggil saat pengguna menekan tombol "Set Timer". Ia melakukan update() pada tabel device_status, mengisi kolom schedule_duration_microseconds dan setter_user_id dengan nilai yang baru.

3. Halaman SplashScreen (Baru)
StatefulWidget: Diperlukan karena kita perlu mengelola state selama proses navigasi.

initState(): Metode ini dipanggil sekali saat widget pertama kali dibuat. Di sinilah kita memulai timer.

Future.delayed(const Duration(seconds: 3), ...): Menjalankan kode di dalamnya setelah jeda 3 detik.

Navigator.pushReplacement(...): Setelah 3 detik, kita pindah ke AuthWrapper. pushReplacement digunakan agar pengguna tidak bisa kembali ke splash screen dengan menekan tombol "back".

4. AuthWrapper
Seperti yang dijelaskan, ini adalah widget tanpa tampilan yang berfungsi sebagai router cerdas.

Consumer<AppState>: Widget ini secara otomatis "mendengarkan" AppState. Setiap kali notifyListeners() dipanggil di AppState, bagian builder dari Consumer ini akan dieksekusi ulang.

if (appState.currentUser != null && appState.deviceId != null): Logika inti. Jika ada pengguna yang login DAN deviceId sudah diatur, tampilkan DashboardPage. Jika tidak, tampilkan LoginPage.

5. LoginPage
StatefulWidget & TextEditingController: Digunakan untuk mengelola input teks dari pengguna.

_formKey: Digunakan untuk validasi form (memastikan kolom tidak kosong).

_signIn():

Memeriksa validasi form.

Memanggil supabase.auth.signInWithPassword(...).

Jika berhasil, ia memanggil Provider.of<AppState>(context, listen: false).setDeviceIdAndFetchData(...) untuk memberi tahu AppState bahwa pengguna telah login dengan deviceId tertentu, sehingga AppState bisa mulai mengambil data.

Menangani AuthException jika login gagal (misalnya, password salah).

6. RegisterPage
Mirip dengan LoginPage, tetapi memanggil supabase.auth.signUp(...).

data: {'full_name': ...}: Ini adalah bagian penting. Di sinilah kita menyimpan data tambahan (nama lengkap) ke dalam kolom raw_user_meta_data di tabel auth.users Supabase.

7. DashboardPage & Komponen-komponennya
DashboardPage: Menggunakan CustomScrollView dan Sliver untuk layout yang efisien dan memungkinkan adanya refresh indicator.

ProfileBar: Mengambil data pengguna (fullName, email) dari AppState dan menampilkannya. Tombol logout memanggil appState.signOut().

SettingsBar:

Menampilkan status online/offline berdasarkan data dari _deviceStatus di AppState.

Tombol "Set Timer" hanya aktif jika isOnline == true.

_showSetTimerDialog(): Memunculkan TimePicker bawaan Flutter. Logikanya menghitung selisih antara waktu sekarang dan waktu yang dipilih pengguna, mengonversinya ke mikrodetik, lalu memanggil appState.setSleepSchedule() untuk mengirim data ke Supabase.

FootageGallery & FootageCard:

FootageGallery menampilkan SliverList dari FootageCard berdasarkan data _events di AppState.

FootageCard adalah kartu individu yang menampilkan gambar (Image.network), lokasi, tipe event, dan waktu kejadian. Desain kartu dibuat dengan BoxDecoration untuk memberikan efek bayangan (mirip 3D) dan sudut yang tumpul (borderRadius).