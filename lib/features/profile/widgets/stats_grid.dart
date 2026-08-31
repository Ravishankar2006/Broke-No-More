import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/badge_engine.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/user_profile.dart';
import '../../../shared_widgets/app_card.dart';
import '../../../shared_widgets/stat_tile.dart';

/// The numbers a gamified app should be proud of, none of which the screen
/// showed before.
class StatsGrid extends StatelessWidget {
  const StatsGrid({
    super.key,
    required this.profile,
    required this.transactionCount,
    required this.activeDays,
    required this.totalSpent,
    required this.badgeCount,
  });

  final UserProfile profile;
  final int transactionCount;
  final int activeDays;
  final double totalSpent;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  value: '$transactionCount',
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Active days',
                  value: '$activeDays',
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Longest streak',
                  value: '${profile.longestStreak}',
                  // Freezes were computed and persisted from day one but
                  // never shown anywhere in the app until now.
                  caption:
                      'Now: ${profile.currentStreak} · '
                      '❄ ${profile.streakFreezesLeft} left',
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Badges',
                  value: '$badgeCount of ${kBadgeCatalog.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Total spent',
                  value: formatCurrency(
                    totalSpent,
                    currencyCode: profile.currencyCode,
                  ),
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.bolt_outlined,
                  label: 'Total XP',
                  value: '${profile.currentXP}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
