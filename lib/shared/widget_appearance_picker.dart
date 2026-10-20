import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../utils/homewidget_utils.dart';
import 'app_theme.dart';

/// Stored in HomeWidget preferences so Android can read it without Flutter.
const widgetThemeModeKey = 'widget_theme_mode';

class WidgetAppearancePicker extends StatefulWidget {
  const WidgetAppearancePicker({super.key});

  @override
  State<WidgetAppearancePicker> createState() => _WidgetAppearancePickerState();
}

class _WidgetAppearancePickerState extends State<WidgetAppearancePicker> {
  ThemeMode _mode = ThemeMode.system;
  bool _busy = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await HomeWidget.getWidgetData<String>(widgetThemeModeKey);
      if (!mounted) return;
      setState(() {
        _mode = ThemeMode.values.firstWhere(
          (mode) => mode.name == saved,
          orElse: () => ThemeMode.system,
        );
        _loadFailed = false;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _busy = false;
      });
    }
  }

  Future<void> _select(ThemeMode? value) async {
    if (value == null || value == _mode || _busy) return;
    setState(() => _busy = true);
    String? feedback;
    try {
      final saved = await HomeWidget.saveWidgetData<String>(
        widgetThemeModeKey,
        value.name,
      );
      if (saved != true) throw StateError('Widget preference write failed');
      if (mounted) setState(() => _mode = value);
      if (!await refreshWidgetOnly(source: 'widget appearance')) {
        feedback = 'Settings_Saved_Update_Pending';
      }
    } catch (_) {
      feedback = 'Settings_Unable_To_Save';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (feedback != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppPalette.of(context).panel,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Widget_Appearance_Title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text('Widget_Appearance_Description'.tr()),
                ],
              ),
            ),
            if (_loadFailed)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _busy = true);
                        _load();
                      },
                child: Text('Widget_Appearance_Retry'.tr()),
              )
            else
              RadioGroup<ThemeMode>(
                groupValue: _mode,
                onChanged: _select,
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        key: ValueKey('widget-appearance-${mode.name}'),
                        enabled: !_busy,
                        value: mode,
                        title: Text('Appearance_${mode.name}'.tr()),
                      ),
                  ],
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
