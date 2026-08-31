import 'package:flutter/material.dart';

import '../../../core/theme/app_semantic_colors.dart';

/// Stable hash for category-to-colour assignment. Hand-rolled djb2 (not
/// String.hashCode, which Dart does not guarantee stable across
/// runs/platforms).
int _paletteSeed(String key) {
  var h = 5381;
  for (final u in key.codeUnits) {
    h = ((h * 33) ^ u) & 0x7fffffff;
  }
  return h;
}

/// Assigns each category a stable colour index, independent of logging
/// order — called once per build to map category names to chart palette
/// slots deterministically.
Map<String, Color> assignCategoryColors(
  Iterable<String> categories,
  List<Color> palette,
) {
  final sorted = categories.toList()..sort();
  final taken = <int>{};
  final out = <String, Color>{};
  for (final name in sorted) {
    var i = _paletteSeed(name) % palette.length;
    while (taken.contains(i) && taken.length < palette.length) {
      i = (i + 1) % palette.length;
    }
    taken.add(i);
    out[name] = palette[i];
  }
  return out;
}

/// The high-contrast text colour for a slice of background colour [bg].
Color onSliceTextColor(BuildContext context, Color bg) {
  return bg.computeLuminance() > 0.45 ? context.semantics.onGold : Colors.white;
}
