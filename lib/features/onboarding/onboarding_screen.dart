import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../providers/profile_provider.dart';

const _avatarIds = ['🦊', '🐼', '🐨', '🐸', '🦉', '🐢'];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  String _selectedAvatar = _avatarIds.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final budgetText = _budgetController.text.trim();
    // No explicit navigation here — BrokeNoMoreApp watches profileProvider
    // and swaps MaterialApp.home to HomeShell reactively once it's set.
    await ref.read(profileProvider.notifier).createProfile(
          name: _nameController.text.trim(),
          avatarId: _selectedAvatar,
          monthlyBudget: budgetText.isEmpty ? null : double.tryParse(budgetText),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: Spacing.xl),
              Text('Welcome to Broke No More',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: Spacing.sm),
              Text(
                'Log spending, build a streak, level up. Takes less than a minute to set up.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: Spacing.xl),
              Text('What should we call you?',
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: Spacing.sm),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                ),
              ),
              SizedBox(height: Spacing.xl),
              Text('Pick an avatar', style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.md,
                children: _avatarIds.map((avatar) {
                  final selected = avatar == _selectedAvatar;
                  return ChoiceChip(
                    label: Text(avatar, style: const TextStyle(fontSize: 20)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedAvatar = avatar),
                  );
                }).toList(),
              ),
              SizedBox(height: Spacing.xl),
              Text('Monthly budget (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: Spacing.sm),
              TextField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'e.g. 8000',
                ),
              ),
              SizedBox(height: Spacing.xl),
              Container(
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: EdgeInsets.all(Spacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: context.semantics.goldInk),
                    SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        'Every logged transaction earns XP. Log daily to build a streak — '
                        'levels get harder to reach the further you go.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(cs.onTertiary),
                          ),
                        )
                      : const Text('Get started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
