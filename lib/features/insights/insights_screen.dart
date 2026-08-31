import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../providers/category_provider.dart';
import '../../providers/profile_provider.dart'
    show currentCurrencyCodeProvider, profileProvider;
import '../../providers/insights_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/section_header.dart';
import '../transactions/transaction_history_screen.dart';
import 'widgets/category_breakdown.dart';
import 'widgets/category_budgets_card.dart';
import 'widgets/category_colors.dart';
import 'widgets/gamification_strip.dart';
import 'widgets/month_outlook_card.dart';
import 'widgets/net_summary_card.dart';
import 'widgets/range_selector.dart';
import 'widgets/summary_hero.dart';
import 'widgets/trend_chart.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsRange _range = InsightsRange.week;

  void _openCategoryHistory(String category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionHistoryScreen(initialQuery: category),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: ref.read(customInsightsRangeProvider),
    );
    if (picked == null || !mounted) return;
    ref.read(customInsightsRangeProvider.notifier).set(picked);
    setState(() => _range = InsightsRange.custom);
  }

  void _onRangeChanged(InsightsRange range) {
    // Custom needs a date range before it means anything, so selecting the
    // segment opens the picker rather than switching immediately — and
    // re-tapping it while already active lets the user change the dates.
    if (range == InsightsRange.custom) {
      _pickCustomRange();
    } else {
      setState(() => _range = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final transactions = ref.watch(transactionsProvider);
    final currencyCode = ref.watch(currentCurrencyCodeProvider);
    final profile = ref.watch(profileProvider);

    final current = ref.watch(currentInsightsWindowProvider(_range));
    final previous = ref.watch(previousInsightsWindowProvider(_range));

    final byCategory = ref.watch(categoryTotalsProvider(_range));
    final categoryColors = assignCategoryColors(
      byCategory.keys,
      semantics.chartPalette,
    );
    final categoriesWithActiveQuest = ref
        .watch(activeQuestsProvider)
        .map((q) => q.category)
        .whereType<String>()
        .toSet();

    // Budgets are a calendar-month concept (matching dailyBudgetFor's own
    // proration), so this deliberately ignores the range selector above —
    // switching to "Week" shouldn't make a category's monthly budget look
    // unspent.
    final budgetedCategories = ref
        .watch(expenseCategoriesProvider)
        .where((c) => c.budget != null)
        .toList();
    final monthToDateByCategory = ref.watch(monthToDateByCategoryProvider);
    final monthToDateSpend = ref.watch(monthToDateSpendProvider);
    final burnRateProjection = ref.watch(monthBurnRateProjectionProvider);
    final recurringForecast = ref.watch(recurringCommitmentForecastProvider);
    final hasMonthOutlook =
        profile?.monthlyBudget != null ||
        burnRateProjection != null ||
        recurringForecast > 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Insights'),
            titleSpacing: Spacing.lg,
          ),
          if (transactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.insights_rounded,
                title: 'Nothing logged yet',
                message:
                    'Log a few transactions and this fills up with category '
                    'breakdowns, trends, and how much you\'re saving.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                Spacing.xxxl,
              ),
              sliver: SliverList.list(
                children: [
                  if (profile != null) ...[
                    GamificationStrip(profile: profile),
                    const SizedBox(height: Spacing.lg),
                  ],
                  RangeSelector(range: _range, onChanged: _onRangeChanged),
                  if (_range == InsightsRange.custom) ...[
                    const SizedBox(height: Spacing.sm),
                    InputChip(
                      avatar: const Icon(
                        Icons.calendar_today_rounded,
                        size: IconSize.sm,
                      ),
                      label: Text(
                        current.start == current.end
                            ? DateFormat.MMMd().format(current.start)
                            : '${DateFormat.MMMd().format(current.start)} – '
                                  '${DateFormat.MMMd().format(current.end)}',
                      ),
                      onPressed: _pickCustomRange,
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  SummaryHero(
                    current: current,
                    previous: previous,
                    currencyCode: currencyCode,
                  ),
                  const SizedBox(height: Spacing.lg),
                  NetSummaryCard(window: current, currencyCode: currencyCode),
                  if (hasMonthOutlook) ...[
                    const SizedBox(height: Spacing.xl),
                    MonthOutlookCard(
                      monthlyBudget: profile?.monthlyBudget,
                      monthToDateSpend: monthToDateSpend,
                      burnRateProjection: burnRateProjection,
                      recurringForecast: recurringForecast,
                      currencyCode: currencyCode,
                    ),
                  ],
                  const SizedBox(height: Spacing.xl),
                  const SectionHeader(title: 'By category'),
                  CategoryBreakdown(
                    byCategory: byCategory,
                    total: current.total,
                    colors: categoryColors,
                    currencyCode: currencyCode,
                    onCategoryTap: _openCategoryHistory,
                    categoriesWithActiveQuest: categoriesWithActiveQuest,
                  ),
                  if (budgetedCategories.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xl),
                    const SectionHeader(title: 'Category budgets'),
                    CategoryBudgetsCard(
                      categories: budgetedCategories,
                      spentByCategory: monthToDateByCategory,
                      currencyCode: currencyCode,
                    ),
                  ],
                  const SizedBox(height: Spacing.xl),
                  const SectionHeader(title: 'Daily trend'),
                  TrendChart(
                    window: current,
                    range: _range,
                    currencyCode: currencyCode,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
