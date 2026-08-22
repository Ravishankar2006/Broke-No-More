import 'package:flutter/material.dart';

/// Spacing tokens on a 4pt grid.
abstract class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii tokens. Use these exclusively — no hardcoded BorderRadius.circular(8).
abstract class AppRadius {
  static const double xs = 8; // progress-bar clips, chip avatars
  static const double sm = 12; // buttons, text fields, segmented button
  static const double md = 16; // inner containers, list-tile ink
  static const double lg = 20; // CARDS (was 16 in the old theme)
  static const double xl = 28; // dialogs, bottom sheet top, FAB
  static const double pill = 999; // fully rounded

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static BorderRadius vertical({double top = 0, double bottom = 0}) =>
      BorderRadius.only(
        topLeft: Radius.circular(top),
        topRight: Radius.circular(top),
        bottomLeft: Radius.circular(bottom),
        bottomRight: Radius.circular(bottom),
      );
  static const BorderRadius cardShape = BorderRadius.all(Radius.circular(lg));
}

/// Elevation z-index tokens.
abstract class AppElevation {
  static const double flat = 0;
  static const double chrome = 3; // bottom app bar (lifts off canvas)
  static const double fab = 3;
}
