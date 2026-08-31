import 'package:flutter/material.dart';

/// Wraps the content of a modal bottom sheet (or dialog) so a swipe-down or
/// back-gesture dismissal while [isDirty] is true prompts to confirm
/// discarding, instead of silently losing what the user typed.
///
/// The log sheet, the recurring-rule editor and the edit-profile sheet all
/// used to discard on dismiss with no warning — this is the shared fix for
/// all three, rather than three copies of the same confirm-dialog logic.
class DiscardChangesGuard extends StatelessWidget {
  const DiscardChangesGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  /// Whether the sheet currently holds unsaved changes. Re-evaluated on
  /// every dismissal attempt, so a field cleared back to its original value
  /// stops prompting.
  final bool isDirty;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text("You haven't saved this yet."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
