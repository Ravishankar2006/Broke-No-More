import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../providers/profile_provider.dart';
import '../../shared_widgets/app_avatar.dart';
import '../../shared_widgets/discard_changes_guard.dart';
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
  late final String _initialName;
  late final String _initialAvatarId;
  bool _submitted = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _initialName = profile?.name ?? '';
    _initialAvatarId = profile?.avatarId ?? kAvatarChoices.first;
    _nameController = TextEditingController(text: _initialName);
    _avatarId = _initialAvatarId;
    _nameController.addListener(() {
      if (_submitted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _nameController.text.trim() != _initialName ||
      _avatarId != _initialAvatarId;

  String? get _nameError {
    if (!_submitted) return null;
    return _nameController.text.trim().isEmpty ? 'Enter a name' : null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    // If the profile has somehow disappeared out from under this sheet,
    // _saving must still be reset — otherwise the button stays disabled
    // forever with no way to close and retry.
    final profile = ref.read(profileProvider);
    if (profile == null) {
      setState(() {
        _saving = false;
        _saveError = "Couldn't save — please try again.";
      });
      return;
    }

    try {
      final updated = profile.copyWith(name: name, avatarId: _avatarId);
      await ref.read(profileRepositoryProvider).save(updated);
      ref.read(profileProvider.notifier).setProfile(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = "Couldn't save — please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DiscardChangesGuard(
      isDirty: _isDirty,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
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
                const SizedBox(height: Spacing.xl),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                Text('Avatar', style: theme.textTheme.titleSmall),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.md,
                  runSpacing: Spacing.md,
                  children: [
                    for (final emoji in kAvatarChoices)
                      AppAvatar(
                        emoji: emoji,
                        size: MedallionSize.avatarPicker,
                        selected: emoji == _avatarId,
                        onTap: () => setState(() => _avatarId = emoji),
                      ),
                  ],
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: Spacing.md),
                  Text(
                    _saveError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: IconSize.md,
                            height: IconSize.md,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
