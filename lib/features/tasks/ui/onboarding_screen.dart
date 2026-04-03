import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const _titles = <String>[
    'Welcome to Planly!',
    'Stay Motivated',
    'Customize Your Experience',
  ];

  static const _descriptions = <String>[
    'Organize your tasks, set reminders, and boost your productivity.',
    'Get daily quotes and celebrate your achievements with confetti!',
    'Choose your favorite theme and accent color in settings.',
  ];

  static const _icons = <IconData>[
    Icons.check_circle_outline,
    Icons.emoji_events_outlined,
    Icons.color_lens_outlined,
  ];

  bool get _isLastPage => _currentPage == _titles.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_isLastPage) {
      widget.onFinish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _skipToLast() {
    _pageController.animateToPage(
      _titles.length - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required String title,
    required String description,
    required IconData image,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 140),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(image, size: 120, color: primaryColor, semanticLabel: title),
            ),
            const SizedBox(height: 32),
            Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(description, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimary =
        primaryColor.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _titles.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return _buildPage(
                context,
                title: _titles[index],
                description: _descriptions[index],
                image: _icons[index],
              );
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_titles.length, (index) {
                    final active = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? primaryColor
                            : primaryColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (!_isLastPage)
                      TextButton(
                        onPressed: _skipToLast,
                        child: const Text('Skip'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: onPrimary,
                      ),
                      onPressed: _goNext,
                      child: Text(_isLastPage ? 'Get Started' : 'Next'),
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
}
