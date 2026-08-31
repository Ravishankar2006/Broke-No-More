import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';

/// A tappable row with a leading icon chip, title and optional subtitle —
/// used throughout Profile's settings cards.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: MedallionSize.iconChip,
        height: MedallionSize.iconChip,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: IconSize.md, color: cs.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// Same leading-icon-chip layout as [SettingsTile], but for a boolean
/// setting rather than a navigation row.
class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SwitchListTile(
      secondary: Container(
        width: MedallionSize.iconChip,
        height: MedallionSize.iconChip,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: IconSize.md, color: cs.onSurfaceVariant),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A divider indented to clear a [SettingsTile]/[SwitchTile]'s 36px leading
/// icon chip, so it reads as separating rows rather than cutting through
/// the icon column.
class TileDivider extends StatelessWidget {
  const TileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: Spacing.lg + MedallionSize.iconChip + Spacing.lg,
    );
  }
}
