import 'package:flutter/material.dart';

import '../../../core/utils/currency_catalog.dart';

class CurrencyDialog extends StatelessWidget {
  const CurrencyDialog({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Currency'),
      content: SizedBox(
        width: double.maxFinite,
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final currency in kSupportedCurrencies)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${currency.symbol} ${currency.name}'),
                  subtitle: Text(currency.code),
                  value: currency.code,
                ),
            ],
          ),
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
