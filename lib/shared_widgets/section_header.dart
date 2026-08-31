import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_typography.dart';

/// A labelled section break.
///
/// Replaces the pattern of recolouring `titleMedium` to `colorScheme.primary`,
/// which was copy-pasted verbatim three times in the Quests screen and gave
/// sections no more weight than body text. An overline-styled label plus an
/// optional count reads as structure instead.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Shown as a pill beside the title. Null hides it — pass null rather than 0
  /// so an empty section doesn't advertise its emptiness twice.
  final int? count;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md, top: Spacing.xs),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: kOverlineLetterSpacing,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: Spacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                // Was Size.zero + shrinkWrap, which let this button render
                // (and hit-test) well under the 48dp minimum tap target —
                // easy to miss and inaccessible for low-dexterity users.
                minimumSize: const Size(0, kMinTapTarget),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
