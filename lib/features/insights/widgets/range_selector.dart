import 'package:flutter/material.dart';

import '../../../providers/insights_provider.dart';

class RangeSelector extends StatelessWidget {
  const RangeSelector({
    super.key,
    required this.range,
    required this.onChanged,
  });

  final InsightsRange range;
  final ValueChanged<InsightsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<InsightsRange>(
      segments: [
        for (final option in InsightsRange.values)
          ButtonSegment(value: option, label: Text(option.label)),
      ],
      selected: {range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
