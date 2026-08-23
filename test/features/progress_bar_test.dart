import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/shared_widgets/animated_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The track has to span the full available width whatever the progress is.
///
/// It didn't: callers place the bar in a Column with CrossAxisAlignment.start,
/// which passes a loose width constraint, and a Container with no explicit
/// width sizes to its child — so the "track" was exactly as wide as the fill.
/// At 10% progress that renders as a lone pill floating on the card with no
/// indication of how far there is to go, and nothing about it throws.
void main() {
  Future<void> pumpBar(WidgetTester tester, double value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              // Reproduces the real caller: a start-aligned Column, which is
              // what makes the width constraint loose.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [AnimatedProgressBar(value: value)],
              ),
            ),
          ),
        ),
      ),
    );
    // Past the fill tween, so the measured width is the settled one.
    await tester.pump(const Duration(milliseconds: 900));
  }

  for (final value in [0.0, 0.1, 0.5, 1.0]) {
    testWidgets('track spans the full width at value $value', (tester) async {
      await pumpBar(tester, value);

      expect(
        tester.getSize(find.byType(AnimatedProgressBar)).width,
        300,
        reason: 'the bar itself must fill its parent',
      );
    });
  }

  testWidgets('fill scales with value, independently of the track',
      (tester) async {
    // FractionallySizedBox sizes *itself* to the incoming constraints and only
    // its child to the factor, so the fill is measured on the child.
    final fill = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );

    await pumpBar(tester, 0.25);
    final quarter = tester.getSize(fill.first).width;

    await pumpBar(tester, 1.0);
    final full = tester.getSize(fill.first).width;

    expect(full, 300, reason: 'a complete bar fills the track');
    expect(quarter, closeTo(75, 1), reason: 'a quarter bar fills a quarter');
  });
}
