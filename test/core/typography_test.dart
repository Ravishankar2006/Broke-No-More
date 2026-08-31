import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the failure that prompted the UI revamp.
///
/// The app declared Plus Jakarta Sans through google_fonts with runtime
/// fetching disabled and an empty asset directory, so every TextStyle silently
/// fell back to Roboto and the entire hand-tuned type scale was invisible in
/// the running app. Nothing failed — it just looked wrong.
///
/// These assert the two halves that have to hold: the family is actually
/// bundled, and the theme actually applies it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weights = [
    ('Regular', 400),
    ('Medium', 500),
    ('SemiBold', 600),
    ('Bold', 700),
    ('ExtraBold', 800),
  ];

  for (final (name, weight) in weights) {
    test('$name ($weight) is bundled as a real font file', () async {
      final data = await rootBundle.load(
        'assets/fonts/PlusJakartaSans-$name.ttf',
      );
      expect(
        data.lengthInBytes,
        greaterThan(10000),
        reason: 'a truncated or placeholder file would load but not render',
      );

      // TrueType files start with the version tag 0x00010000.
      final header = data.buffer.asUint8List(0, 4);
      expect(header, [0x00, 0x01, 0x00, 0x00], reason: 'not a TrueType file');
    });
  }

  test('every themed text style uses the bundled family', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final styles = <String, TextStyle?>{
        'headlineMedium': theme.textTheme.headlineMedium,
        'headlineSmall': theme.textTheme.headlineSmall,
        'titleLarge': theme.textTheme.titleLarge,
        'titleMedium': theme.textTheme.titleMedium,
        'titleSmall': theme.textTheme.titleSmall,
        'bodyLarge': theme.textTheme.bodyLarge,
        'bodyMedium': theme.textTheme.bodyMedium,
        'bodySmall': theme.textTheme.bodySmall,
        'labelLarge': theme.textTheme.labelLarge,
        'labelMedium': theme.textTheme.labelMedium,
        'labelSmall': theme.textTheme.labelSmall,
      };

      styles.forEach((role, style) {
        expect(
          style?.fontFamily,
          kFontFamily,
          reason: '$role fell back to the platform default',
        );
      });
    }
  });

  testWidgets('rendered text resolves to the bundled family', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('Broke No More')),
      ),
    );

    final text = tester.widget<Text>(find.text('Broke No More'));
    final resolved = DefaultTextStyle.of(
      tester.element(find.text('Broke No More')),
    ).style.merge(text.style);

    expect(resolved.fontFamily, kFontFamily);
  });
}
