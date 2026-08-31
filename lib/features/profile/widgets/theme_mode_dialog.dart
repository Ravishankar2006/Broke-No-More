import 'package:flutter/material.dart';

String themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class ThemeModeDialog extends StatelessWidget {
  const ThemeModeDialog({super.key, required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Appearance'),
      content: RadioGroup<ThemeMode>(
        groupValue: current,
        onChanged: (value) => Navigator.of(context).pop(value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                contentPadding: EdgeInsets.zero,
                title: Text(themeModeLabel(mode)),
                value: mode,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
