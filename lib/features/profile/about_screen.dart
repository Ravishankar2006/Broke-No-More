import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_dimens.dart';
import '../../shared_widgets/app_avatar.dart';

/// App version and open-source licences — the PRD's data-ownership story
/// (fully offline, nothing leaves the device) previously had nowhere to
/// state that plainly, and there was no way to see which version was
/// installed without checking the OS app-info page.
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const Center(
            child: AppAvatar(emoji: '💸', size: MedallionSize.dialogPrimary),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Broke No More',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final label = info == null
                  ? ' '
                  : 'Version ${info.version} (${info.buildNumber})';
              return Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text(
            'Fully offline. No account, no server, no analytics — every '
            'transaction, badge and quest lives only on this device. '
            'Nothing you log here is ever sent anywhere.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Center(
            child: OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Broke No More',
              ),
              child: const Text('Open-source licences'),
            ),
          ),
        ],
      ),
    );
  }
}
