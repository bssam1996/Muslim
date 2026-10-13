import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'app_appearance.dart';
import 'app_theme.dart';

class AppearancePicker extends StatefulWidget {
  const AppearancePicker({super.key});
  @override
  State<AppearancePicker> createState() => _AppearancePickerState();
}

class _AppearancePickerState extends State<AppearancePicker> {
  bool _saving = false;

  Future<void> _select(AppAppearance appearance, ThemeMode? value) async {
    if (value == null || _saving) return;
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await appearance.setMode(value);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't save data".tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AppAppearanceScope.maybeOf(context);
    if (appearance == null) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    return Card(
      color: palette.panel,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Text(
                'Appearance_Title'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: appearance.mode,
              onChanged: (value) => _select(appearance, value),
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      key: ValueKey('appearance-${mode.name}'),
                      enabled: !_saving,
                      value: mode,
                      title: Text('Appearance_${mode.name}'.tr()),
                    ),
                ],
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
