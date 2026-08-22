# Product Requirements Document

## App name
Broke No More

## 1. Overview

A standalone, client-side Flutter mobile app that helps users build financial responsibility through habit-formation and gamification, not just passive expense tracking. Manual transaction entry is intentionally chosen over auto-sync, using gamified logging (XP, streaks, quests) to solve the friction/retention problem that kills most spending trackers.

**Primary audience:** Students and young earners — high responsiveness to streak/level mechanics, lower transaction volume (manual entry stays feasible), and impulsive spending is the core problem being solved.

**Platform:** Flutter, mobile (Android/iOS), fully offline, no backend for v1.

## 2. Goals

- Make logging a transaction fast enough to sustain a daily habit
- Turn financial discipline into a game loop (XP, levels, streaks, quests, badges) without making it feel punitive
- Give users spending insight that ties back to their own goals, not generic budgeting advice
- Be fully functional offline, with all data stored locally on-device

## 3. Non-goals (v1)

- No bank/SMS auto-sync or transaction auto-import
- No backend, cloud sync, or multi-device support
- No social features (leaderboards, shared budgets, friend comparisons)
- No account system / auth (local profile only)
- No push notifications requiring a server (local notifications only, if included)

## 4. Core user flow

```
Onboarding → Home Dashboard → {Log Transaction (FAB), Insights, Quests, Profile}
```

- **Onboarding**: quick setup (under 60 seconds) — local profile (name, avatar), optional starting monthly budget, brief intro to XP/streak mechanics.
- **Home dashboard**: current streak, XP bar/level, today's spending vs daily budget, FAB for logging a transaction.
- **Log transaction**: bottom sheet — amount, category (icon grid), optional note. Fast enough to use mid-demo.
- **Quests**: system-suggested (not forced) quests based on the user's own spending patterns, accept/skip; streak calendar; badge shelf.
- **Insights**: category breakdown, spending trend, week-over-week comparison.
- **Profile**: local identity, level/badges, budget & category settings, data export (CSV) / local backup, theme toggle.

## 5. Data model

```dart
Transaction {
  id: String (uuid)
  amount: double
  type: enum (expense, income)
  category: String
  note: String?
  timestamp: DateTime
  loggedAt: DateTime
  isQuickLog: bool        // logged within 30 min of the timestamp
}

UserProfile {
  id: String
  name: String
  avatarId: String        // preset avatar, no photo upload
  joinDate: DateTime
  currentXP: int
  level: int
  currentStreak: int
  longestStreak: int
  lastLoggedDate: DateTime
  monthlyBudget: double?
  badgeIds: List<String>
}

Quest {
  id: String
  title: String
  type: enum (streak, category-avoid, budget-limit, count)
  targetValue: int
  currentProgress: int
  startDate: DateTime
  endDate: DateTime
  xpReward: int
  status: enum (active, completed, failed, expired)
}

Badge {
  id: String
  name: String
  description: String
  iconId: String
  unlockedAt: DateTime?
}
```

## 6. XP & streak logic

### XP triggers

| Action | XP | Notes |
|---|---|---|
| Log a transaction | +5 | Base habit reward |
| Quick log (within 30 min) | +5 bonus | Rewards logging in the moment |
| Complete a daily streak day | +10 | At least one log that calendar day |
| Complete a weekly quest | +50–100 | Larger, less frequent reward |
| Stay under daily budget | +15 | Ties spending discipline to XP directly |

**Anti-abuse rule:** cap XP from transaction-logging at 10 logs/day to prevent farming XP with fake micro-transactions.

### Streak logic

- Increments once per calendar day with ≥1 logged transaction.
- Gap of 1 day from `lastLoggedDate` → streak continues; gap > 1 day → resets to 1.
- **Grace mechanic**: 1 free "streak freeze" per week so a single missed day doesn't erase progress.
- `longestStreak` is permanent and never resets — shown on profile.

### Level curve

```
xpForLevel(n) = 100 * n * (n + 1) / 2
```
Non-linear: fast early levels (week-one hook), slower later levels (long-term retention).

## 7. Quest generation (offline, rule-based)

No ML, no backend — local rule engine over the on-device transaction data:

1. Query last 7 days of transactions grouped by category.
2. Find categories where spend exceeds the user's own historical average for that category.
3. Match top offending categories against a local quest template library (e.g. "no [category] for [X] days", "spend under ₹[X] on [category] this week").
4. Present 2–3 candidate quests; user accepts, skips, or customizes. Never auto-assigned/forced.

## 8. Flutter architecture

**State management:** Riverpod — needed because a single action (logging a transaction) must reactively update XP, streak, level, and quest progress across multiple screens at once.

**Folder structure (feature-first):**

```
lib/
├── main.dart
├── core/
│   ├── database/       # Hive/SQLite setup, box registration
│   ├── theme/           # design tokens, light/dark theme
│   └── utils/           # date helpers, currency formatting
├── models/
│   ├── transaction.dart
│   ├── user_profile.dart
│   ├── quest.dart
│   └── badge.dart
├── data/
│   ├── transaction_repository.dart
│   ├── profile_repository.dart
│   └── quest_repository.dart   # includes rule engine
├── providers/
│   ├── transaction_provider.dart
│   ├── profile_provider.dart
│   ├── quest_provider.dart
│   └── xp_engine_provider.dart
├── features/
│   ├── onboarding/
│   ├── home/
│   ├── log_transaction/
│   ├── quests/
│   ├── insights/
│   └── profile/
└── shared_widgets/
    ├── xp_bar.dart
    ├── streak_calendar.dart
    └── quest_card.dart
```

**Key design decision:** XP/streak logic is written as pure Dart functions with no Flutter/Riverpod dependency, so it's independently unit-testable:

```dart
int calculateXpForTransaction(Transaction t, UserProfile profile) { ... }
StreakResult evaluateStreak(DateTime lastLogged, DateTime today, int freezesLeft) { ... }
```

**Data flow example (logging a transaction):**
Log screen → `transactionRepository.save()` → `transactionProvider` updates → XP engine computes new XP/streak → `profileProvider` updates → Home/Profile/Quests screens rebuild reactively.

## 9. Local persistence

- Hive or SQLite for all data (transactions, profile, quests, badges) — offline-first, no network dependency.
- CSV export from Profile for user-owned data portability (also a good backup mechanism given no cloud sync).

## 10. Tech stack summary

- **Framework:** Flutter
- **State management:** Riverpod
- **Local DB:** Hive (or SQLite via drift/sqflite)
- **Charts:** fl_chart
- **Animations:** Rive or Lottie for celebration/level-up moments
- **Notifications:** flutter_local_notifications (streak reminders — optional v1.1)

## 11. Open questions / decisions still needed

- Branding details (logo, color palette, tone of voice for copy)
- Exact badge list and unlock conditions
- Exact quest template library (full set of rule-based templates)
- Whether streak-freeze count resets weekly or accumulates with a cap
- Icon/category set for the log-transaction grid
