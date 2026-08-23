import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/xp_engine.dart';
import 'animated_progress_bar.dart';
import 'celebration_effects.dart';

/// Level and XP progress — the app's core reward readout.
///
/// Was a label row above a stock [LinearProgressIndicator] that snapped to its
/// new value, which meant the single most important number in a gamified app
/// changed without the user seeing it move. Now the level sits in a medallion,
/// the bar tweens and glows, and the XP count rolls up.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress, this.compact = false});

  final LevelProgress progress;

  /// Drops the medallion and the "to next level" line — for tight contexts
  /// like a list row or a dense header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final remaining = progress.xpForNextLevel - progress.xpIntoLevel;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Level ${progress.level}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          AnimatedProgressBar(value: progress.fraction),
        ],
      );
    }

    return Row(
      children: [
        _LevelMedallion(level: progress.level),
        SizedBox(width: Spacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Both halves shrink: at large text scales the level label
                  // and the XP fraction together exceed the card width.
                  Flexible(
                    child: Text(
                      'Level ${progress.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        CountUpText(
                          value: progress.xpIntoLevel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: semantics.goldInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' / ${progress.xpForNextLevel} XP',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: Spacing.sm),
              AnimatedProgressBar(value: progress.fraction),
              SizedBox(height: Spacing.sm),
              Text(
                remaining > 0
                    ? '$remaining XP to level ${progress.level + 1}'
                    : 'Level complete!',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The level number in a gold gradient disc — gives the XP block an anchor so
/// it reads as an achievement rather than a form field.
class _LevelMedallion extends StatelessWidget {
  const _LevelMedallion({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.xp(theme.brightness),
        boxShadow: AppShadows.gold(theme.brightness),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: theme.textTheme.titleLarge?.copyWith(
          color: semantics.onGold,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
