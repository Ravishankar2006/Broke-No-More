import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

const _confettiColors = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.xp,
  AppColors.streak,
];

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
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              colors: _confettiColors,
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
  const BounceIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: child,
    );
  }
}
