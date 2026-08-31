import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_motion.dart';

/// A shimmering placeholder block.
///
/// Replaces the bare centred [CircularProgressIndicator] that Home and Profile
/// showed while the profile loaded. A spinner on a blank screen communicates
/// nothing about what's coming; a skeleton in the shape of the real content
/// makes the load feel shorter and stops the layout jumping when data lands.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  /// A full-width block.
  const Skeleton.block({super.key, required this.height, this.radius})
    : width = double.infinity;

  final double width;
  final double height;
  final double? radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A perpetually-sweeping gradient is exactly what "remove animations"
    // asks to be turned off; deferred from initState since it needs
    // MediaQuery, which isn't available yet at construction time.
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHigh;
    final highlight = cs.surfaceContainerHighest;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                widget.radius ?? AppRadius.sm,
              ),
              gradient: LinearGradient(
                colors: [base, highlight, base],
                stops: const [0.0, 0.5, 1.0],
                // Sweep from off-screen left to off-screen right.
                begin: Alignment(-1.0 - 2 * (1 - _controller.value), 0),
                end: Alignment(1.0 + 2 * _controller.value, 0),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton standing in for a card of stacked lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.md),
            Skeleton(
              // Taper the lines so it reads as text, not as bars.
              width: i == 0 ? 140 : double.infinity,
              height: i == 0 ? 20 : 14,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen loading state built from skeleton cards.
class SkeletonScreen extends StatelessWidget {
  const SkeletonScreen({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Spacing.lg),
      itemCount: cards,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
      itemBuilder: (_, i) => SkeletonCard(lines: i == 0 ? 4 : 3),
    );
  }
}
