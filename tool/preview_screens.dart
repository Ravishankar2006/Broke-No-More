// Throwaway visual-review harness.
//
// Flutter web sizes its view to the browser window, and this machine's Wayland
// session won't let the window be resized to phone dimensions — so the real
// screens are rendered here inside fixed 412x915 frames instead, two per row,
// against seeded data. Not part of the app; run with:
//
//   flutter build web -t tool/preview_screens.dart -o build/preview
import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/home/home_screen.dart';
import 'package:broke_no_more/features/insights/insights_screen.dart';
import 'package:broke_no_more/features/log_transaction/log_transaction_sheet.dart';
import 'package:broke_no_more/features/onboarding/onboarding_screen.dart';
import 'package:broke_no_more/features/profile/category_management_screen.dart';
import 'package:broke_no_more/features/profile/profile_screen.dart';
import 'package:broke_no_more/features/quests/quests_screen.dart';
import 'package:broke_no_more/features/transactions/transaction_history_screen.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  await _seed();
  runApp(const ProviderScope(child: _PreviewApp()));
}

Future<void> _seed() async {
  final profiles = Hive.box<UserProfile>(HiveBoxes.profile);
  final transactions = Hive.box<Transaction>(HiveBoxes.transactions);
  await transactions.clear();

  final now = DateTime.now();
  await profiles.put(
    'local',
    UserProfile(
      id: 'local',
      name: 'Ravishankar',
      avatarId: '🦊',
      joinDate: now.subtract(const Duration(days: 40)),
      currentXP: 640,
      level: 4,
      currentStreak: 6,
      longestStreak: 14,
      monthlyBudget: 8000,
    ),
  );

  final categories = Hive.box<CategoryRecord>(
    HiveBoxes.categories,
  ).values.where((c) => c.type == TransactionType.expense).toList();

  var i = 0;
  for (final offset in [0, 0, 1, 2, 4, 5, 5, 6, 8, 9, 11, 12]) {
    final day = now.subtract(Duration(days: offset));
    await transactions.put(
      't$i',
      Transaction(
        id: 't$i',
        amount: [180.0, 1249.75, 42.0, 620.5, 95.0][i % 5],
        type: i == 3 ? TransactionType.income : TransactionType.expense,
        category: categories[i % categories.length].name,
        note: i.isEven ? 'Lunch with the team' : null,
        timestamp: day,
        loggedAt: day,
        isQuickLog: i.isEven,
        xpAwarded: i < 10 ? 10 : 0,
      ),
    );
    i++;
  }
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _Board(),
    );
  }
}

class _Board extends StatefulWidget {
  const _Board();

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  Brightness _brightness = Brightness.light;
  String _current = 'Home';

  static const _screens = <String, Widget>{
    'Home': HomeScreen(),
    'Insights': InsightsScreen(),
    'Quests': QuestsScreen(),
    'Profile': ProfileScreen(),
    'History': TransactionHistoryScreen(),
    'Log sheet': Scaffold(body: LogTransactionSheet()),
    'Onboarding': OnboardingScreen(),
    'Categories': CategoryManagementScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A32),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _screens.keys)
                  FilledButton(
                    onPressed: () => setState(() => _current = name),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: _current == name
                          ? Colors.amber
                          : Colors.white24,
                      foregroundColor: _current == name
                          ? Colors.black
                          : Colors.white,
                    ),
                    child: Text(name),
                  ),
                FilledButton(
                  onPressed: () => setState(() {
                    _brightness = _brightness == Brightness.light
                        ? Brightness.dark
                        : Brightness.light;
                  }),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _brightness == Brightness.light ? 'Dark' : 'Light',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _Frame(
                // Keyed on the screen name so switching actually rebuilds the
                // inner Navigator — without this it keeps serving its first
                // route and the frame never changes.
                key: ValueKey('$_current-$_brightness'),
                label: _current,
                brightness: _brightness,
                child: _screens[_current]!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    super.key,
    required this.label,
    required this.child,
    required this.brightness,
  });

  final String label;
  final Widget child;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 412,
        height: 760,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(412, 760), devicePixelRatio: 1),
          child: Theme(
            data: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            child: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => child),
            ),
          ),
        ),
      ),
    );
  }
}
