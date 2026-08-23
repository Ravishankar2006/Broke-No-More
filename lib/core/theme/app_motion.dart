import 'package:flutter/material.dart';

/// Motion tokens — durations and curves.
///
/// Before this existed, every animation in the app picked its own numbers
/// (150ms nav pill, 550ms bounce, 700ms confetti), so nothing felt like it
/// belonged to the same product. Reach for these instead of literals.
///
/// The scale is deliberately short at the top end: this is a gamified app, so
/// feedback should feel immediate and springy, never stately.
abstract class AppMotion {
  /// State flips that must not feel laggy — chip selection, checkbox, ripple.
  static const Duration instant = Duration(milliseconds: 100);

  /// Small local changes — nav pill, icon swaps, press states.
  static const Duration quick = Duration(milliseconds: 180);

  /// The default. Progress bars, card entrances, cross-fades.
  static const Duration standard = Duration(milliseconds: 260);

  /// Larger moves — sheet content, page transitions, list reflow.
  static const Duration slow = Duration(milliseconds: 420);

  /// Reward moments only: level-up, badge unlock, quest completion.
  static const Duration celebrate = Duration(milliseconds: 900);

  /// Counters rolling up to a new value (XP totals, currency amounts).
  static const Duration countUp = Duration(milliseconds: 650);

  /// General-purpose easing — decelerates into place. Use when in doubt.
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Slight overshoot. For things arriving that should feel eager: a card
  /// landing, a chip being selected, the FAB responding to a press.
  static const Curve emphasized = Curves.easeOutBack;

  /// Full spring. Reserved for celebration — overuse makes the app feel jittery.
  static const Curve spring = Curves.elasticOut;

  /// Entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving the screen — faster out than in, so dismissal feels responsive.
  static const Curve exit = Curves.easeInCubic;

  /// Per-item delay for staggered list/grid entrances.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Delay for the item at [index], capped so long lists don't leave the last
  /// items visibly waiting. Anything past [maxItems] enters with the same delay.
  static Duration staggerDelay(int index, {int maxItems = 8}) {
    final clamped = index < 0 ? 0 : (index > maxItems ? maxItems : index);
    return stagger * clamped;
  }
}
