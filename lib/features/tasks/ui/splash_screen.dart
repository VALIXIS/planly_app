import 'package:flutter/material.dart';

/// 🌅 SplashScreen
/// Shows a motivational quote + app name on a beautiful gradient background.
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

  // Daily quote — same logic as home screen
  final List<String> _quotes = [
    "Small steps every day lead to big results.",
    "Done is better than perfect.",
    "Focus on progress, not perfection.",
    "You don't have to be great to start, but you have to start to be great.",
    "One task at a time. That's all it takes.",
    "Your future self is watching. Make them proud.",
    "Discipline is choosing what you want most over what you want now.",
    "The secret of getting ahead is getting started.",
    "Productivity is never an accident. It's the result of commitment.",
    "Every completed task is a step closer to your goal.",
    "Work hard in silence. Let results make the noise.",
    "Don't count the days. Make the days count.",
    "Success is the sum of small efforts repeated daily.",
    "Push yourself, because no one else is going to do it for you.",
    "Great things never come from comfort zones.",
  ];

  String get _todayQuote {
    final dayIndex = DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays %
        _quotes.length;
    return _quotes[dayIndex];
  }

  @override
  void initState() {
    super.initState();

    // Fade + slide animation for content
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideUp = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start content animation immediately
    _controller.forward();

    // Navigate after 3 seconds with fade transition
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => widget.nextScreen,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
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

    return Scaffold(
      body: Stack(
        children: [
          // ── Beautiful gradient background ─────────────
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0533), // deep purple-black
                  Color(0xFF2D1065), // rich purple
                  Color(0xFF4A1080), // vibrant purple
                  Color(0xFF1A0533), // deep again
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          // ── Decorative soft glow circles ──────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── Content: Quote + App Name ─────────────────
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),

                          // 💬 Quote section
                          // Decorative opening quote mark
                          Text(
                            "\u201C",
                            style: TextStyle(
                              fontSize: 80,
                              height: 0.8,
                              color: Colors.white.withOpacity(0.15),
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Quote text
                          Text(
                            _todayQuote,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1.55,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Subtle divider line
                          Container(
                            width: 40,
                            height: 2,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // 🏷 App name section at the bottom
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // App name
                              const Text(
                                "Planly",
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Tagline
                              Text(
                                "Plan smart. Live better.",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.55),
                                  letterSpacing: 0.5,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Loading indicator — subtle dots
                              _DotsLoader(),

                              const SizedBox(height: 32),
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
            // Each dot pulses at a different phase
            final phase = (i / 3);
            final val = ((_ctrl.value - phase) % 1.0).abs();
            final opacity = (1.0 - val * 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}