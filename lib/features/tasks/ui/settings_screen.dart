import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../main.dart' show themeNotifier, accentColorNotifier;

/// 🎨 Settings Screen
/// - Custom accent color picker
/// - Dark mode toggle
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Available accent colors
  final List<Map<String, dynamic>> _colors = [
    {"label": "Violet",     "color": const Color(0xFF7C4DFF)},
    {"label": "Indigo",     "color": const Color(0xFF3D5AFE)},
    {"label": "Blue",       "color": const Color(0xFF2196F3)},
    {"label": "Teal",       "color": const Color(0xFF009688)},
    {"label": "Green",      "color": const Color(0xFF4CAF50)},
    {"label": "Amber",      "color": const Color(0xFFFFC107)},
    {"label": "Orange",     "color": const Color(0xFFFF6D00)},
    {"label": "Pink",       "color": const Color(0xFFE91E63)},
    {"label": "Red",        "color": const Color(0xFFF44336)},
    {"label": "Brown",      "color": const Color(0xFF795548)},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final selectedColor = accentColorNotifier.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Appearance section ──────────────────────
          _sectionHeader("Appearance", isDark),
          const SizedBox(height: 10),

          // Dark mode toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                final isDarkMode = mode == ThemeMode.dark;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dark_mode_outlined,
                            size: 20,
                            color: isDark
                                ? Colors.white70
                                : Colors.black54),
                        const SizedBox(width: 12),
                        Text(
                          "Dark Mode",
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isDarkMode,
                      activeColor: primary,
                      onChanged: (val) {
                        themeNotifier.value =
                            val ? ThemeMode.dark : ThemeMode.light;
                        Hive.box('settings')
                            .put('isDarkMode', val);
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Accent color section ────────────────────
          _sectionHeader("Accent Color", isDark),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose your app color",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 16),

                // Color grid
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((item) {
                    final color = item["color"] as Color;
                    final label = item["label"] as String;
                    final isSelected =
                        selectedColor.value == color.value;

                    return GestureDetector(
                      onTap: () {
                        // ✅ Update accent color globally
                        accentColorNotifier.value = color;
                        Hive.box('settings').put(
                            'accentColor', color.value);
                        setState(() {});
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                        ? Colors.white
                                        : Colors.black)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color:
                                            color.withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── About section ───────────────────────────
          _sectionHeader("About", isDark),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.task_alt_rounded,
                      color: primary, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Planly",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}