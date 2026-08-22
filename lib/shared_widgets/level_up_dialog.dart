import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

Future<void> showLevelUpDialog(BuildContext context, int newLevel) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.xp,
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Level up!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'You\'re now level $newLevel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep going'),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    ),
  );
}
