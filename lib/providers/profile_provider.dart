import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) async {
    final profile = await ref.read(profileRepositoryProvider).create(
          name: name,
          avatarId: avatarId,
          monthlyBudget: monthlyBudget,
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

final profileProvider =
    NotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);
