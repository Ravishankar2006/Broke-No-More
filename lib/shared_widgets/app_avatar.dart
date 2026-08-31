import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';

/// The user's emoji avatar in a proper circular frame.
///
/// Previously the avatar was a raw `Text` at a fixed 28px inside a 76px circle,
/// so the glyph floated in the middle of a large empty ring. Here the emoji is
/// sized as a proportion of the frame, so it fills it at any size.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.emoji,
    this.size = 56,
    this.showRing = true,
    this.selected = false,
    this.onTap,
  });

  final String emoji;
  final double size;

  /// Draws the gold ring. Off for inline/list contexts where it would be noise.
  final bool showRing;

  /// Selection state for pickers — thickens the ring and scales the avatar up.
  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final cs = Theme.of(context).colorScheme;

    final ringWidth = selected ? 3.0 : 2.0;
    final avatar = AnimatedScale(
      scale: selected ? 1.06 : 1,
      duration: AppMotion.quick,
      curve: AppMotion.emphasized,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? semantics.goldSurface : cs.surfaceContainerHigh,
          border: showRing || selected
              ? Border.all(
                  color: selected ? semantics.xp : semantics.goldRing,
                  width: ringWidth,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          // Proportional, so the glyph fills the frame at every size.
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      selected: selected,
      label: emoji,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatar,
      ),
    );
  }
}
