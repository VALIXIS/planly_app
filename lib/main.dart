import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/tasks/ui/home_screen.dart';
import 'features/tasks/ui/calendar_screen.dart';
import 'features/tasks/models/task_model.dart'; // typed Hive Task model

// 🌟 Global key for SnackBar (prevents stuck SnackBars)
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter()); // register your Task model
  final box = await Hive.openBox<Task>('tasks'); // typed box

  // ✅ Clear old Map-based tasks (safe for development)
  await box.clear();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planly',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // ⚡ Key added here
      theme: ThemeData(
        useMaterial3: true,

        // 💜 Background
        scaffoldBackgroundColor: const Color(0xFFF5F3FF),

        // 💜 Theme colors
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB39DDB),
        ),

        // 💜 AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),

        // 💜 SnackBar FIX
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF9575CD),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const MainScreen(),
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

  final List<Widget> screens = const [
    HomeScreen(),
    CalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF9575CD),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Tasks",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Calendar",
          ),
        ],
      ),
    );
  }
}