import 'package:flutter/material.dart';

const Map<String, IconData> _badgeIcons = {
  'flag': Icons.flag,
  'edit_note': Icons.edit_note,
  'auto_awesome': Icons.auto_awesome,
  'military_tech': Icons.military_tech,
  'local_fire_department': Icons.local_fire_department,
  'whatshot': Icons.whatshot,
  'emoji_events': Icons.emoji_events,
  'workspace_premium': Icons.workspace_premium,
  'star': Icons.star,
  'diamond': Icons.diamond,
  'flag_circle': Icons.flag_circle,
  'shield': Icons.shield,
  'savings': Icons.savings,
};

IconData badgeIcon(String iconId) => _badgeIcons[iconId] ?? Icons.emoji_events;
