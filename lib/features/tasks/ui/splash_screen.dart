import 'package:flutter/material.dart';

/// 🌅 SplashScreen
/// Shows a motivational quote with a time-based gradient background.
/// Quote + design changes 3 times per day (Morning / Afternoon / Evening).
/// Auto-navigates to MainScreen after 3 seconds with a fade transition.
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

  // ── Time slot: 0=Morning, 1=Afternoon, 2=Evening ──
  int get _timeSlot {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    return 2;
  }

  // ── 45 quotes — 15 per time slot ──────────────────
  final List<List<String>> _quotesBySlot = [
    // 🌅 Morning quotes (slot 0)
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
    // ☀️ Afternoon quotes (slot 1)
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
    // 🌙 Evening quotes (slot 2)
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

  // Pick quote based on time slot + day rotation
  String get _currentQuote {
    final slot = _timeSlot;
    final quotes = _quotesBySlot[slot];
    final dayIndex =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return quotes[dayIndex % quotes.length];
  }

  // ── Design config per time slot ────────────────────
  _SlotDesign get _design => _designs[_timeSlot];

  final List<_SlotDesign> _designs = [
    // 🌅 Morning — warm sunrise purples + gold
    _SlotDesign(
      gradientColors: [
        const Color(0xFF1A0533),
        const Color(0xFF3D1273),
        const Color(0xFF6B2FA0),
        const Color(0xFFB06AB3),
      ],
      gradientStops: [0.0, 0.3, 0.65, 1.0],
      glowColor: const Color(0xFFB06AB3),
      accentColor: const Color(0xFFFFD700),
      label: "Morning",
      labelIcon: Icons.wb_sunny_rounded,
      tagline: "Start strong. Own your day.",
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // ☀️ Afternoon — deep blue ocean
    _SlotDesign(
      gradientColors: [
        const Color(0xFF0A1628),
        const Color(0xFF0D2B55),
        const Color(0xFF1565C0),
        const Color(0xFF1E88E5),
      ],
      gradientStops: [0.0, 0.3, 0.65, 1.0],
      glowColor: const Color(0xFF1E88E5),
      accentColor: const Color(0xFF64B5F6),
      label: "Afternoon",
      labelIcon: Icons.wb_cloudy_rounded,
      tagline: "Keep the momentum going.",
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    // 🌙 Evening — dark teal midnight
    _SlotDesign(
      gradientColors: [
        const Color(0xFF0A1A1A),
        const Color(0xFF0D3333),
        const Color(0xFF00695C),
        const Color(0xFF00897B),
      ],
      gradientStops: [0.0, 0.3, 0.65, 1.0],
      glowColor: const Color(0xFF00897B),
      accentColor: const Color(0xFF80CBC4),
      label: "Evening",
      labelIcon: Icons.nights_stay_rounded,
      tagline: "Finish strong. Rest well.",
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ];

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

    // Auto-navigate after 3 seconds with fade
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => widget.nextScreen,
            transitionsBuilder: (_, animation, __, child) =>
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
    final design = _design;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ───────────────────────
          Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: design.begin,
                end: design.end,
                colors: design.gradientColors,
                stops: design.gradientStops,
              ),
            ),
          ),

          // ── Glow circle — top right ───────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: design.glowColor.withOpacity(0.18),
              ),
            ),
          ),

          // ── Glow circle — bottom left ─────────────────
          Positioned(
            bottom: 60,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: design.glowColor.withOpacity(0.12),
              ),
            ),
          ),

          // ── Small accent circle — mid right ───────────
          Positioned(
            top: size.height * 0.42,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Horizontal accent line ────────────────────
          Positioned(
            top: size.height * 0.52,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
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

                          // Time-of-day label badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: design.accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: design.accentColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  design.labelIcon,
                                  size: 13,
                                  color: design.accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  design.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: design.accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Large decorative quote mark
                          Text(
                            "\u201C",
                            style: TextStyle(
                              fontSize: 72,
                              height: 0.8,
                              color: Colors.white.withOpacity(0.12),
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
                            width: 36,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: design.accentColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // App name + tagline at bottom
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App name
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

                              // Tagline — changes per time slot
                              Text(
                                design.tagline,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 0.4,
                                ),
                              ),

                              const SizedBox(height: 36),

                              // Animated loading dots
                              _DotsLoader(accentColor: design.accentColor),

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
// Design config per time slot
// ─────────────────────────────────────────────
class _SlotDesign {
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Color glowColor;
  final Color accentColor;
  final String label;
  final IconData labelIcon;
  final String tagline;
  final Alignment begin;
  final Alignment end;

  const _SlotDesign({
    required this.gradientColors,
    required this.gradientStops,
    required this.glowColor,
    required this.accentColor,
    required this.label,
    required this.labelIcon,
    required this.tagline,
    required this.begin,
    required this.end,
  });
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
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            final phase = i / 3;
            final val = ((_ctrl.value - phase) % 1.0).abs();
            final opacity = (1.0 - val * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}