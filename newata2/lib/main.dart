// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/pantau_footage_provider.dart';
import 'providers/schedule_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/video_player_screen.dart'; // Pastikan path benar
import 'screens/image_viewer_screen.dart'; // Pastikan path benar

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("main: WidgetsFlutterBinding initialized."); // Log

  try {
    await dotenv.load(fileName: ".env");
    print("main: .env file loaded successfully."); // Log
  } catch (e) {
    print("main: Error loading .env file: $e"); // Log error
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print(
        "main: Supabase URL or Anon Key not found in .env file. App cannot initialize Supabase."); // Log error
    return;
  }
  print("main: Supabase URL and Anon Key found."); // Log

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print("main: Supabase initialized successfully."); // Log
  } catch (e) {
    print("main: Error initializing Supabase: $e"); // Log error
    return;
  }

  try {
    await initializeDateFormatting('id_ID', null);
    print("main: Date formatting initialized."); // Log
  } catch (e) {
    print("main: Error initializing date formatting: $e"); // Log error
  }

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("MyApp: Building..."); // Log
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FootageProvider>(
          create: (_) => FootageProvider(null),
          update: (_, auth, previousFootage) =>
              FootageProvider(auth.currentUser?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ScheduleProvider>(
          create: (_) => ScheduleProvider(null),
          update: (_, auth, previousSchedule) =>
              ScheduleProvider(auth.currentUser?.id),
        ),
      ],
      child: MaterialApp(
        title: 'CCTV IoT App',
        theme: ThemeData(
          // Tema tetap sama
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: Colors.grey[100],
          appBarTheme: AppBarTheme(
              backgroundColor: Colors.teal[600],
              elevation: 2,
              iconTheme:
                  const IconThemeData(color: Colors.white), // Warna ikon AppBar
              titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500) // Style title AppBar
              ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: Colors.teal[700],
            unselectedItemColor: Colors.grey[600],
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[500],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          )),
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
          ),
          listTileTheme: ListTileThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal[600],
            ),
          ),
          dialogTheme: DialogTheme(
            // Style untuk dialog (misal loading)
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            elevation: 5,
          ),
          timePickerTheme: TimePickerThemeData(
            // Style untuk TimePicker
            backgroundColor: Colors.white,
            hourMinuteShape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            dayPeriodShape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              side: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            dayPeriodColor: Colors.teal[50],
            dayPeriodTextColor: Colors.teal[800],
            hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.teal[100]!
                    : Colors.grey[100]!),
            hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.teal[900]!
                    : Colors.black54),
            dialHandColor: Colors.teal[300],
            dialBackgroundColor: Colors.teal[50],
            dialTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.teal[900]!),
            entryModeIconColor: Colors.teal[600],
            helpTextStyle: TextStyle(color: Colors.teal[800]),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/video_player': (context) => VideoPlayerScreen(
                videoUrl:
                    ModalRoute.of(context)?.settings.arguments as String? ?? '',
              ),
          '/image_viewer': (context) => ImageViewerScreen(
                imageUrl:
                    ModalRoute.of(context)?.settings.arguments as String? ?? '',
              ),
        },
      ),
    );
  }
}
