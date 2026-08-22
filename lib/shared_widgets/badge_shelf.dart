import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kBadgeCatalog.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final def = kBadgeCatalog[index];
          final unlocked = unlockedIds.contains(def.id);
          return Tooltip(
            message: unlocked ? '${def.name}\n${def.description}' : 'Locked · ${def.description}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: unlocked
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  child: Icon(
                    unlocked ? badgeIcon(def.iconId) : Icons.lock_outline,
                    color: unlocked
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
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
