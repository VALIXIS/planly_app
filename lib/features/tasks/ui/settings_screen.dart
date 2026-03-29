import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../main.dart' show themeNotifier, accentColorNotifier;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // ── 20 aesthetic, muted-but-rich accent colors ──
  final List<Map<String, dynamic>> _colors = [
    // Purples & Violets
    {"label": "Violet",    "color": const Color(0xFF7C4DFF)},
    {"label": "Lavender",  "color": const Color(0xFF9575CD)},
    {"label": "Mauve",     "color": const Color(0xFF8D6E9F)},
    // Blues
    {"label": "Indigo",    "color": const Color(0xFF3D5AFE)},
    {"label": "Ocean",     "color": const Color(0xFF1565C0)},
    {"label": "Steel",     "color": const Color(0xFF455A64)},
    {"label": "Sky",       "color": const Color(0xFF0288D1)},
    // Teals & Greens
    {"label": "Teal",      "color": const Color(0xFF00695C)},
    {"label": "Sage",      "color": const Color(0xFF558B6E)},
    {"label": "Forest",    "color": const Color(0xFF2E7D32)},
    // Warm tones
    {"label": "Amber",     "color": const Color(0xFFE65100)},
    {"label": "Sienna",    "color": const Color(0xFF8D5524)},
    {"label": "Rose",      "color": const Color(0xFFC2185B)},
    {"label": "Coral",     "color": const Color(0xFFD84315)},
    // Neutrals & Slates
    {"label": "Slate",     "color": const Color(0xFF37474F)},
    {"label": "Graphite",  "color": const Color(0xFF424242)},
    {"label": "Plum",      "color": const Color(0xFF6A1B4D)},
    {"label": "Burgundy",  "color": const Color(0xFF7B1C1C)},
    {"label": "Navy",      "color": const Color(0xFF1A237E)},
    {"label": "Midnight",  "color": const Color(0xFF1C1C3A)},
  ];

  // ── Load settings from Hive ─────────────────────
  bool get _showSplashQuote =>
      Hive.box('settings').get('showSplashQuote', defaultValue: true) as bool;

  bool get _showHomeQuote =>
      Hive.box('settings').get('showHomeQuote', defaultValue: true) as bool;

  String get _selectedLanguage =>
      Hive.box('settings').get('language', defaultValue: 'English') as String;

  void _saveSetting(String key, dynamic value) {
    Hive.box('settings').put(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final selectedColor = accentColorNotifier.value;
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ══════════════════════════════════════════
          // APPEARANCE
          // ══════════════════════════════════════════
          _sectionHeader("Appearance", isDark),
          const SizedBox(height: 10),

          // Dark mode toggle
          _SettingsTile(
            cardColor: cardColor,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                return _SwitchRow(
                  icon: Icons.dark_mode_outlined,
                  label: "Dark Mode",
                  iconColor: iconColor,
                  textColor: textColor,
                  value: mode == ThemeMode.dark,
                  activeColor: primary,
                  onChanged: (val) {
                    themeNotifier.value =
                        val ? ThemeMode.dark : ThemeMode.light;
                    Hive.box('settings').put('isDarkMode', val);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════════
          // ACCENT COLOR
          // ══════════════════════════════════════════
          _sectionHeader("Accent Color", isDark),
          const SizedBox(height: 10),

          _SettingsTile(
            cardColor: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose your app color",
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 16),
                // Color grid — 5 per row
                Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  children: _colors.map((item) {
                    final color = item["color"] as Color;
                    final label = item["label"] as String;
                    final isSelected = selectedColor.value == color.value;
                    return GestureDetector(
                      onTap: () {
                        accentColorNotifier.value = color;
                        Hive.box('settings').put('accentColor', color.value);
                        setState(() {});
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(
                                      color: color.withOpacity(0.45),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: subtitleColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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

          // ══════════════════════════════════════════
          // DISPLAY
          // ══════════════════════════════════════════
          _sectionHeader("Display", isDark),
          const SizedBox(height: 10),

          _SettingsTile(
            cardColor: cardColor,
            child: Column(
              children: [
                // Show quote on splash screen
                _SwitchRow(
                  icon: Icons.auto_awesome_outlined,
                  label: "Quote on Launch Screen",
                  subtitle: "Show motivational quote when app opens",
                  iconColor: iconColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  value: _showSplashQuote,
                  activeColor: primary,
                  onChanged: (val) => _saveSetting('showSplashQuote', val),
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06),
                ),
                // Show quote on home screen
                _SwitchRow(
                  icon: Icons.format_quote_rounded,
                  label: "Quote on Home Screen",
                  subtitle: "Show daily quote card on home",
                  iconColor: iconColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  value: _showHomeQuote,
                  activeColor: primary,
                  onChanged: (val) => _saveSetting('showHomeQuote', val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════════
          // LANGUAGE
          // ══════════════════════════════════════════
          _sectionHeader("Language", isDark),
          const SizedBox(height: 10),

          _SettingsTile(
            cardColor: cardColor,
            child: Row(
              children: [
                Icon(Icons.language_outlined, size: 20, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("App Language",
                          style: TextStyle(fontSize: 15, color: textColor)),
                      const SizedBox(height: 2),
                      Text(
                        "More languages coming soon",
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedLanguage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════════
          // DATA
          // ══════════════════════════════════════════
          _sectionHeader("Data", isDark),
          const SizedBox(height: 10),

          _SettingsTile(
            cardColor: cardColor,
            child: GestureDetector(
              onTap: () => _confirmClearAll(context, isDark),
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_outlined,
                      size: 20, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Clear All Tasks",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Permanently delete all tasks",
                          style: TextStyle(
                              fontSize: 12, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.red.shade300, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ══════════════════════════════════════════
          // ABOUT
          // ══════════════════════════════════════════
          _sectionHeader("About", isDark),
          const SizedBox(height: 10),

          _SettingsTile(
            cardColor: cardColor,
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
                    Text("Planly",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        )),
                    Text("Version 1.0.0",
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        )),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Clear all tasks confirmation dialog ─────────
  void _confirmClearAll(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear All Tasks"),
        content: const Text(
            "This will permanently delete all your tasks. This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await Hive.box<dynamic>('tasks').clear();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All tasks cleared"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text("Clear All",
                style: TextStyle(fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────
// Reusable card wrapper
// ─────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final Color cardColor;
  final Widget child;
  const _SettingsTile({required this.cardColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// Reusable switch row
// ─────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final Color textColor;
  final Color? subtitleColor;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.iconColor,
    required this.textColor,
    this.subtitleColor,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 15, color: textColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: subtitleColor)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}