import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_catalog.dart';
import '../../providers/profile_provider.dart';
import '../../shared_widgets/app_avatar.dart';
import '../profile/profile_screen.dart' show kAvatarChoices;

/// Setup, in three steps.
///
/// Was a single long scroll asking for name, avatar and budget all at once,
/// with an avatar picker built from ChoiceChips — which rendered each emoji as
/// a stadium pill around a tiny glyph rather than as a selectable avatar — and
/// a submit button that silently did nothing when the name was blank.
///
/// Paging keeps the PRD's "under 60 seconds" target while giving the app a
/// first impression, which it previously had none of: no logo, no illustration,
/// no brand moment anywhere.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 3;

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  int _page = 0;
  String _selectedAvatar = kAvatarChoices.first;
  String _selectedCurrencyCode = kDefaultCurrencyCode;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_submitted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _nameController.text.trim().isEmpty
        ? 'We need a name to start'
        : null;
  }

  void _next() {
    // Gate leaving the identity page on a name, with visible feedback rather
    // than a silent no-op.
    if (_page == 1 && _nameController.text.trim().isEmpty) {
      setState(() => _submitted = true);
      HapticFeedback.heavyImpact();
      return;
    }
    if (_page == _pageCount - 1) {
      _submit();
      return;
    }
    HapticFeedback.selectionClick();
    _pageController.nextPage(
      duration: AppMotion.slow,
      curve: AppMotion.standardCurve,
    );
  }

  Future<void> _submit() async {
    if (_saving) return;

    // The page gate in `_next()` only fires when Continue is pressed *on*
    // the identity page — the PageView itself is freely swipeable, so a
    // swipe straight to the budget page bypassed it entirely and let Start
    // create a blank-named profile. Re-check here, on the actual write path.
    if (_nameController.text.trim().isEmpty) {
      setState(() => _submitted = true);
      unawaited(HapticFeedback.heavyImpact());
      unawaited(
        _pageController.animateToPage(
          1,
          duration: AppMotion.slow,
          curve: AppMotion.standardCurve,
        ),
      );
      return;
    }

    setState(() {
      _submitted = true;
      _saving = true;
    });

    final budgetText = _budgetController.text.trim();
    try {
      // No explicit navigation here — BrokeNoMoreApp watches profileProvider
      // and swaps MaterialApp.home to HomeShell reactively once it's set.
      await ref
          .read(profileProvider.notifier)
          .createProfile(
            name: _nameController.text.trim(),
            avatarId: _selectedAvatar,
            monthlyBudget: budgetText.isEmpty
                ? null
                : double.tryParse(budgetText),
            currencyCode: _selectedCurrencyCode,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save your profile — please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressDots(count: _pageCount, current: _page),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  const _WelcomePage(),
                  _IdentityPage(
                    nameController: _nameController,
                    nameError: _nameError,
                    selectedAvatar: _selectedAvatar,
                    onAvatarSelected: (emoji) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAvatar = emoji);
                    },
                  ),
                  _BudgetPage(
                    controller: _budgetController,
                    currencyCode: _selectedCurrencyCode,
                    onCurrencyChanged: (code) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCurrencyCode = code);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? SizedBox(
                              height: IconSize.md,
                              width: IconSize.md,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onTertiary,
                                ),
                              ),
                            )
                          : Text(
                              _page == _pageCount - 1 ? 'Start' : 'Continue',
                            ),
                    ),
                  ),
                  if (_page == _pageCount - 1) ...[
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'You can change any of this later',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.standardCurve,
              margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              width: i == current ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= current ? semantics.xp : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}

/// The brand moment the app never had.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return _Page(
      children: [
        Container(
              width: MedallionSize.onboardingHero,
              height: MedallionSize.onboardingHero,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.xp(theme.brightness),
                boxShadow: AppShadows.gold(theme.brightness),
              ),
              child: Icon(
                Icons.savings_rounded,
                size: IconSize.heroLg,
                color: semantics.onGold,
              ),
            )
            .animate()
            .scale(
              duration: AppMotion.celebrate,
              curve: AppMotion.spring,
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
            )
            .fadeIn(),
        const SizedBox(height: Spacing.xxl),
        Text(
          'Broke No More',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          'Track what you spend, earn XP for showing up, and build a streak '
          "you won't want to break.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xxl),
        const _MechanicRow(
          icon: Icons.bolt,
          title: 'Earn XP',
          subtitle: 'Every transaction you log counts',
        ),
        const _MechanicRow(
          icon: Icons.local_fire_department,
          title: 'Build a streak',
          subtitle: 'Miss a day? One free freeze a week has you covered',
        ),
        const _MechanicRow(
          icon: Icons.flag_rounded,
          title: 'Take on quests',
          subtitle: 'Suggested from your own spending — never forced',
        ),
      ],
    );
  }
}

class _MechanicRow extends StatelessWidget {
  const _MechanicRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Row(
        children: [
          Container(
            width: MedallionSize.transactionChip,
            height: MedallionSize.transactionChip,
            decoration: BoxDecoration(
              color: semantics.goldSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: IconSize.md, color: semantics.goldInk),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: Spacing.xxs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityPage extends StatelessWidget {
  const _IdentityPage({
    required this.nameController,
    required this.nameError,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  final TextEditingController nameController;
  final String? nameError;
  final String selectedAvatar;
  final ValueChanged<String> onAvatarSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Page(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What should we call you?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: Spacing.sm),
        Text(
          'Stays on this device — there is no account and nothing leaves your '
          'phone.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xl),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Your name',
            errorText: nameError,
          ),
        ),
        const SizedBox(height: Spacing.xxl),
        Text('Pick an avatar', style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.lg),
        Wrap(
          spacing: Spacing.lg,
          runSpacing: Spacing.lg,
          children: [
            for (final emoji in kAvatarChoices)
              AppAvatar(
                emoji: emoji,
                size: MedallionSize.avatarPickerLg,
                selected: emoji == selectedAvatar,
                onTap: () => onAvatarSelected(emoji),
              ),
          ],
        ),
      ],
    );
  }
}

class _BudgetPage extends StatelessWidget {
  const _BudgetPage({
    required this.controller,
    required this.currencyCode,
    required this.onCurrencyChanged,
  });

  final TextEditingController controller;
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return _Page(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set a monthly budget', style: theme.textTheme.headlineSmall),
        const SizedBox(height: Spacing.sm),
        Text(
          'Optional. If you set one, staying under your daily share earns bonus '
          'XP.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xl),
        DropdownButtonFormField<String>(
          initialValue: currencyCode,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: [
            for (final currency in kSupportedCurrencies)
              DropdownMenuItem(
                value: currency.code,
                child: Text('${currency.symbol} ${currency.name}'),
              ),
          ],
          onChanged: (code) {
            if (code != null) onCurrencyChanged(code);
          },
        ),
        const SizedBox(height: Spacing.lg),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly budget',
            prefixText: '${currencyInfoFor(currencyCode).symbol} ',
            hintText: 'e.g. 8000',
          ),
        ),
        const SizedBox(height: Spacing.xl),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: semantics.goldSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt, color: semantics.goldInk),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  'Log within 30 minutes of spending for a quick-log bonus. '
                  'Only your first 10 logs a day earn XP, so there is no point '
                  'padding the list.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared page shell: scrollable, so a small screen with the keyboard up never
/// overflows.
class _Page extends StatelessWidget {
  const _Page({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xl,
        vertical: Spacing.lg,
      ),
      child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
    );
  }
}
