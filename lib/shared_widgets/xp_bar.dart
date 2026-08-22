import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/xp_engine.dart';

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.progress});

  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.fraction.clamp(0, 1),
            minHeight: 10,
            backgroundColor: AppColors.xp.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.xp),
          ),
        ),
      ],
    );
  }
}
