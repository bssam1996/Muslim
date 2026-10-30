import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/prayer_alert_options.dart';

class PrayerAlertOptionsEditor extends StatefulWidget {
  const PrayerAlertOptionsEditor({
    super.key,
    required this.options,
    required this.adhanEnabled,
    required this.enabled,
    required this.sounds,
    required this.onChanged,
    required this.onPreview,
    this.isPreviewPlaying = false,
  });

  final PrayerAlertOptions options;
  final bool adhanEnabled;
  final bool enabled;
  final Map<String, String> sounds;
  final Future<void> Function(Map<String, dynamic>) onChanged;
  final Future<void> Function(String) onPreview;
  final bool isPreviewPlaying;

  @override
  State<PrayerAlertOptionsEditor> createState() =>
      _PrayerAlertOptionsEditorState();
}

class _PrayerAlertOptionsEditorState extends State<PrayerAlertOptionsEditor> {
  double? _dragVolume;
  int _fieldRevision = 0;

  Future<void> _customMinutes() async {
    var input = '${widget.options.reminderMinutes}';
    final form = GlobalKey<FormState>();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prayer_Reminder_Minutes'.tr()),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('reminder_custom_minutes'),
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              helperText: 'Prayer_Reminder_Minutes_Help'.tr(),
            ),
            validator: (value) {
              final minutes = int.tryParse(value ?? '');
              return minutes == null || minutes < 1 || minutes > 180
                  ? 'Prayer_Reminder_Minutes_Help'.tr()
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Prayer_Alert_Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
            child: Text('Prayer_Alert_Save'.tr()),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _fieldRevision++);
    if (result != null) {
      await widget.onChanged({'reminderMinutes': result});
    }
  }

  Future<void> _customText() async {
    final options = widget.options;
    var input =
        [
          reminderPrepareText,
          reminderPreviousText,
        ].contains(options.reminderText)
        ? ''
        : options.reminderText;
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Prayer_Reminder_Custom_Text'.tr()),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('reminder_custom_text'),
            initialValue: input,
            onChanged: (value) => input = value,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Prayer_Reminder_Text_Required'.tr()
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Prayer_Alert_Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, input.trim());
              }
            },
            child: Text('Prayer_Alert_Save'.tr()),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _fieldRevision++);
    if (result != null) {
      await widget.onChanged({'reminderText': result});
    }
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> change,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value:$_fieldRevision'),
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        decoration: InputDecoration(
          labelText: label.tr(),
          border: const OutlineInputBorder(),
        ),
        items: items.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: widget.enabled ? change : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final minutes = options.reminderMinutes;
    final presetText = [
      reminderPrepareText,
      reminderPreviousText,
    ].contains(options.reminderText);
    final soundItems = {
      'system': 'Prayer_Reminder_System_Sound'.tr(),
      'silent': 'Prayer_Reminder_Silent'.tr(),
      ...widget.sounds,
    };
    final sound = soundItems.containsKey(options.reminderSound)
        ? options.reminderSound
        : 'system';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.adhanEnabled ||
            options.reminderEnabled && sound != 'silent') ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Prayer_Adhan_Force'.tr()),
            subtitle: Text('Prayer_Adhan_Force_Help'.tr()),
            value: options.forceSound,
            onChanged: widget.enabled
                ? (value) => widget.onChanged({'forceSound': value})
                : null,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Prayer_Adhan_Volume'.tr()),
            subtitle: Text('Prayer_Adhan_Volume_Help'.tr()),
            value: options.volume != null,
            onChanged: widget.enabled
                ? (value) => widget.onChanged({'volume': value ? 0.8 : null})
                : null,
          ),
          if (options.volume != null) ...[
            Text(
              'Prayer_Adhan_Volume_Value'.tr(
                namedArgs: {
                  'volume':
                      '${((_dragVolume ?? options.volume!) * 100).round()}',
                },
              ),
            ),
            Slider(
              value: _dragVolume ?? options.volume!,
              divisions: 20,
              label: '${((_dragVolume ?? options.volume!) * 100).round()}%',
              onChanged: widget.enabled
                  ? (value) => setState(() => _dragVolume = value)
                  : null,
              onChangeEnd: widget.enabled
                  ? (value) async {
                      await widget.onChanged({'volume': value});
                      if (mounted) setState(() => _dragVolume = null);
                    }
                  : null,
            ),
          ],
          if (options.forceSound || options.volume != null)
            Text(
              'Prayer_Adhan_Exact_Required'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Prayer_Reminder_Enable'.tr()),
          subtitle: Text('Prayer_Reminder_Enable_Help'.tr()),
          value: options.reminderEnabled,
          onChanged: widget.enabled
              ? (value) => widget.onChanged({'reminderEnabled': value})
              : null,
        ),
        if (options.reminderEnabled) ...[
          _dropdown(
            label: 'Prayer_Reminder_Minutes',
            value: reminderMinutePresets.contains(minutes)
                ? '$minutes'
                : 'custom',
            items: {
              for (final value in reminderMinutePresets)
                '$value': 'Prayer_Reminder_Minutes_Before'.tr(
                  namedArgs: {'minutes': '$value'},
                ),
              'custom': reminderMinutePresets.contains(minutes)
                  ? 'Prayer_Reminder_Custom'.tr()
                  : 'Prayer_Reminder_Minutes_Before'.tr(
                      namedArgs: {'minutes': '$minutes'},
                    ),
            },
            change: (value) {
              if (value == 'custom') {
                _customMinutes();
              } else if (value != null) {
                widget.onChanged({'reminderMinutes': int.parse(value)});
              }
            },
          ),
          if (!reminderMinutePresets.contains(minutes))
            TextButton(
              onPressed: widget.enabled ? _customMinutes : null,
              child: Text('Prayer_Reminder_Edit_Minutes'.tr()),
            ),
          _dropdown(
            label: 'Prayer_Reminder_Message',
            value: presetText ? options.reminderText : 'custom',
            items: {
              reminderPrepareText: 'Prayer_Reminder_Prepare_Label'.tr(),
              reminderPreviousText: 'Prayer_Reminder_Previous_Label'.tr(),
              'custom': 'Prayer_Reminder_Custom_Text'.tr(),
            },
            change: (value) {
              if (value == 'custom') {
                _customText();
              } else if (value != null) {
                widget.onChanged({'reminderText': value});
              }
            },
          ),
          if (!presetText) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(options.reminderText),
            ),
            TextButton(
              onPressed: widget.enabled ? _customText : null,
              child: Text('Prayer_Reminder_Edit_Text'.tr()),
            ),
          ],
          _dropdown(
            label: 'Prayer_Reminder_Sound',
            value: sound,
            items: soundItems,
            change: (value) {
              if (value != null) widget.onChanged({'reminderSound': value});
            },
          ),
          if (widget.sounds.containsKey(sound))
            TextButton.icon(
              onPressed: widget.enabled ? () => widget.onPreview(sound) : null,
              icon: Icon(
                widget.isPreviewPlaying ? Icons.stop : Icons.play_arrow,
              ),
              label: Text(
                (widget.isPreviewPlaying ? 'Audio_Stop' : 'Audio_Preview').tr(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Prayer_Reminder_Sound_Help'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}
