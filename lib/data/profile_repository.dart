import 'package:hive/hive.dart';

import '../core/database/hive_boxes.dart';
import '../models/user_profile.dart';

/// Single local profile per device — key is fixed since there's no
/// multi-user/auth in v1.
const String kLocalProfileKey = 'local';

class ProfileRepository {
  Box<UserProfile> get _box => Hive.box<UserProfile>(HiveBoxes.profile);

  UserProfile? get current => _box.get(kLocalProfileKey);

  bool get hasProfile => _box.containsKey(kLocalProfileKey);

  Future<UserProfile> create({
    required String name,
    required String avatarId,
    double? monthlyBudget,
  }) async {
    final profile = UserProfile(
      id: kLocalProfileKey,
      name: name,
      avatarId: avatarId,
      joinDate: DateTime.now(),
      monthlyBudget: monthlyBudget,
    );
    await _box.put(kLocalProfileKey, profile);
    return profile;
  }

  /// Writes [profile] by the fixed local key. Uses `put` rather than
  /// `profile.save()` so it works for both the box-bound instance and a
  /// fresh `copyWith` value.
  Future<void> save(UserProfile profile) => _box.put(kLocalProfileKey, profile);
}
