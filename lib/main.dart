import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/tasks/models/tag_model.dart';
import 'features/tasks/models/task_model.dart';
import 'features/tasks/ui/calendar_screen.dart';
import 'features/tasks/ui/home_screen.dart';
import 'features/tasks/ui/notification_reliability_wizard_screen.dart';
import 'features/tasks/ui/onboarding_screen.dart';
import 'features/tasks/ui/settings_screen.dart';
import 'features/tasks/ui/splash_screen.dart';
import 'services/admob_service.dart';
import 'services/app_state_service.dart';
import 'services/notification_service.dart';
import 'services/task_action_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TagModelAdapter());
  Hive.registerAdapter(TaskSubtaskAdapter());
  await Hive.openBox<Task>('tasks');
  final tagBox = await Hive.openBox<TagModel>('tags');
  if (tagBox.isEmpty) {
    await tagBox.addAll([
      TagModel(name: 'work', colorValue: 0xFF42A5F5),
      TagModel(name: 'personal', colorValue: 0xFF66BB6A),
      TagModel(name: 'urgent', colorValue: 0xFFEF5350),
    ]);
  }
  await Hive.openBox('settings');

  AppStateService.loadPersistedSettings();

  await NotificationService().init();
  await TaskActionService.resyncAllUpcomingReminders();
  await AdMobService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppStateService.themeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: AppStateService.accentColorNotifier,
          builder: (context, accentColor, _) {
            final onPrimary = accentColor.computeLuminance() > 0.4
                ? Colors.black
                : Colors.white;

            return MaterialApp(
              title: 'Planly',
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: AppStateService.rootScaffoldMessengerKey,
              themeMode: mode,
              themeAnimationDuration: Duration.zero,
              themeAnimationCurve: Curves.linear,
              theme: _buildLightTheme(accentColor, onPrimary),
              darkTheme: _buildDarkTheme(accentColor, onPrimary),
              home: ValueListenableBuilder(
                valueListenable: Hive.box('settings').listenable(
                  keys: const ['onboardingDone'],
                ),
                builder: (context, _, _) {
                  final onboardingDone = Hive.box('settings').get(
                    'onboardingDone',
                    defaultValue: false,
                  ) as bool;

                  if (!onboardingDone) {
                    return OnboardingScreen(
                      onFinish: () {
                        AppStateService.setOnboardingDone();
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

  ThemeData _buildLightTheme(Color accentColor, Color onPrimary) {
    return ThemeData(
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
      pageTransitionsTheme: _pageTransitionsTheme(),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
        bodySmall: TextStyle(color: Colors.grey),
      ),
    );
  }

  ThemeData _buildDarkTheme(Color accentColor, Color onPrimary) {
    return ThemeData(
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
      pageTransitionsTheme: _pageTransitionsTheme(),
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
    );
  }

  PageTransitionsTheme _pageTransitionsTheme() {
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  late final PageController _pageController;
  bool _reliabilityWizardCheckQueued = false;

  final List<Widget> screens = const [HomeScreen(), CalendarScreen()];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _showReliabilityWizardOnceIfNeeded();
  }

  void _showReliabilityWizardOnceIfNeeded() {
    if (!NotificationService.isAndroidDevice || _reliabilityWizardCheckQueued) {
      return;
    }

    _reliabilityWizardCheckQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || AppStateService.isReliabilityWizardSeen) return;

      await AppStateService.setReliabilityWizardSeen(true);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NotificationReliabilityWizardScreen(
            fromFirstLaunch: true,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppStateService.themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Planly'),
            actions: [
              IconButton(
                tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: AppStateService.toggleTheme,
              ),
              IconButton(
                tooltip: 'Settings',
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
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() => currentIndex = index);
            },
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            height: 70,
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 2,
            indicatorColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
            ],
          ),
        );
      },
    );
  }
}
