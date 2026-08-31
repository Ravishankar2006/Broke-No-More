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
    String? currencyCode,
  }) async {
    final profile = UserProfile(
      id: kLocalProfileKey,
      name: name,
      avatarId: avatarId,
      joinDate: DateTime.now(),
      monthlyBudget: monthlyBudget,
      currencyCode: currencyCode,
    );
    await _box.put(kLocalProfileKey, profile);
    return profile;
  }

  /// Writes [profile] by the fixed local key. Uses `put` rather than
  /// `profile.save()` so it works for both the box-bound instance and a
  /// fresh `copyWith` value.
  Future<void> save(UserProfile profile) => _box.put(kLocalProfileKey, profile);

  /// Removes the profile entirely — Settings > Reset app, and the first
  /// step of a JSON backup restore before writing the restored one back.
  /// Previously there was no delete path at all.
  Future<void> delete() => _box.delete(kLocalProfileKey);
}
