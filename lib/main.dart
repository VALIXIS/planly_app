import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/tasks/ui/home_screen.dart';
import 'features/tasks/ui/calendar_screen.dart';
import 'features/tasks/models/task_model.dart';
import 'services/notification_service.dart';

// 🌟 Global SnackBar key
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// 🌙 Global theme notifier — toggle from anywhere in the app
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📦 Init Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  await Hive.openBox<Task>('tasks');

  // ⚙️ Settings box — persists dark mode preference
  await Hive.openBox('settings');
  final settings = Hive.box('settings');
  final isDark = settings.get('isDarkMode', defaultValue: false) as bool;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // 🔔 Init notification service
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Planly',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          themeMode: mode,

          // ✅ Instant theme switching — no slow fade animation
          themeAnimationDuration: Duration.zero,
          themeAnimationCurve: Curves.linear,

          // ☀️ LIGHT THEME
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Color(0xFF7C4DFF),
              onPrimary: Colors.white,
              secondary: Color(0xFFB39DDB),
              onSecondary: Colors.black,
              error: Colors.red,
              onError: Colors.white,
              background: Color(0xFFF8F7FC),
              onBackground: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F7FC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 1.5,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF2E2E2E),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF7C4DFF),
              elevation: 2,
            ),
            textTheme: const TextTheme(
              titleLarge:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
              bodySmall: TextStyle(color: Colors.grey),
            ),
          ),

          // 🌙 DARK THEME
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: const ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFFB39DDB),
              onPrimary: Colors.black,
              secondary: Color(0xFF7C4DFF),
              onSecondary: Colors.white,
              error: Colors.redAccent,
              onError: Colors.black,
              background: Color(0xFF121212),
              onBackground: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 2,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF383838),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFFB39DDB),
              elevation: 2,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            textTheme: const TextTheme(
              titleLarge: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
              bodySmall: TextStyle(color: Colors.grey),
            ),
          ),

          home: const MainScreen(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MainScreen — bottom nav + theme toggle in AppBar
// ─────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    CalendarScreen(),
  ];

  void _toggleTheme() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;

    // 💾 Persist preference to Hive
    Hive.box('settings').put('isDarkMode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;

        return Scaffold(
          // Theme toggle lives in a floating AppBar action
          appBar: AppBar(
            title: const Text("Planly"),
            actions: [
              IconButton(
                tooltip: isDark ? "Switch to Light" : "Switch to Dark",
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: _toggleTheme,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: screens[currentIndex],
          bottomNavigationBar: NavigationBar(
            height: 70,
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              setState(() => currentIndex = index);
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 2,
            indicatorColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: "Tasks",
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: "Calendar",
              ),
            ],
          ),
        );
      },
    );
  }
}