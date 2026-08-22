import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/badge_icons.dart';
import '../models/badge.dart' as model;

/// Horizontal shelf of every badge in the catalog — unlocked ones lit up,
/// locked ones dimmed with a lock overlay. Lives on the Quests screen per
/// the PRD (section 4: "streak calendar; badge shelf").
class BadgeShelf extends StatelessWidget {
  const BadgeShelf({super.key, required this.unlockedBadges});

  final List<model.Badge> unlockedBadges;

  @override
  Widget build(BuildContext context) {
    final unlockedIds = unlockedBadges.map((b) => b.id).toSet();
    final semantics = context.semantics;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kBadgeCatalog.length,
        separatorBuilder: (_, _) => SizedBox(width: Spacing.md),
        itemBuilder: (context, index) {
          final def = kBadgeCatalog[index];
          final unlocked = unlockedIds.contains(def.id);
          return Tooltip(
            message: unlocked ? '${def.name}\n${def.description}' : 'Locked · ${def.description}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? semantics.xp.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHigh,
                    border: unlocked
                        ? Border.all(color: semantics.xp.withValues(alpha: 0.4), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      unlocked ? badgeIcon(def.iconId) : Icons.lock_outline,
                      color: unlocked
                          ? semantics.goldInk
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                      size: 28,
                    ),
                  ),
                ),
                SizedBox(height: Spacing.sm),
                SizedBox(
                  width: 64,
                  child: Text(
                    def.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: unlocked ? null : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
