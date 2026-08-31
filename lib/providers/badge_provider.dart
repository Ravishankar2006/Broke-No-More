import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/badge_repository.dart';
import '../models/badge.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return BadgeRepository();
});

class BadgesNotifier extends Notifier<List<Badge>> {
  @override
  List<Badge> build() {
    return ref.watch(badgeRepositoryProvider).getAll();
  }

  void refresh() {
    state = ref.read(badgeRepositoryProvider).getAll();
  }
}

final badgesProvider = NotifierProvider<BadgesNotifier, List<Badge>>(
  BadgesNotifier.new,
);
