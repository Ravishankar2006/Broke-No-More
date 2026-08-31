import 'package:flutter/material.dart';

import '../core/utils/badge_engine.dart';
import '../models/quest.dart';
import 'badge_unlock_dialog.dart';
import 'celebration_effects.dart';
import 'level_up_dialog.dart';
import 'quest_complete_dialog.dart';

/// Runs the standard XP → quest-complete → level-up → badge-unlock
/// celebration sequence for a mutation's result.
///
/// Shared by the log-transaction flow and CSV import — both react to the
/// same shape of orchestrator result, and duplicating this ordering would
/// let them drift. Checks `context.mounted` between each awaited step, since
/// any dialog can pop the widget tree out from under the caller (a
/// navigation, a hot restart, the sheet's own dismissal).
Future<void> showGamificationCelebrations(
  BuildContext context, {
  required int xpGained,
  required List<Quest> completedQuests,
  required int? leveledUpTo,
  required List<BadgeDefinition> newlyUnlockedBadges,
  required int totalBadgesUnlocked,
  bool freezeConsumed = false,
}) async {
  // The freeze mechanic was entirely silent — a covered gap looked exactly
  // like an unbroken streak, so the user never learned it exists. A snackbar
  // rather than a dialog: this is a "you're covered" reassurance, not a
  // reward worth interrupting for.
  if (freezeConsumed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.ac_unit, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text('Streak freeze used — your streak continues!'),
            ),
          ],
        ),
      ),
    );
  }

  // Every mutation now gets acknowledged. Previously one that didn't happen
  // to trigger a level-up produced no feedback at all.
  if (xpGained > 0) showXpGain(context, xpGained);

  if (completedQuests.isNotEmpty) {
    await showQuestCompleteDialog(context, completedQuests);
  }

  if (!context.mounted) return;
  if (leveledUpTo != null) {
    await showLevelUpDialog(context, leveledUpTo);
  }
  if (!context.mounted || newlyUnlockedBadges.isEmpty) return;
  await showBadgeUnlockDialog(
    context,
    newlyUnlockedBadges,
    totalUnlocked: totalBadgesUnlocked,
  );
}
