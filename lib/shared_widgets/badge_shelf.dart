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
/// The stats [badgeProgressValue] needs to compute a locked badge's "3/7"
/// progress — bundled so the shelf's constructor doesn't grow five loose
/// int params.
typedef BadgeProgressStats = ({
  int transactionCount,
  int currentStreak,
  int level,
  int questsCompleted,
  int daysUnderBudget,
});

class BadgeShelf extends StatelessWidget {
  const BadgeShelf({
    super.key,
    required this.unlockedBadges,
    required this.stats,
  });

  final List<model.Badge> unlockedBadges;

  /// Drives the locked-badge progress ring/label — previously a locked
  /// badge showed only a lock icon with no indication of how close it was.
  final BadgeProgressStats stats;

  @override
  Widget build(BuildContext context) {
    final unlockedById = {for (final b in unlockedBadges) b.id: b};

    return SizedBox(
      height: MedallionSize.badgeShelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
        itemCount: kBadgeCatalog.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
        itemBuilder: (context, index) {
          final def = kBadgeCatalog[index];
          final unlocked = unlockedById[def.id];
          final progressValue = badgeProgressValue(
            def.criteriaType,
            transactionCount: stats.transactionCount,
            currentStreak: stats.currentStreak,
            level: stats.level,
            questsCompleted: stats.questsCompleted,
            daysUnderBudget: stats.daysUnderBudget,
          );
          return _BadgeMedallion(
            definition: def,
            unlockedAt: unlocked?.unlockedAt,
            progressValue: progressValue,
            delay: AppMotion.staggerDelay(index),
            onTap: () => showBadgeDetailSheet(
              context,
              definition: def,
              unlockedAt: unlocked?.unlockedAt,
              progressValue: progressValue,
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
    required this.progressValue,
    required this.delay,
    required this.onTap,
  });

  final BadgeDefinition definition;
  final DateTime? unlockedAt;
  final int progressValue;
  final Duration delay;
  final VoidCallback onTap;

  bool get _unlocked => unlockedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final cs = theme.colorScheme;
    final fraction = definition.threshold == 0
        ? 0.0
        : (progressValue / definition.threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MedallionSize.badgeShelfCell,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: MedallionSize.badgeDetail,
              height: MedallionSize.badgeDetail,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _unlocked ? AppGradients.xp(theme.brightness) : null,
                color: _unlocked ? null : cs.surfaceContainerHigh,
                boxShadow: _unlocked ? AppShadows.gold(theme.brightness) : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_unlocked)
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: CircularProgressIndicator(
                        value: fraction,
                        strokeWidth: 3,
                        backgroundColor: cs.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  _unlocked
                      ? Icon(
                          badgeIcon(definition.iconId),
                          color: semantics.onGold,
                          size: IconSize.xl,
                        )
                      : Text(
                          '$progressValue/${definition.threshold}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: semantics.lockedIcon,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
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
  int progressValue = 0,
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
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
            Spacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: MedallionSize.dialogPrimary,
                height: MedallionSize.dialogPrimary,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked ? AppGradients.xp(theme.brightness) : null,
                  color: unlocked ? null : cs.surfaceContainerHigh,
                  boxShadow: unlocked
                      ? AppShadows.gold(theme.brightness)
                      : null,
                ),
                child: Icon(
                  unlocked ? badgeIcon(definition.iconId) : Icons.lock_outline,
                  size: IconSize.xxxl,
                  color: unlocked ? semantics.onGold : semantics.lockedIcon,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(definition.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: Spacing.sm),
              Text(
                definition.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
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
                      : 'Progress: $progressValue / ${definition.threshold}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: unlocked ? semantics.goldInk : cs.onSurfaceVariant,
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
