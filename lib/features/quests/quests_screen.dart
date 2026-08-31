import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_catalog.dart';
import '../../core/utils/quest_template_engine.dart' show QuestCandidate;
import '../../models/quest.dart';
import '../../providers/badge_provider.dart';
import '../../providers/profile_provider.dart'
    show currentCurrencyCodeProvider, profileProvider;
import '../../providers/quest_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/badge_shelf.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/quest_card.dart';
import '../../shared_widgets/section_header.dart';
import 'quest_history_screen.dart';
import 'widgets/quest_customize_dialog.dart';

/// Older finished quests than this stay reachable only through "See all" —
/// the Finished section on this screen is meant to be a glance, not an
/// archive.
const int _kFinishedPreviewCount = 5;

/// Quests, badges and progress.
///
/// Previously three unrelated blocks stacked with no framing — including a
/// duplicate of Home's streak calendar, rendered here as an unlabelled row of
/// dots. The calendar now lives only on Home, where it's the hero, and this
/// screen gets a quest-focused header of its own.
class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  @override
  void initState() {
    super.initState();
    // Also check on screen open, not just app startup, so a quest that
    // expires mid-session doesn't linger as "active" until next launch.
    // Routed through the orchestrator (not the repository directly) since
    // an expiring budgetLimit quest can grant XP right here — see
    // XpEngineOrchestrator.expireOverdueQuests.
    Future.microtask(() async {
      await ref.read(xpEngineOrchestratorProvider).expireOverdueQuests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allQuests = ref.watch(questsProvider);
    final activeQuests = ref.watch(activeQuestsProvider);
    final candidates = ref.watch(visibleQuestCandidatesProvider);
    final unlockedBadges = ref.watch(badgesProvider);
    final currencySymbol = currencyInfoFor(
      ref.watch(currentCurrencyCodeProvider),
    ).symbol;
    final profile = ref.watch(profileProvider);
    final transactionCount = ref.watch(transactionsProvider).length;

    final finished =
        allQuests.where((q) => q.status != QuestStatus.active).toList()
          ..sort((a, b) => b.endDate.compareTo(a.endDate));
    final completedCount = allQuests
        .where((q) => q.status == QuestStatus.completed)
        .length;
    final badgeStats = (
      transactionCount: transactionCount,
      currentStreak: profile?.currentStreak ?? 0,
      level: profile?.level ?? 1,
      questsCompleted: completedCount,
      daysUnderBudget: profile?.daysUnderBudgetCount ?? 0,
    );

    final nothingToShow =
        activeQuests.isEmpty && candidates.isEmpty && finished.isEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Quests'),
            titleSpacing: Spacing.lg,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                _QuestHero(
                  active: activeQuests.length,
                  completed: completedCount,
                  badges: unlockedBadges.length,
                ),
                const SizedBox(height: Spacing.xl),

                SectionHeader(title: 'Badges', count: unlockedBadges.length),
                BadgeShelf(unlockedBadges: unlockedBadges, stats: badgeStats),
                const SizedBox(height: Spacing.xl),

                if (activeQuests.isNotEmpty) ...[
                  SectionHeader(title: 'Active', count: activeQuests.length),
                  for (final quest in activeQuests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: QuestCard(quest: quest),
                    ),
                  const SizedBox(height: Spacing.lg),
                ],

                if (candidates.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Suggested for you',
                    count: candidates.length,
                  ),
                  for (final candidate in candidates)
                    Padding(
                          key: ValueKey(candidate.title),
                          padding: const EdgeInsets.only(bottom: Spacing.md),
                          child: Dismissible(
                            key: ValueKey('dismiss-${candidate.title}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _skip(candidate.title),
                            background: const _SkipBackground(),
                            child: QuestCandidateCard(
                              candidate: candidate,
                              onAccept: () => _accept(candidate),
                              onSkip: () => _skip(candidate.title),
                              onCustomize: () =>
                                  _customize(candidate, currencySymbol),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: AppMotion.standard)
                        .slideX(begin: 0.04, end: 0, curve: AppMotion.enter),
                  const SizedBox(height: Spacing.lg),
                ],

                if (finished.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Finished',
                    count: finished.length,
                    actionLabel: finished.length > _kFinishedPreviewCount
                        ? 'See all'
                        : null,
                    onAction: finished.length > _kFinishedPreviewCount
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  QuestHistoryScreen(quests: finished),
                            ),
                          )
                        : null,
                  ),
                  for (final quest in finished.take(_kFinishedPreviewCount))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: QuestCard(quest: quest),
                    ),
                ],

                if (nothingToShow)
                  const EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No quests yet',
                    message:
                        'Keep logging transactions — suggestions appear once '
                        "there's enough history to spot a pattern worth "
                        'challenging.',
                  )
                else if (activeQuests.isEmpty && candidates.isEmpty)
                  // Distinct from the both-empty case: the user has finished
                  // quests but nothing is on offer right now, which previously
                  // just rendered as a section silently vanishing.
                  const Padding(
                    padding: EdgeInsets.only(top: Spacing.lg),
                    child: EmptyState(
                      compact: true,
                      icon: Icons.hourglass_empty_rounded,
                      title: 'Nothing on offer right now',
                      message:
                          'New suggestions show up as your spending patterns '
                          'change. Check back tomorrow.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _customize(
    QuestCandidate candidate,
    String currencySymbol,
  ) async {
    final result = await showDialog<CustomizedQuest>(
      context: context,
      builder: (_) => QuestCustomizeDialog(
        candidate: candidate,
        currencySymbol: currencySymbol,
      ),
    );
    if (result == null) return;
    await _accept(result.candidate, durationDays: result.durationDays);
  }

  Future<void> _accept(QuestCandidate candidate, {int? durationDays}) async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref
          .read(xpEngineOrchestratorProvider)
          .acceptQuest(candidate, durationDays: durationDays);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't accept — please try again.")),
      );
    }
  }

  void _skip(String title) {
    HapticFeedback.selectionClick();
    ref.read(skippedQuestsProvider.notifier).skip(title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Suggestion skipped'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              ref.read(skippedQuestsProvider.notifier).unskip(title),
        ),
      ),
    );
  }
}

/// Quest-focused header, replacing the duplicated streak calendar.
class _QuestHero extends StatelessWidget {
  const _QuestHero({
    required this.active,
    required this.completed,
    required this.badges,
  });

  final int active;
  final int completed;
  final int badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppCard.hero(
      gradient: AppGradients.brand(theme.brightness),
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              label: 'Active',
              value: active,
              color: cs.onPrimary,
            ),
          ),
          _Divider(color: cs.onPrimary),
          Expanded(
            child: _HeroStat(
              label: 'Completed',
              value: completed,
              color: cs.onPrimary,
            ),
          ),
          _Divider(color: cs.onPrimary),
          Expanded(
            child: _HeroStat(
              label: 'Badges',
              value: badges,
              color: cs.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.75),
            letterSpacing: kOverlineLetterSpacing,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color.withValues(alpha: 0.2));
  }
}

class _SkipBackground extends StatelessWidget {
  const _SkipBackground();

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Spacing.xl),
      decoration: BoxDecoration(
        color: semantics.barTrack,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: IconSize.md,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
          Text('Skip', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
