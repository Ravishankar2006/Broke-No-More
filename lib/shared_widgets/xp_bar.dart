import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/xp_engine.dart';

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress});

  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Level ${progress.level}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress.fraction.clamp(0, 1),
            minHeight: 10,
            backgroundColor: semantics.xpTrack,
            valueColor: AlwaysStoppedAnimation<Color>(semantics.xp),
          ),
        ),
      ],
    );
  }
}
