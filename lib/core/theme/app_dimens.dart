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

/// Icon glyph sizes — the `size:` passed to an `Icon` widget. Previously ~9
/// ad hoc literals (14-44px) scattered across icon-only `Icon()` call
/// sites, each hand-picked per screen with no shared rule.
abstract class IconSize {
  static const double xs = 14; // stat-tile caption icons
  static const double sm = 16; // inline chip/date icons, day-dot glyphs
  static const double smMd =
      18; // secondary action icons (close, search prefix)
  static const double md = 20; // primary tile/button icons, inline spinners
  static const double mdLg = 22; // category-picker, quest-complete row icons
  static const double lg = 24; // hero-adjacent icons (log-sheet category cell)
  static const double xl = 28; // FAB icon, badge-shelf glyphs
  static const double xxl = 36; // medallion-embedded icons
  static const double xxxl = 44; // large medallion icons (badge detail sheet)
  static const double hero =
      56; // boot-failure status icon, streak-flame animation
  static const double heroLg = 60; // onboarding welcome icon
}

/// Circular avatar/medallion/icon-chip diameters — the `width`/`height` of a
/// `Container`, `AppAvatar`, or celebration-dialog medallion. Previously
/// ~15 ad hoc literals (30-148px), each a slightly different hand-picked
/// value for what was usually the same idea: an icon or emoji inside a
/// circle. Named by role rather than a strict linear scale, since the roles
/// genuinely span from a 30px calendar dot to a 148px dialog hero.
abstract class MedallionSize {
  static const double dayDot = 30; // streak calendar day dot
  static const double iconChip = 36; // settings-tile / quest-card icon chip
  static const double avatarCompact = 36; // home greeting-row avatar
  static const double transactionChip =
      40; // transaction/recurring row icon chip
  static const double badgeSmall =
      44; // badge-shelf small medallion, quest-complete icon
  static const double categoryCell = 48; // category icon-picker cell
  static const double xpMedallion = 52; // XP bar level medallion
  static const double avatarPicker =
      56; // avatar choice (edit-profile) / badge-unlock ring
  // Onboarding's avatar picker uses 64px, edit-profile's uses 56px — a real
  // inconsistency for the same idiom, preserved here rather than silently
  // unified without visual verification. Worth reconciling in a design pass.
  static const double avatarPickerLg = 64; // avatar choice (onboarding)
  static const double badgeDetail =
      60; // badge detail-sheet medallion, onboarding icon
  static const double badgeShelfCell = 68; // badge shelf horizontal cell width
  static const double profileAvatar =
      72; // profile header avatar, quest-complete icon
  static const double dialogSecondary = 78; // level-up secondary medallion
  static const double dialogPrimary = 96; // badge-unlock primary medallion
  static const double badgeShelfHeight = 108; // badge shelf row height
  static const double onboardingHero = 120; // onboarding welcome logo
  static const double celebrationHero = 148; // level-up primary medallion
}

/// The minimum recommended touch-target side length (Material/WCAG both
/// converge on 48dp), for custom tappable widgets that don't already get it
/// from a Material component's own theming.
const double kMinTapTarget = 48;

/// Fixed heights for the two Insights charts — previously two more ad hoc
/// literals (180, 210), each hand-picked per chart with no shared rule.
abstract class ChartSize {
  static const double trend = 180; // daily-trend bar chart
  static const double pie = 210; // category-breakdown pie chart
}
