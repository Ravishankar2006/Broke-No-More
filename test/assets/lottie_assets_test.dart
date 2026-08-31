import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// The three celebration animations are hand-authored shape-layer JSON rather
/// than exported from After Effects, so "it's valid JSON" is not enough — these
/// assert the Lottie parser actually accepts them and that they carry real
/// animated content. A malformed file would otherwise fail silently at runtime,
/// leaving a blank space where a reward moment should be.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = <String, ({int layers, double minDurationMs})>{
    'assets/lottie/level_up.json': (layers: 4, minDurationMs: 900),
    'assets/lottie/badge_unlock.json': (layers: 2, minDurationMs: 1400),
    'assets/lottie/streak_flame.json': (layers: 3, minDurationMs: 1900),
  };

  assets.forEach((path, expected) {
    test('$path parses as a Lottie composition', () async {
      final bytes = await rootBundle.load(path);
      final composition = await LottieComposition.fromBytes(
        bytes.buffer.asUint8List(),
      );

      expect(
        composition.layers.length,
        expected.layers,
        reason: 'layer count changed for $path',
      );
      expect(
        composition.duration.inMilliseconds,
        greaterThanOrEqualTo(expected.minDurationMs.toInt()),
        reason: '$path should actually animate, not be a single static frame',
      );
      expect(composition.bounds.width, greaterThan(0));
      expect(composition.bounds.height, greaterThan(0));
    });
  });
}
