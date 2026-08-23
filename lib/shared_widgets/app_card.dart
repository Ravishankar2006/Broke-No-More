import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_motion.dart';

/// The app's surface primitive, replacing bare [Card].
///
/// Two things this fixes. First, depth: the Material [Card] theme is
/// `elevation: 0` with a 1px hairline border, which reads flat, so every screen
/// looked like a wireframe of stacked rectangles. [AppCard] carries a real
/// tinted shadow instead. Second, hierarchy: [AppCard.hero] exists so a screen
/// can have an obvious focal point rather than a run of identical peers.
///
/// It also owns its padding, so screens stop repeating
/// `Padding(padding: EdgeInsets.all(Spacing.lg), child: Column(...))` around
/// every single card.
class AppCard extends StatelessWidget {
  /// Default surface. Use for most content.
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  })  : gradient = null,
        _elevated = false;

  /// A screen's focal point: gradient fill plus a gold glow. At most one per
  /// screen — the glow is the app's loudest signal, and two of them means
  /// neither reads as the hero.
  const AppCard.hero({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.onTap,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  })  : color = null,
        _elevated = true;

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final CrossAxisAlignment crossAxisAlignment;
  final bool _elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final radius = BorderRadius.circular(AppRadius.lg);

    final content = Padding(
      padding: padding ?? EdgeInsets.all(Spacing.lg),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? theme.colorScheme.surface) : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: _elevated
            ? AppShadows.gold(brightness)
            : AppShadows.card(brightness),
        // In dark mode the shadow alone can't separate a surface from a
        // near-black canvas, so surfaces get a hairline to define their edge.
        border: brightness == Brightness.dark && gradient == null
            ? Border.all(color: theme.colorScheme.outlineVariant, width: 1)
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: onTap == null
            ? content
            : _PressScale(
                onTap: onTap!,
                borderRadius: radius,
                child: content,
              ),
      ),
    );
  }
}

/// Adds a subtle shrink-on-press to a tappable surface.
///
/// A ripple alone doesn't read as "pressable" on a large card — the ink is too
/// far from the finger. Scaling the whole surface does, and it's the tactile
/// cue a gamified app is expected to have.
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: AppMotion.quick,
      curve: AppMotion.standardCurve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
