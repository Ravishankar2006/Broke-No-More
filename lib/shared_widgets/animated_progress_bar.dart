import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';

/// What a bar represents. Drives colour, height and whether it gets a glow, so
/// three different meanings stop looking identical.
enum ProgressVariant {
  /// Level progress. The app's core reward — gets the gradient and the glow.
  xp,

  /// Daily budget. Flips to the "over" colour once exceeded.
  budget,

  /// Quest progress. Deliberately quieter than [xp]; a quest is a side goal.
  quest,
}

/// The app's single progress bar.
///
/// There used to be three: the XP bar at 10px, the budget bar at 8px, and an
/// unstyled one inside quest cards — same shape, same gold, three unrelated
/// meanings, and none of them animated. A gamified app where the XP bar snaps
/// to its new value throws away its best feedback moment, so this tweens.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.variant = ProgressVariant.xp,
    this.isOver = false,
  });

  /// Progress in 0..1. Values outside are clamped.
  final double value;

  final ProgressVariant variant;

  /// [ProgressVariant.budget] only: render in the "over budget" colour.
  final bool isOver;

  double get _height => switch (variant) {
        ProgressVariant.xp => 14,
        ProgressVariant.budget => 10,
        ProgressVariant.quest => 8,
      };

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final brightness = Theme.of(context).brightness;
    final clamped = value.clamp(0.0, 1.0);

    // One neutral track for every variant. A gold-tinted track for the XP bar
    // reads as almost nothing against a white card, which made the bar look
    // like a floating pill with no indication of the distance left to cover.
    // The fill colour is what distinguishes the variants.
    final track = semantics.barTrack;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: AppMotion.countUp,
      curve: AppMotion.standardCurve,
      builder: (context, animated, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            // Explicitly full width. Callers place this inside a Column with
            // CrossAxisAlignment.start, which passes a *loose* width; a
            // Container then sizes to its child, so the track ended up exactly
            // as wide as the fill and was invisible as a track at all.
            width: double.infinity,
            height: _height,
            color: track,
            // FractionallySizedBox directly, with heightFactor: 1.
            //
            // Wrapping it in an Align first loosens the height constraint, and
            // a childless DecoratedBox then collapses to zero height — so the
            // fill was invisible on every bar in the app while the track still
            // rendered, which looked like "progress is always empty".
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              // A zero-width fill would clip the pill radius into nothing and
              // flicker; keep a sliver visible once there's any progress.
              widthFactor: animated <= 0 ? 0 : animated.clamp(0.02, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: switch (variant) {
                    ProgressVariant.xp => AppGradients.xp(brightness),
                    ProgressVariant.budget => null,
                    ProgressVariant.quest => null,
                  },
                  color: switch (variant) {
                    ProgressVariant.xp => null,
                    ProgressVariant.budget =>
                      isOver ? semantics.budgetOver : semantics.budgetUnder,
                    ProgressVariant.quest => semantics.xp,
                  },
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
