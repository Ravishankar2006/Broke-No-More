import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';

/// Paths to the hand-authored celebration animations.
abstract class CelebrationAssets {
  static const levelUp = 'assets/lottie/level_up.json';
  static const badgeUnlock = 'assets/lottie/badge_unlock.json';
  static const streakFlame = 'assets/lottie/streak_flame.json';
}

/// Wraps a celebration dialog's content with a one-shot confetti burst that
/// plays as soon as it appears — shared by the level-up and badge-unlock
/// dialogs so neither has to manage a [ConfettiController] itself.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({super.key, required this.child});

  final Widget child;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst> {
  late final ConfettiController _controller = ConfettiController(
    duration: AppMotion.confetti,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deferred from initState: needs an inherited MediaQuery, which isn't
    // available yet at construction time.
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.play();
    }
    // The burst is silent otherwise; a reward the user can feel lands harder.
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Remove animations" is an explicit accessibility opt-out — respecting
    // it means suppressing the confetti burst entirely, not just shortening it.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final confettiColors = [
      Theme.of(context).colorScheme.primary,
      context.semantics.xp,
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
      context.semantics.xp.withValues(alpha: 0.7),
    ];
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          top: -12,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 22,
              maxBlastForce: 18,
              minBlastForce: 7,
              gravity: 0.35,
              shouldLoop: false,
              colors: confettiColors,
            ),
          ),
        ),
      ],
    );
  }
}

/// Scales [child] in with an overshoot bounce — used for the icon at the
/// top of a celebration dialog so it doesn't just pop in flat.
class BounceIn extends StatelessWidget {
  const BounceIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;

  /// Staggers multi-item reveals, so several badges arrive in sequence rather
  /// than all bouncing in unison.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppMotion.bounce,
      curve: AppMotion.spring,
      // TweenAnimationBuilder has no delay, so hold at scale 0 until the
      // stagger has elapsed.
      builder: (context, value, child) => delay == Duration.zero
          ? Transform.scale(scale: value, child: child)
          : _DelayedScale(delay: delay, value: value, child: child!),
      child: child,
    );
  }
}

class _DelayedScale extends StatefulWidget {
  const _DelayedScale({
    required this.delay,
    required this.value,
    required this.child,
  });

  final Duration delay;
  final double value;
  final Widget child;

  @override
  State<_DelayedScale> createState() => _DelayedScaleState();
}

class _DelayedScaleState extends State<_DelayedScale> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _started ? widget.value : 0,
      child: widget.child,
    );
  }
}

/// A number that rolls up to its value rather than snapping.
///
/// XP totals and currency amounts changing instantly is the single clearest
/// tell that a gamified app isn't finished.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.countUp,
      curve: AppMotion.standardCurve,
      builder: (context, animated, _) {
        return Text('$prefix${animated.round()}$suffix', style: style);
      },
    );
  }
}

/// A Lottie celebration sized to [size], falling back to [fallbackIcon] if the
/// animation asset can't be loaded.
///
/// The fallback matters: the animations are hand-authored, and a celebration
/// that renders as a blank gap is worse than one that renders as a static icon.
class CelebrationAnimation extends StatelessWidget {
  const CelebrationAnimation({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.size = 120,
    this.repeat = false,
  });

  final String asset;
  final IconData fallbackIcon;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    // A looping Lottie (the Home streak flame) is exactly the kind of
    // perpetual motion "remove animations" is meant to suppress; freeze on
    // the fallback icon instead of playing even a single pass.
    if (repeat && MediaQuery.disableAnimationsOf(context)) {
      return Icon(fallbackIcon, size: size * 0.6, color: semantics.xp);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) =>
            Icon(fallbackIcon, size: size * 0.6, color: semantics.xp),
      ),
    );
  }
}

/// Shows a floating "+N XP" chip near the top of the screen.
///
/// This closes the app's biggest feedback gap: logging a transaction that
/// didn't happen to trigger a level-up produced *no* acknowledgement at all —
/// the sheet just closed. Every log now gets a visible reward.
///
/// Uses an overlay rather than a SnackBar so it doesn't displace layout or
/// collide with the bottom navigation bar.
void showXpGain(BuildContext context, int xp) {
  if (xp <= 0) return;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  HapticFeedback.lightImpact();
  // The chip itself sits inside an IgnorePointer/opacity-animated overlay
  // that a screen reader has no reason to visit, so without this a TalkBack
  // user gets no signal at all that logging just earned XP.
  SemanticsService.sendAnnouncement(
    View.of(context),
    '+$xp XP earned',
    TextDirection.ltr,
  );

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _XpGainChip(
      xp: xp,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _XpGainChip extends StatefulWidget {
  const _XpGainChip({required this.xp, required this.onDone});

  final int xp;
  final VoidCallback onDone;

  @override
  State<_XpGainChip> createState() => _XpGainChipState();
}

class _XpGainChipState extends State<_XpGainChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.xpChipLifetime,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + Spacing.md,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            // Rise and fade: in over the first 20%, hold, out over the last 25%.
            final opacity = t < 0.2
                ? (t / 0.2)
                : t > 0.75
                ? (1 - (t - 0.75) / 0.25)
                : 1.0;
            final rise = t < 0.2 ? (1 - t / 0.2) * 16 : -8 * (t - 0.2);
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, rise), child: child),
            );
          },
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: AppGradients.xp(theme.brightness),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.gold(theme.brightness),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt,
                    size: IconSize.smMd,
                    color: semantics.onGold,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    '+${widget.xp} XP',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: semantics.onGold,
                      fontWeight: FontWeight.w800,
                    ),
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
