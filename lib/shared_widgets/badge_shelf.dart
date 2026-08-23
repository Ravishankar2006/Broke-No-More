import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/badge_icons.dart';
import '../models/badge.dart' as model;

/// Horizontal shelf of every badge in the catalog — unlocked ones lit up,
/// locked ones dimmed. Lives on the Quests screen per the PRD (section 4:
/// "streak calendar; badge shelf").
///
/// Tapping a medallion opens a detail sheet. The previous version used a
/// [Tooltip], which on mobile requires a long-press most users never discover,
/// so badge names and unlock criteria were effectively invisible.
class BadgeShelf extends StatelessWidget {
  const BadgeShelf({super.key, required this.unlockedBadges});

  final List<model.Badge> unlockedBadges;

  @override
  Widget build(BuildContext context) {
    final unlockedById = {for (final b in unlockedBadges) b.id: b};

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Spacing.xxs),
        itemCount: kBadgeCatalog.length,
        separatorBuilder: (_, _) => SizedBox(width: Spacing.md),
        itemBuilder: (context, index) {
          final def = kBadgeCatalog[index];
          final unlocked = unlockedById[def.id];
          return _BadgeMedallion(
            definition: def,
            unlockedAt: unlocked?.unlockedAt,
            delay: AppMotion.staggerDelay(index),
            onTap: () => showBadgeDetailSheet(
              context,
              definition: def,
              unlockedAt: unlocked?.unlockedAt,
            ),
          );
        },
      ),
    );
  }
}

class _BadgeMedallion extends StatelessWidget {
  const _BadgeMedallion({
    required this.definition,
    required this.unlockedAt,
    required this.delay,
    required this.onTap,
  });

  final BadgeDefinition definition;
  final DateTime? unlockedAt;
  final Duration delay;
  final VoidCallback onTap;

  bool get _unlocked => unlockedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    _unlocked ? AppGradients.xp(theme.brightness) : null,
                color: _unlocked ? null : cs.surfaceContainerHigh,
                boxShadow:
                    _unlocked ? AppShadows.gold(theme.brightness) : null,
              ),
              child: Center(
                child: Icon(
                  _unlocked ? badgeIcon(definition.iconId) : Icons.lock_outline,
                  color: _unlocked ? semantics.onGold : semantics.lockedIcon,
                  size: 28,
                ),
              ),
            ),
            SizedBox(height: Spacing.sm),
            Text(
              definition.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _unlocked ? cs.onSurface : semantics.lockedLabel,
                fontWeight: _unlocked ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail sheet for a single badge — name, what it takes, and when it was
/// earned. Replaces the undiscoverable tooltip.
Future<void> showBadgeDetailSheet(
  BuildContext context, {
  required BadgeDefinition definition,
  DateTime? unlockedAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final semantics = context.semantics;
      final cs = theme.colorScheme;
      final unlocked = unlockedAt != null;

      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
            Spacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked ? AppGradients.xp(theme.brightness) : null,
                  color: unlocked ? null : cs.surfaceContainerHigh,
                  boxShadow:
                      unlocked ? AppShadows.gold(theme.brightness) : null,
                ),
                child: Icon(
                  unlocked ? badgeIcon(definition.iconId) : Icons.lock_outline,
                  size: 44,
                  color: unlocked ? semantics.onGold : semantics.lockedIcon,
                ),
              ),
              SizedBox(height: Spacing.lg),
              Text(definition.name, style: theme.textTheme.headlineSmall),
              SizedBox(height: Spacing.sm),
              Text(
                definition.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: Spacing.lg),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: unlocked
                      ? semantics.goldSurface
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  unlocked
                      ? 'Earned ${_formatDate(unlockedAt)}'
                      : 'Not earned yet',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        unlocked ? semantics.goldInk : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
