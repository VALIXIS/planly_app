import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:planly/core/theme/fluid_bottom_sheet.dart';
import 'package:planly/core/theme/oled_theme.dart';
import 'package:planly/services/app_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OledTheme specifications', () {
    test('themeData has true pitch-black background and charcoal surfaces', () {
      final theme = OledTheme.buildTheme();

      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF000000)));
      expect(theme.canvasColor, equals(const Color(0xFF000000)));
      expect(theme.cardColor, equals(const Color(0xFF121212)));
      expect(theme.cardTheme.color, equals(const Color(0xFF121212)));
      expect(theme.colorScheme.brightness, equals(Brightness.dark));
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('themeData features vibrant neon cyan/mint accents by default', () {
      final theme = OledTheme.buildTheme();

      expect(theme.colorScheme.primary, equals(OledTheme.neonMint));
      expect(theme.colorScheme.secondary, equals(OledTheme.neonCyan));
      expect(theme.floatingActionButtonTheme.backgroundColor, equals(OledTheme.neonMint));
    });

    test('themeData custom accent color support', () {
      const customAccent = Color(0xFF00E5FF);
      final theme = OledTheme.buildTheme(accentColor: customAccent);

      expect(theme.colorScheme.primary, equals(customAccent));
    });

    test('OLED constants verification', () {
      expect(OledTheme.pureBlack, equals(const Color(0xFF000000)));
      expect(OledTheme.charcoalCard, equals(const Color(0xFF121212)));
      expect(OledTheme.neonMint, equals(const Color(0xFF00F5D4)));
      expect(OledTheme.neonCyan, equals(const Color(0xFF00E5FF)));
      expect(OledTheme.sheetSpringCurve, equals(Curves.easeOutBack));
    });
  });

  group('AppStateService OLED mode toggle', () {
    setUp(() async {
      final tempDir = const String.fromEnvironment('TEMP', defaultValue: '.');
      Hive.init(tempDir);
      if (!Hive.isBoxOpen('settings')) {
        await Hive.openBox('settings');
      }
    });

    tearDown(() async {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').deleteFromDisk();
      }
    });

    test('toggleOledMode toggles isOledMode and activates dark mode', () async {
      await AppStateService.setThemeMode(ThemeMode.light);
      await AppStateService.setOledMode(false);

      expect(AppStateService.isOledMode, isFalse);

      await AppStateService.toggleOledMode();
      expect(AppStateService.isOledMode, isTrue);
      expect(AppStateService.themeNotifier.value, equals(ThemeMode.dark));

      await AppStateService.toggleOledMode();
      expect(AppStateService.isOledMode, isFalse);
    });
  });

  group('FluidModalBottomSheet micro-interactions', () {
    testWidgets('shows modal sheet with easeOutBack spring animation curve', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OledTheme.buildTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showFluidModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => const SizedBox(
                      height: 200,
                      child: Text('Fluid Sheet Content'),
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      // Pump frame to begin animation
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Fluid Sheet Content'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Fluid Sheet Content'), findsOneWidget);
    });
  });
}
