import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/currency_catalog.dart';
import '../data/profile_repository.dart';
import '../models/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    return ref.watch(profileRepositoryProvider).current;
  }

  Future<UserProfile> createProfile({
    required String name,
    required String avatarId,
    double? monthlyBudget,
    String? currencyCode,
  }) async {
    final profile = await ref
        .read(profileRepositoryProvider)
        .create(
          name: name,
          avatarId: avatarId,
          monthlyBudget: monthlyBudget,
          currencyCode: currencyCode,
        );
    state = profile;
    return profile;
  }

  /// Called by the XP engine orchestrator after it persists an updated
  /// profile, so dependent screens (Home/Profile/Quests) rebuild reactively.
  void setProfile(UserProfile profile) {
    state = profile;
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

/// Whether a profile exists — used for onboarding-vs-home routing at the
/// `MaterialApp` root. Selecting this boolean instead of watching
/// [profileProvider] directly means the root widget only rebuilds when
/// onboarding completes, not on every XP/streak/quest change that produces a
/// new profile object.
final hasProfileProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider.select((profile) => profile != null));
});

/// The active currency code, defaulting for the pre-profile (onboarding)
/// window rather than exposing null to every call site.
final currentCurrencyCodeProvider = Provider<String>((ref) {
  return ref.watch(
        profileProvider.select((profile) => profile?.currencyCode),
      ) ??
      kDefaultCurrencyCode;
});
