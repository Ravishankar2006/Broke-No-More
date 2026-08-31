import 'package:flutter/material.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../models/user_profile.dart';
import '../../../shared_widgets/app_card.dart';
import '../../../shared_widgets/stat_tile.dart';

/// Insights was entirely disconnected from XP/streaks/quests — a screen
/// all about the user's spending never once acknowledged the game layer
/// wrapped around it. This is the tie-back: the same streak and level
/// shown on Home and Profile, so spending data and the reward system read
/// as one app rather than two.
class GamificationStrip extends StatelessWidget {
  const GamificationStrip({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.local_fire_department_outlined,
              label: 'Streak',
              value: '${profile.currentStreak}',
              valueColor: semantics.streak,
              caption: profile.currentStreak == 1 ? 'day' : 'days',
            ),
          ),
          Expanded(
            child: StatTile(
              icon: Icons.military_tech_outlined,
              label: 'Level',
              value: '${profile.level}',
            ),
          ),
          Expanded(
            child: StatTile(
              icon: Icons.bolt_outlined,
              label: 'Total XP',
              value: '${profile.currentXP}',
              valueColor: semantics.goldInk,
            ),
          ),
        ],
      ),
    );
  }
}
