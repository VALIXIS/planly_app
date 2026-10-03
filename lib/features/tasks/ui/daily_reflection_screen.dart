import 'package:flutter/material.dart';
import '../../common/widgets/motivational_quote_ad_card.dart';

/// 🌙 Daily Reflection Screen
/// Full-screen experience shown once per day.
/// Shows completion stats + a rich message based on performance.
class DailyReflectionScreen extends StatelessWidget {
  final double pct;
  final int completed;
  final int total;
  final VoidCallback? onContinue;
  final VoidCallback? onClose;

  const DailyReflectionScreen({
    super.key,
    required this.pct,
    required this.completed,
    required this.total,
    this.onContinue,
    this.onClose,
  });

  // ── Performance label ──────────────────────────
  String _label() {
    if (pct >= 1.0) return "Excellent Day";
    if (pct >= 0.7) return "Great Progress";
    if (pct >= 0.4) return "Good Effort";
    return "Keep Going";
  }

  // ── Rich, attractive message per state ─────────
  String _message() {
    if (pct >= 1.0) {
      return "Every single task — done. That's not motivation, that's discipline. Most people plan. You executed. Sleep well tonight knowing you earned it.";
    } else if (pct >= 0.7) {
      return "You tackled the hard stuff and kept moving when it would've been easy to stop. That's what separates the consistent from the occasional. Tomorrow starts with momentum.";
    } else if (pct >= 0.4) {
      return "Progress isn't always a straight line — and that's okay. You showed up, you moved the needle, and that still counts. Build on it tomorrow.";
    } else if (completed == 0) {
      return "Today didn't go as planned — and that happens. The only thing that matters now is what you do next. Tomorrow is a clean slate. Use it.";
    } else {
      return "Not your best day, but you're still here, still tracking, still trying. That intention is worth something. Reset tonight and come back stronger.";
    }
  }

  // ── Subtitle per state ─────────────────────────
  String _subtitle() {
    if (pct >= 1.0) return "Perfect completion";
    if (pct >= 0.7) return "Strong performance";
    if (pct >= 0.4) return "Steady progress";
    return "Tomorrow is a fresh start";
  }

  // ── Color per state ────────────────────────────
  Color _stateColor() {
    if (pct >= 1.0) return const Color(0xFF4CAF50);
    if (pct >= 0.7) return const Color(0xFF26A69A);
    if (pct >= 0.4) return const Color(0xFF42A5F5);
    return const Color(0xFFFF7043);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final percent = (pct * 100).round();
    final stateColor = _stateColor();

    int scaledChannel(double channel, double factor) =>
        (channel * 255.0 * factor).round().clamp(0, 255);

    // Build gradient using accent color — deep to lighter
    final darkEnd = Color.fromARGB(
      255,
      scaledChannel(primary.r, 0.12),
      scaledChannel(primary.g, 0.08),
      scaledChannel(primary.b, 0.12),
    );
    final midPoint = Color.fromARGB(
      255,
      scaledChannel(primary.r, 0.30),
      scaledChannel(primary.g, 0.22),
      scaledChannel(primary.b, 0.35),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkEnd, midPoint, primary.withValues(alpha: 0.8)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top label ───────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Daily Reflection",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Performance label ────────────────
                  Text(
                    _label(),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _subtitle(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Progress stats ───────────────────
                  Row(
                    children: [
                      // Completed count
                      _StatChip(
                        value: "$completed",
                        label: "Completed",
                        color: stateColor,
                      ),
                      const SizedBox(width: 12),
                      // Total count
                      _StatChip(
                        value: "$total",
                        label: "Total",
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 12),
                      // Percentage
                      _StatChip(
                        value: "$percent%",
                        label: "Done",
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Animated progress bar ────────────
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: pct),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, _) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              color: stateColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Message ──────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 80,
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _message(),
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.65,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── High-eCPM Native Banner Ad Card ──
                  const MotivationalQuoteAdCard(),

                  const SizedBox(height: 20),

                  // ── Action buttons ───────────────────
                  if (pct < 1.0) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Continue Tasks",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onClose ?? () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        pct >= 1.0 ? "That's a wrap!" : "Close Day",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Compact stat chip
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color == Colors.white.withValues(alpha: 0.3)
                  ? Colors.white70
                  : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
