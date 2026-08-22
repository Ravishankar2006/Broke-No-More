# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Broke No More** — a standalone, fully offline Flutter app (Android/iOS) that gamifies personal
expense tracking: manual transaction logging earns XP, builds streaks, unlocks badges, and drives
rule-based quests. No backend, no auth, no cloud sync — everything lives in local Hive boxes. Full
product spec is in `Docs/PRD/finance-app-prd.md`; read it for XP formulas, streak/freeze rules,
quest-generation rules, and badge criteria before changing any of that logic.

## Commands

```bash
flutter pub get                       # install dependencies
flutter pub run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart (Hive adapters) after editing any model in lib/models/
flutter analyze                       # static analysis (flutter_lints, see analysis_options.yaml)
flutter test                          # run all tests
flutter test test/core/xp_engine_test.dart   # run a single test file
flutter test --plain-name "caps out at kMaxXpEligibleLogsPerDay"   # run a single test by name
flutter run                           # run the app on a connected device/emulator
```

Every `lib/models/*.dart` file is a `HiveObject` with a matching generated `*.g.dart` adapter —
regenerate with `build_runner` any time you add/remove a `@HiveField`, and never hand-edit the
generated files.

## Architecture

**State management is Riverpod, layered strictly as repository → provider → orchestrator → UI.**
This layering exists because a single user action (logging a transaction) must fan out to XP,
streak, quest progress, and badge unlocks atomically, then reactively update every screen watching
any of that state.

```
lib/
├── core/
│   ├── database/hive_boxes.dart   # box names + initHive() — adapter registration, box opening, default-category seeding
│   ├── theme/                     # design tokens, light/dark themes
│   ├── notifications/             # local streak-reminder scheduling (flutter_local_notifications)
│   └── utils/                     # pure engines (see below) + date/currency/icon helpers
├── models/                        # HiveObject data classes (Transaction, UserProfile, Quest, Badge, CategoryRecord)
├── data/                          # repositories — thin Hive CRUD wrappers, one per model/box
├── providers/                     # Riverpod providers/notifiers, one per repository, plus xp_engine_provider.dart (the orchestrator)
├── features/                      # screens, one folder per PRD flow (onboarding, home, log_transaction, quests, insights, profile)
└── shared_widgets/                # widgets shared across features (xp_bar, streak_calendar, quest_card, celebration effects, badge dialogs)
```

### Pure engines (`lib/core/utils/`)

`xp_engine.dart`, `quest_engine.dart`, and `badge_engine.dart` are deliberately plain Dart with
**no Flutter or Riverpod dependency** — this is the key design decision from the PRD (section 8)
and is what makes `test/core/*_test.dart` possible without widget/provider scaffolding. When
changing XP/streak/level/quest/badge rules, edit these files, not the orchestrator or providers.
Callers (the orchestrator) own persistence and sequencing; the engines only compute results from
inputs.

- `xp_engine.dart` — XP constants, `xpForLevel`/`levelForXp` (level curve: `100 * n * (n+1) / 2`),
  `evaluateStreak` (streak/freeze logic), `shouldAwardDailyBudgetBonus`, `shouldResetWeeklyFreeze`.
- `quest_engine.dart` — `evaluateQuestAfterTransaction`, pure per-quest-type progress evaluation.
- `quest_template_engine.dart` — the offline rule engine that turns recent spending patterns into
  quest candidates (PRD section 7).
- `badge_engine.dart` — `kBadgeCatalog` (the full badge list + unlock thresholds) and
  `evaluateNewlyUnlockedBadges`.

### The orchestrator (`lib/providers/xp_engine_provider.dart`)

`XpEngineOrchestrator.logTransaction(...)` is the single entry point for "user logged a
transaction." It: saves the transaction, computes XP/streak/budget-bonus via the pure engines,
advances every active quest, unlocks any newly-eligible badges, persists the updated profile, and
pushes all the resulting state into `transactionsProvider` / `profileProvider` / `questsProvider` /
`badgesProvider` so dependent screens rebuild reactively. Any new action that should affect
XP/streak/quests/badges belongs as a step in this orchestrator, not scattered across UI code.

### Persistence

Hive only (no SQL). `initHive()` in `core/database/hive_boxes.dart` registers all adapters, opens
all boxes, and seeds default categories on first run — it must complete before `runApp`. Box names
are centralized in `HiveBoxes`; repositories never hardcode box-name strings.

### Notable behavior to preserve

- **Anti-abuse cap**: only the first `kMaxXpEligibleLogsPerDay` (10) logs per calendar day earn
  transaction XP.
- **Streak freeze**: a 1-day gap continues the streak normally; a 2-day gap consumes a weekly
  streak-freeze (if available) instead of breaking it; anything larger resets to 1.
- **Quest expiry**: `QuestRepository().expireOverdueQuests()` runs once at app startup (in
  `main.dart`) — it's the only guaranteed checkpoint for expiring quests whose `endDate` passed
  while the app was closed, since there's no backend to run this on a schedule.
