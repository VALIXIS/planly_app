import 'package:flutter/material.dart';
import 'features/tasks/ui/home_screen.dart';

class PlanlyApp extends StatelessWidget {
  const PlanlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planly',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),

        scaffoldBackgroundColor: const Color(0xFFF6F7FB),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          shape: CircleBorder(),
        ),
      ),

      home: const HomeScreen(),
    );
  }
}