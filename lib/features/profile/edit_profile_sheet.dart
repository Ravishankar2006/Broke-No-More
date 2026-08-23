import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../providers/profile_provider.dart';
import '../../shared_widgets/app_avatar.dart';
import 'profile_screen.dart' show kAvatarChoices;

/// Change the display name and avatar.
///
/// Both were previously set once during onboarding and then permanently fixed —
/// there was no path to change either, so a typo in the name was forever.
Future<void> showEditProfileSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _EditProfileSheet(),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late String _avatarId;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile?.name ?? '');
    _avatarId = profile?.avatarId ?? kAvatarChoices.first;
    _nameController.addListener(() {
      if (_submitted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _nameController.text.trim().isEmpty ? 'Enter a name' : null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() => _saving = true);
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final updated = profile.copyWith(name: name, avatarId: _avatarId);
    await ref.read(profileRepositoryProvider).save(updated);
    ref.read(profileProvider.notifier).setProfile(updated);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit profile', style: theme.textTheme.headlineSmall),
              SizedBox(height: Spacing.xl),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: _nameError,
                ),
              ),
              SizedBox(height: Spacing.xl),
              Text('Avatar', style: theme.textTheme.titleSmall),
              SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                children: [
                  for (final emoji in kAvatarChoices)
                    AppAvatar(
                      emoji: emoji,
                      size: 56,
                      selected: emoji == _avatarId,
                      onTap: () => setState(() => _avatarId = emoji),
                    ),
                ],
              ),
              SizedBox(height: Spacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
