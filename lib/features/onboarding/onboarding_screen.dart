import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Welcome to Broke No More',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Log spending, build a streak, level up. Takes less than a minute to set up.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Text('What should we call you?',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text('Pick an avatar', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: _avatarIds.map((avatar) {
                  final selected = avatar == _selectedAvatar;
                  return ChoiceChip(
                    label: Text(avatar, style: const TextStyle(fontSize: 20)),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedAvatar = avatar),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Monthly budget (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'e.g. 8000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber),
                      const SizedBox(width: 12),
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
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
