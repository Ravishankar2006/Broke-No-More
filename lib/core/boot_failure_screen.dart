import 'package:flutter/material.dart';

import 'theme/app_dimens.dart';
import 'theme/app_theme.dart';

/// Rendered instead of the app when startup (`initHive`, recurring-rule
/// materialization, quest expiry, or the gamification repair pass) throws.
///
/// Without this, a Hive failure (corrupt box, adapter mismatch, full disk)
/// kills the process at the native launch screen with no UI and no recovery
/// path — the user just sees the app "not open". This gives them a retry,
/// which is enough for transient failures (disk momentarily full, a race on
/// first-ever launch); a boot step that fails deterministically will need a
/// reinstall, since there's no backend to reset from.
class BootFailureScreen extends StatelessWidget {
  const BootFailureScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Broke No More',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: IconSize.hero,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    "Broke No More couldn't start",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Something went wrong loading your data on this device. '
                    'Your transactions are still on disk — try again, or '
                    'restart the app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: Spacing.xl),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
