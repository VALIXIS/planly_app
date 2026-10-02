import 'package:flutter/material.dart';
import 'reliable_banner_ad.dart';

/// A native banner ad card styled as a motivational quote.
/// Designed for placement on completed tasks celebration screens.
class MotivationalQuoteAdCard extends StatelessWidget {
  const MotivationalQuoteAdCard({
    super.key,
    this.quote,
    this.author,
  });

  final String? quote;
  final String? author;

  static const List<Map<String, String>> _defaultQuotes = [
    {
      'quote': 'Small daily improvements over time lead to stunning results.',
      'author': 'Robin Sharma',
    },
    {
      'quote': 'Success is the sum of small efforts repeated day in and day out.',
      'author': 'Robert Collier',
    },
    {
      'quote': 'The secret of getting ahead is getting started.',
      'author': 'Mark Twain',
    },
    {
      'quote': 'You don’t have to see the whole staircase, just take the first step.',
      'author': 'Martin Luther King Jr.',
    },
    {
      'quote': 'Well done is better than well said.',
      'author': 'Benjamin Franklin',
    },
  ];

  Map<String, String> get _selectedQuote {
    if (quote != null && quote!.isNotEmpty) {
      return {'quote': quote!, 'author': author ?? 'Inspiration'};
    }
    final dayIndex = DateTime.now().day % _defaultQuotes.length;
    return _defaultQuotes[dayIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final selected = _selectedQuote;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2638),
                  const Color(0xFF141923),
                ]
              : [
                  primary.withValues(alpha: 0.08),
                  primary.withValues(alpha: 0.03),
                ],
        ),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Top Header (Quote Icon + Sponsored Badge)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.format_quote_rounded,
                          size: 18,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DAILY MOTIVATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ad',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Motivational Quote Content
              Text(
                '“${selected['quote']}”',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '— ${selected['author']}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 0.8),
              const SizedBox(height: 12),
              // Banner Ad integration
              const ReliableBannerAd(),
            ],
          ),
        ),
      ),
    );
  }
}
