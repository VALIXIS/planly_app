import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../services/app_state_service.dart';

/// 🌅 SplashScreen
/// - Gradient uses the user's chosen accent color
/// - Quote + design changes 3x per day (Morning / Afternoon / Evening)
/// - Respects "Show quote on splash" setting
/// - Auto-navigates after 3 seconds with fade transition
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  // Time slot: 0=Morning, 1=Afternoon, 2=Evening
  int get _timeSlot {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    return 2;
  }

  bool get _showQuote =>
      Hive.box('settings').get('showSplashQuote', defaultValue: true) as bool;

  // 45 quotes — 15 per time slot
  final List<List<String>> _quotesBySlot = [
    // 🌅 Morning
    [
      "Today is a fresh start. Make it count.",
      "Rise up and attack the day with enthusiasm.",
      "The way you start your day sets the tone for everything.",
      "Your only limit is your mindset. Good morning.",
      "Small steps every morning lead to big results.",
      "Don't count the days. Make the days count.",
      "Every morning is a chance to be better than yesterday.",
      "You don't have to be great to start — but start.",
      "The secret of getting ahead is getting started.",
      "Believe in yourself and your morning will believe in you.",
      "Wake up with determination. Go to bed with satisfaction.",
      "Today's goals are tomorrow's achievements.",
      "Discipline is choosing what you want most.",
      "One productive morning changes your entire day.",
      "Make each morning a masterpiece.",
    ],
    // ☀️ Afternoon
    [
      "Keep the momentum going. You've already started.",
      "Halfway through — don't stop now.",
      "The afternoon is where great work happens.",
      "Focus on progress, not perfection.",
      "Done is better than perfect.",
      "Every task you finish brings you closer.",
      "Stay consistent. Consistency beats talent.",
      "Push through the afternoon slump. You've got this.",
      "Work hard in silence. Let results make the noise.",
      "You are what you repeatedly do.",
      "Excellence is a habit, not an act.",
      "Your future self will thank you for today's effort.",
      "One task at a time. That's all it takes.",
      "Productivity is never an accident.",
      "Keep going. The best is yet to come.",
    ],
    // 🌙 Evening
    [
      "Wrap up strong. Finish what you started.",
      "How you end your day defines tomorrow.",
      "Every evening is a chance to reflect and reset.",
      "Great things never come from comfort zones.",
      "Rest is not giving up. It's gearing up.",
      "Your evening effort shapes your morning.",
      "The day is almost done — give it your best finish.",
      "Finish strong. Every. Single. Time.",
      "Success is the sum of small efforts repeated daily.",
      "Review today. Plan tomorrow. Rest well.",
      "Discipline tonight creates freedom tomorrow.",
      "The evening is proof of what your day was worth.",
      "Wind down with gratitude. You showed up today.",
      "The most productive evenings belong to those who planned.",
      "End your day well so tomorrow starts well.",
    ],
  ];

  String get _currentQuote {
    final slot = _timeSlot;
    final quotes = _quotesBySlot[slot];
    final dayIndex = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return quotes[dayIndex % quotes.length];
  }

  // Time-of-day labels + icons
  final List<String> _labels = ["Morning", "Afternoon", "Evening"];
  final List<IconData> _icons = [
    Icons.wb_sunny_rounded,
    Icons.wb_cloudy_rounded,
    Icons.nights_stay_rounded,
  ];
  final List<String> _taglines = [
    "Start strong. Own your day.",
    "Keep the momentum going.",
    "Finish strong. Rest well.",
  ];

  // Gradient direction changes per slot
  final List<List<Alignment>> _directions = [
    [Alignment.topLeft, Alignment.bottomRight],
    [Alignment.topRight, Alignment.bottomLeft],
    [Alignment.topCenter, Alignment.bottomCenter],
  ];

  int _scaledChannel(double channel, double factor) =>
      (channel * 255.0 * factor).round().clamp(0, 255);

  int _mixWithWhite(double channel, double amount) {
    final base = channel * 255.0;
    return (base + (255.0 - base) * amount).round().clamp(0, 255);
  }

  // Builds gradient using user's accent color
  List<Color> _buildGradient(Color accent) {
    // Darken the accent for the dark end of the gradient
    final dark = Color.fromARGB(
      255,
      _scaledChannel(accent.r, 0.15),
      _scaledChannel(accent.g, 0.10),
      _scaledChannel(accent.b, 0.15),
    );
    final mid = Color.fromARGB(
      255,
      _scaledChannel(accent.r, 0.35),
      _scaledChannel(accent.g, 0.25),
      _scaledChannel(accent.b, 0.40),
    );
    final light = Color.fromARGB(
      255,
      _scaledChannel(accent.r, 0.65),
      _scaledChannel(accent.g, 0.50),
      _scaledChannel(accent.b, 0.70),
    );
    return [dark, mid, light, accent.withValues(alpha: 0.75)];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideUp = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, _, _) => widget.nextScreen,
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final slot = _timeSlot;
    final showQuote = _showQuote;

    // Use user's accent color for gradient
    final accent = AppStateService.accentColorNotifier.value;
    final gradientColors = _buildGradient(accent);
    final glowColor = accent;
    // Accent highlight — lighter tint for badges/dots
    final highlight = Color.fromARGB(
      255,
      _mixWithWhite(accent.r, 0.5),
      _mixWithWhite(accent.g, 0.5),
      _mixWithWhite(accent.b, 0.5),
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background (accent-based) ────────
          Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _directions[slot][0],
                end: _directions[slot][1],
                colors: gradientColors,
                stops: const [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),

          // ── Glow circles ──────────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: -100,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.42, right: -30,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // ── Subtle horizontal line ─────────────────────
          Positioned(
            top: size.height * 0.52, left: 0, right: 0,
            child: Container(height: 1,
                color: Colors.white.withValues(alpha: 0.05)),
          ),

          // ── Main content ──────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeIn.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),

                          if (showQuote) ...[
                            // Time-of-day badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: highlight.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: highlight.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_icons[slot],
                                      size: 13, color: highlight),
                                  const SizedBox(width: 6),
                                  Text(
                                    _labels[slot],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: highlight,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Decorative quote mark
                            Text(
                              "\u201C",
                              style: TextStyle(
                                fontSize: 72,
                                height: 0.8,
                                color: Colors.white.withValues(alpha: 0.12),
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Quote text
                            Text(
                              _currentQuote,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                height: 1.6,
                                letterSpacing: 0.1,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Accent divider
                            Container(
                              width: 36, height: 2.5,
                              decoration: BoxDecoration(
                                color: highlight.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],

                          const Spacer(flex: 3),

                          // App name + tagline
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Planly",
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -2,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _taglines[slot],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 36),
                              _DotsLoader(accentColor: highlight),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Animated loading dots
// ─────────────────────────────────────────────
class _DotsLoader extends StatefulWidget {
  final Color accentColor;
  const _DotsLoader({required this.accentColor});

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          children: List.generate(3, (i) {
            final phase = i / 3;
            final val = ((_ctrl.value - phase) % 1.0).abs();
            final opacity = (1.0 - val * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 5, height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
