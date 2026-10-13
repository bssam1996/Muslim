import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppNumberField extends StatelessWidget {
  const AppNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.minimum = -100,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;
  final int minimum;

  void _step(int change) {
    final next = (int.tryParse(controller.text) ?? 0) + change;
    if (next < minimum) return;
    controller.text = next.toString();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Number_Decrease'.tr(namedArgs: {'label': label}),
        onPressed: () => _step(-1),
        icon: const Icon(Icons.remove),
      ),
      Expanded(
        child: TextFormField(
          key: PageStorageKey('number_field_$label'),
          controller: controller,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            TextInputFormatter.withFunction(
              (oldValue, newValue) =>
                  RegExp(r'^-?[0-9]*$').hasMatch(newValue.text)
                  ? newValue
                  : oldValue,
            ),
          ],
          decoration: InputDecoration(labelText: label),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (text) {
            final value = int.tryParse(text ?? '');
            if (value == null || value < minimum) {
              return 'Number_Minimum'.tr(namedArgs: {'minimum': '$minimum'});
            }
            return null;
          },
          onChanged: (text) {
            final value = int.tryParse(text);
            if (value != null && value >= minimum) onChanged(value);
          },
        ),
      ),
      IconButton(
        tooltip: 'Number_Increase'.tr(namedArgs: {'label': label}),
        onPressed: () => _step(1),
        icon: const Icon(Icons.add),
      ),
    ],
  );
}
