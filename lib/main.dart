import 'package:flutter/material.dart';
import 'features/tasks/ui/splash_screen.dart';
import 'features/tasks/ui/onboarding_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/tasks/ui/home_screen.dart';
import 'features/tasks/ui/calendar_screen.dart';
import 'features/tasks/ui/settings_screen.dart';
import 'features/tasks/models/task_model.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'services/admob_service.dart';

// 🌟 Global SnackBar key
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// 🌙 Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// 🎨 Global accent color notifier
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(
  const Color(0xFF7C4DFF),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📦 Init Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  await Hive.openBox<Task>('tasks');

  // ⚙️ Settings box
  await Hive.openBox('settings');
  final settings = Hive.box('settings');

  // 🌙 Load dark mode
  final isDark = settings.get('isDarkMode', defaultValue: false) as bool;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // 🎨 Load accent color
  final savedColor =
      settings.get('accentColor', defaultValue: 0xFF7C4DFF) as int;
  accentColorNotifier.value = Color(savedColor);


  // 🔔 Init notifications
  await NotificationService().init();

  // 📊 Init analytics
  await AnalyticsService.init();
  await AnalyticsService.logAppOpen();

  // Ads SDK init
  await AdMobService.initialize();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to BOTH theme mode AND accent color
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: accentColorNotifier,
          builder: (context, accentColor, _) {
            // Derive a readable onPrimary color
            final onPrimary = accentColor.computeLuminance() > 0.4
                ? Colors.black
                : Colors.white;

            return MaterialApp(
              title: 'Planly',
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              themeMode: mode,
              themeAnimationDuration: Duration.zero,
              themeAnimationCurve: Curves.linear,

              // ☀️ LIGHT THEME — uses dynamic accent color
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme(
                  brightness: Brightness.light,
                  primary: accentColor,
                  onPrimary: onPrimary,
                  secondary: accentColor.withValues(alpha: 0.6),
                  onSecondary: Colors.black,
                  error: Colors.red,
                  onError: Colors.white,
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
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor: accentColor,
                  elevation: 2,
                ),
                textTheme: const TextTheme(
                  titleLarge: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
                  bodySmall: TextStyle(color: Colors.grey),
                ),
              ),

              // 🌙 DARK THEME — uses dynamic accent color (lighter)
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme(
                  brightness: Brightness.dark,
                  primary: accentColor.withValues(alpha: 0.85),
                  onPrimary: onPrimary,
                  secondary: accentColor.withValues(alpha: 0.5),
                  onSecondary: Colors.white,
                  error: Colors.redAccent,
                  onError: Colors.black,
                  surface: const Color(0xFF1E1E1E),
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
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor: accentColor.withValues(alpha: 0.85),
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
                    color: Colors.white,
                  ),
                  bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
                  bodySmall: TextStyle(color: Colors.grey),
                ),
              ),

              // ✅ App starts in onboarding once, then persists and enters splash/main
              home: ValueListenableBuilder(
                valueListenable: Hive.box('settings').listenable(
                  keys: const ['onboardingDone'],
                ),
                builder: (context, _, _) {
                  final onboardingDone =
                      Hive.box('settings').get(
                            'onboardingDone',
                            defaultValue: false,
                          ) as bool;

                  if (!onboardingDone) {
                    return OnboardingScreen(
                      onFinish: () {
                        Hive.box('settings').put('onboardingDone', true);
                      },
                    );
                  }

                  return const SplashScreen(nextScreen: MainScreen());
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MainScreen — bottom nav + AppBar actions
// ─────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [HomeScreen(), CalendarScreen()];

  void _toggleTheme() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    Hive.box('settings').put('isDarkMode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Planly"),
            actions: [
              // 🌙 Theme toggle
              IconButton(
                tooltip: isDark ? "Switch to Light" : "Switch to Dark",
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: _toggleTheme,
              ),
              // ⚙️ Settings
              IconButton(
                tooltip: "Settings",
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),
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
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
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
