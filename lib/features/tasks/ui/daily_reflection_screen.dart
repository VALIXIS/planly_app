import 'package:flutter/material.dart';

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

  String _label() {
    if (pct >= 1.0) return "Excellent Day";
    if (pct >= 0.7) return "Great Progress";
    if (pct >= 0.4) return "Good Effort";
    return "Keep Going";
  }

  String _message() {
    if (pct >= 1.0) {
      return "You completed everything today. That is discipline.";
    } else if (pct >= 0.7) {
      return "Strong progress today. You showed consistency.";
    } else if (pct >= 0.4) {
      return "You made progress. That still counts.";
    } else if (completed == 0) {
      return "You didn't complete any tasks today. Tomorrow is a fresh start.";
    } else {
      return "Not your best day. Reset and come back stronger.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final percent = (pct * 100).round();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primary.withOpacity(0.85),
              primary.withOpacity(0.55),
              Colors.black,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                Text(
                  _label(),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "$completed of $total tasks completed · $percent%",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _message(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),

                const Spacer(),

                if (pct < 1.0) ...[
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Continue Tasks"),
                  ),
                  const SizedBox(height: 10),
                ],

                OutlinedButton(
                  onPressed: onClose ?? () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Close Day",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}