import '../../utils/prayer_notification_status.dart';
import '../../utils/prayer_alert_options.dart';
import 'prayer_alert_options_editor.dart';
import 'dart:convert';
import 'package:muslim/shared/app_theme.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import '../../utils/helper.dart' as helper;
import '../../utils/notification_service.dart';
import '../../utils/prayer_data_repository.dart';
import '../../shared/retry_notice.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;

class PrayerNotificationsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;

  const PrayerNotificationsPageClass({
    super.key,
    required this.prefs,
    this.loadStatus,
    this.reconcile,
    this.requestPermissions,
    this.testNotification,
    this.stopAudio,
  });
  final Future<PrayerNotificationStatus> Function()? loadStatus;
  final Future<bool> Function()? reconcile;
  final Future<bool> Function()? requestPermissions;
  final Future<void> Function()? testNotification;
  final Future<void> Function()? stopAudio;

  @override
  State<PrayerNotificationsPageClass> createState() =>
      _PrayerNotificationsPageClassState();
}

class _PrayerNotificationsPageClassState
    extends State<PrayerNotificationsPageClass>
    with WidgetsBindingObserver {
  TextStyle get detailsStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppPalette.of(context).text,
  );
  TextStyle get helperStyle => TextStyle(
    fontSize: 13,
    color: AppPalette.of(context).accent,
    height: 1.4,
  );

  PrayerNotificationStatus? _status;
  bool _statusFailed = false;
  int _statusRequest = 0;
  bool get _supported =>
      widget.loadStatus != null || (!kIsWeb && Platform.isAndroid);
  bool _scheduleBusy = false;
  bool _stopAudioBusy = false;
  bool _scheduleFailed = false;
  bool prayerNotification = false;
  List<String> adhanOptions = [];
  Map<String, PrayerAlertOptions> alertOptions = {};
  Map<String, String> reminderSoundAssets = {};
  Map<String, bool> prayerNotifications = {
    for (final prayerName in PRAYER_NOTIFICATION_NAMES) prayerName: false,
  };
  Map<String, String> prayerNotificationModes = {
    for (final prayerName in PRAYER_NOTIFICATION_NAMES)
      prayerName: prayerNotificationModeVibrationOnly,
  };
  Map<String, String> prayerNotificationSounds = {
    for (final prayerName in PRAYER_NOTIFICATION_NAMES) prayerName: "",
  };
  final AudioPlayer _previewPlayer = AudioPlayer();
  late final StreamSubscription<void> _previewCompleteSubscription;
  String? _previewPrayerName;
  String? _previewSoundKey;
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readStatus());
    _previewCompleteSubscription = _previewPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewPlaying = false;
        _previewPrayerName = null;
        _previewSoundKey = null;
      });
    });

    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        _updatePrayerNotifications();
      });
    } catch (e) {
      if (kDebugMode) {
        EasyLoading.dismiss();
        print(e);
      }
    }
  }

  Future<void> _updatePrayerNotifications() async {
    final bool sharedPrayerNotification = await shared_preference_methods
        .checkExistenceData(widget.prefs, 'prayerNotification');
    bool prayerNotificationValue = false;

    if (sharedPrayerNotification) {
      prayerNotificationValue = await shared_preference_methods.getBoolData(
        widget.prefs,
        'prayerNotification',
      );
    } else {
      await shared_preference_methods.setBoolData(
        widget.prefs,
        'prayerNotification',
        prayerNotificationValue,
      );
    }
    Map<String, bool> prayerNotificationValues = await helper
        .getPrayerNotificationSettings(widget.prefs, true);
    final List<String> adhanOptionValues = await _loadAdhanOptions();
    Map<String, String> prayerNotificationModeValues = await helper
        .getPrayerNotificationModes(widget.prefs);
    Map<String, String> prayerNotificationSoundValues = await helper
        .getPrayerNotificationSounds(widget.prefs);
    prayerNotificationSoundValues = await _normalizePrayerSoundSelections(
      prayerNotificationModeValues,
      prayerNotificationSoundValues,
      adhanOptionValues,
    );

    if (!mounted) {
      EasyLoading.dismiss();
      return;
    }

    final prefs = await widget.prefs;
    setState(() {
      alertOptions = {
        for (final name in PRAYER_NOTIFICATION_NAMES)
          name: PrayerAlertOptions.read(prefs, name),
      };
      prayerNotification = prayerNotificationValue;
      adhanOptions = adhanOptionValues;
      prayerNotifications = prayerNotificationValues;
      prayerNotificationModes = prayerNotificationModeValues;
      prayerNotificationSounds = prayerNotificationSoundValues;
    });
    EasyLoading.dismiss();
  }

  Future<List<String>> _loadAdhanOptions() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      reminderSoundAssets = {
        for (final path in manifest.listAssets().where(
          (path) =>
              path.startsWith('assets/reminders/') &&
              path.toLowerCase().endsWith('.mp3'),
        ))
          androidRawResourceNameFromSoundKey(
            path.split('/').last.replaceAll('.mp3', ''),
          ): path,
      };
      final List<String> options =
          manifest
              .listAssets()
              .where(
                (assetPath) =>
                    assetPath.startsWith('assets/adhan/') &&
                    assetPath.toLowerCase().endsWith('.mp3'),
              )
              .map(adhanSoundKeyFromAssetPath)
              .toSet()
              .toList()
            ..sort();
      return options;
    } catch (_) {
      return [];
    }
  }

  Future<bool> _savePrayerNotificationModes(Map<String, String> values) async {
    bool result = true;
    for (final entry in values.entries) {
      final bool saved = await shared_preference_methods.setStringData(
        widget.prefs,
        prayerNotificationModePreferenceKey(entry.key),
        entry.value,
      );
      result = result && saved;
    }
    return result;
  }

  Future<bool> _savePrayerNotificationSounds(Map<String, String> values) async {
    bool result = true;
    for (final entry in values.entries) {
      final bool saved = await shared_preference_methods.setStringData(
        widget.prefs,
        prayerNotificationSoundPreferenceKey(entry.key),
        entry.value,
      );
      result = result && saved;
    }
    return result;
  }

  Future<Map<String, String>> _normalizePrayerSoundSelections(
    Map<String, String> modeValues,
    Map<String, String> soundValues,
    List<String> availableSounds,
  ) async {
    if (availableSounds.isEmpty) {
      return soundValues;
    }
    bool hasChanges = false;
    final Map<String, String> normalizedValues = Map<String, String>.from(
      soundValues,
    );
    for (final prayerName in PRAYER_NOTIFICATION_NAMES) {
      if (modeValues[prayerName] != prayerNotificationModeCustomSound) {
        continue;
      }
      final String selectedSound = normalizedValues[prayerName] ?? "";
      if (selectedSound.isEmpty || !availableSounds.contains(selectedSound)) {
        normalizedValues[prayerName] = availableSounds.first;
        hasChanges = true;
      }
    }
    if (hasChanges) {
      await _savePrayerNotificationSounds(normalizedValues);
    }
    return normalizedValues;
  }

  String _adhanLabel(String soundKey) {
    final String cleaned = soundKey.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return soundKey;
    }
    final List<String> parts = cleaned.split(RegExp(r'\s+'));
    return parts
        .map((part) {
          if (part.isEmpty) {
            return part;
          }
          final String lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  String _assetSourceFromSoundKey(String soundKey) {
    final String assetPath = adhanAssetPathFromSoundKey(soundKey);
    return assetPath.replaceFirst('assets/', '');
  }

  Future<void> _stopSoundPreview({bool updateState = true}) async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    if (!updateState || !mounted) {
      return;
    }
    setState(() {
      _isPreviewPlaying = false;
      _previewPrayerName = null;
      _previewSoundKey = null;
    });
  }

  Future<void> _toggleSoundPreview(
    String prayerName,
    String soundKey, {
    String? assetPath,
  }) async {
    if (soundKey.isEmpty) {
      return;
    }
    if (_isPreviewPlaying &&
        _previewPrayerName == prayerName &&
        _previewSoundKey == soundKey) {
      await _stopSoundPreview();
      return;
    }
    await _stopSoundPreview(updateState: false);
    try {
      await _previewPlayer.play(
        AssetSource(
          assetPath?.replaceFirst('assets/', '') ??
              _assetSourceFromSoundKey(soundKey),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreviewPlaying = true;
        _previewPrayerName = prayerName;
        _previewSoundKey = soundKey;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      _feedback('Audio_Preview_Error');
    }
  }

  Future<void> _performNotificationChange(
    Future<void> Function() change,
  ) async {
    if (_scheduleBusy || !mounted) return;
    setState(() {
      _scheduleBusy = true;
      _scheduleFailed = false;
    });
    try {
      await change();
      final success =
          await (widget.reconcile?.call() ??
              reconcileSavedPrayerNotifications());
      await _readStatus();
      if (mounted) setState(() => _scheduleFailed = !success);
    } catch (_) {
      if (mounted) setState(() => _scheduleFailed = true);
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _changePrayerNotification(bool value) =>
      _performNotificationChange(() => _persistPrayerNotification(value));
  Future<void> _changeSinglePrayerNotification(String name, bool value) =>
      _performNotificationChange(
        () => _persistSinglePrayerNotification(name, value),
      );
  Future<void> _changePrayerNotificationMode(String name, String mode) =>
      _performNotificationChange(
        () => _persistPrayerNotificationMode(name, mode),
      );
  Future<void> _changePrayerNotificationSound(String name, String sound) =>
      _performNotificationChange(
        () => _persistPrayerNotificationSound(name, sound),
      );

  Future<void> _changeAlertOptions(String name, Map<String, dynamic> changes) =>
      _performNotificationChange(() async {
        final prefs = await widget.prefs;
        final next = PrayerAlertOptions.fromJson({
          ...PrayerAlertOptions.read(prefs, name).toJson(),
          ...changes,
        });
        if (((changes.containsKey('forceSound') && next.forceSound) ||
                (changes.containsKey('volume') && next.volume != null)) &&
            widget.requestPermissions == null &&
            !await NotificationService()
                .requestExactAlarmPermissionIfNeeded()) {
          _feedback('Prayer_Adhan_Exact_Required');
          return;
        }
        if (!await prefs.setString(
          prayerAlertOptionsKey(name),
          jsonEncode(next.toJson()),
        )) {
          throw StateError('Save failed');
        }
        if (mounted) setState(() => alertOptions[name] = next);
      });

  Future<void> _previewReminder(String name, String resource) async {
    final asset = reminderSoundAssets[resource];
    if (asset == null) {
      final sound = adhanOptions
          .where((key) => androidRawResourceNameFromSoundKey(key) == resource)
          .firstOrNull;
      if (sound != null) await _toggleSoundPreview('reminder_$name', sound);
      return;
    }
    await _toggleSoundPreview('reminder_$name', resource, assetPath: asset);
  }

  Future<void> _persistPrayerNotification(bool value) async {
    if (!_supported) {
      _feedback('Prayer_Notifications_Not_Supported');
      return;
    }
    if (value) {
      final granted = widget.requestPermissions != null
          ? await widget.requestPermissions!()
          : await Permission.notification.request().isGranted;
      if (!granted) {
        _feedback('Unable to get notifications permission');
        return;
      }
      if (widget.requestPermissions == null &&
          !await NotificationService().requestExactAlarmPermissionIfNeeded()) {
        _feedback('Prayer_Notifications_Exact_Alarm_Info');
      }
    }
    final prefs = await widget.prefs;
    if (!await prefs.setBool('prayerNotification', value)) {
      throw StateError('Save failed');
    }
    await _updatePrayerNotifications();
  }

  Future<void> _persistSinglePrayerNotification(
    String prayerName,
    bool value,
  ) async {
    final prefs = await widget.prefs;
    if (!await prefs.setBool(
      prayerNotificationPreferenceKey(prayerName),
      value,
    )) {
      throw StateError('Save failed');
    }
    if (mounted) setState(() => prayerNotifications[prayerName] = value);
  }

  Future<void> _persistPrayerNotificationMode(
    String prayerName,
    String mode,
  ) async {
    final Map<String, String> nextModes = Map<String, String>.from(
      prayerNotificationModes,
    );
    final Map<String, String> nextSounds = Map<String, String>.from(
      prayerNotificationSounds,
    );
    nextModes[prayerName] = mode;
    if (mode != prayerNotificationModeCustomSound &&
        _isPreviewPlaying &&
        _previewPrayerName == prayerName) {
      await _stopSoundPreview();
    }
    if (mode == prayerNotificationModeCustomSound &&
        (nextSounds[prayerName] == null ||
            nextSounds[prayerName] == '' ||
            !adhanOptions.contains(nextSounds[prayerName])) &&
        adhanOptions.isNotEmpty) {
      nextSounds[prayerName] = adhanOptions.first;
    }

    final bool modeSaved = await _savePrayerNotificationModes(nextModes);
    final bool soundSaved = await _savePrayerNotificationSounds(nextSounds);
    if (!modeSaved || !soundSaved) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      prayerNotificationModes = nextModes;
      prayerNotificationSounds = nextSounds;
    });
  }

  Future<void> _persistPrayerNotificationSound(
    String prayerName,
    String soundKey,
  ) async {
    if (_isPreviewPlaying && _previewPrayerName == prayerName) {
      await _stopSoundPreview();
    }
    final Map<String, String> nextSounds = Map<String, String>.from(
      prayerNotificationSounds,
    );
    nextSounds[prayerName] = soundKey;
    final bool soundSaved = await _savePrayerNotificationSounds(nextSounds);
    if (!soundSaved) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      prayerNotificationSounds = nextSounds;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_readStatus());
  }

  void _feedback(String key) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(key.tr())));
    }
  }

  Future<void> _readStatus() async {
    final request = ++_statusRequest;
    try {
      final value =
          await (widget.loadStatus?.call() ?? readPrayerNotificationStatus())
              .timeout(const Duration(seconds: 15));
      if (mounted && request == _statusRequest) {
        setState(() {
          _status = value;
          _statusFailed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _statusRequest) {
        setState(() => _statusFailed = true);
      }
    }
  }

  Future<void> _sendTest() async {
    if (_scheduleBusy) return;
    setState(() => _scheduleBusy = true);
    try {
      await (widget.testNotification?.call() ??
          NotificationService().showTestNotification(
            'App_Title'.tr(),
            'Notifications_Test_Body'.tr(),
          ));
      _feedback('Notifications_Test_Requested');
    } catch (_) {
      _feedback('Notifications_Test_Failed');
    } finally {
      if (mounted) setState(() => _scheduleBusy = false);
    }
  }

  Future<void> _stopPrayerAudio() async {
    if (_stopAudioBusy) return;
    setState(() => _stopAudioBusy = true);
    try {
      await (widget.stopAudio?.call() ??
          NotificationService().stopPrayerAudio());
      await _stopSoundPreview();
    } catch (_) {
      _feedback('Prayer_Audio_Stop_Error');
    } finally {
      if (mounted) setState(() => _stopAudioBusy = false);
    }
  }

  String _permission(bool? granted) =>
      (granted == true
              ? 'Notifications_Granted'
              : granted == false
              ? 'Notifications_Denied'
              : 'Notifications_Unknown')
          .tr();

  Widget _buildStatusCard() {
    final status = _status;
    final alarm = status?.nextAlarm;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Notifications_Status'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (status?.supported == false)
            Text('Prayer_Notifications_Not_Supported'.tr())
          else ...[
            Text(
              '${'Notifications_Permission'.tr()}: ${_permission(status?.notifications)}',
            ),
            Text(
              '${'Notifications_Exact_Permission'.tr()}: ${_permission(status?.exactAlarms)}',
            ),
            if (status?.exactAlarms == false)
              Text(
                'Prayer_Notifications_Exact_Alarm_Info'.tr(),
                style: helperStyle,
              ),
            if (status != null)
              Text(
                alarm == null
                    ? 'Notifications_None_Scheduled'.tr()
                    : (alarm.isReminder
                              ? 'Prayer_Reminder_Next_Scheduled'
                              : 'Notifications_Next_Scheduled')
                          .tr(
                            namedArgs: {
                              'prayer': alarm.name.tr(),
                              'date': DateFormat.MMMd(
                                context.locale.toString(),
                              ).format(alarm.time),
                              'time': DateFormat(
                                status.use24Hour ? 'HH:mm' : 'h:mm a',
                              ).format(alarm.time),
                            },
                          ),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('stop_prayer_audio'),
                  onPressed: _stopAudioBusy || !_supported
                      ? null
                      : _stopPrayerAudio,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text('Prayer_Audio_Stop'.tr()),
                ),
                TextButton.icon(
                  key: const ValueKey('test_notification'),
                  onPressed: _scheduleBusy || status?.notifications != true
                      ? null
                      : _sendTest,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text('Notifications_Test'.tr()),
                ),
                if (status?.exactAlarms == false)
                  TextButton(
                    onPressed: _scheduleBusy
                        ? null
                        : () => _performNotificationChange(() async {
                            await NotificationService()
                                .requestExactAlarmPermissionIfNeeded();
                          }),
                    child: Text('Notifications_Enable_Exact'.tr()),
                  ),
              ],
            ),
            Text('Notifications_Test_Help'.tr(), style: helperStyle),
          ],
          if (_statusFailed)
            RetryNotice(
              message: 'Notifications_Status_Error'.tr(),
              onRetry: _readStatus,
            ),
          TextButton.icon(
            onPressed: _readStatus,
            icon: const Icon(Icons.refresh),
            label: Text('Reload'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Material(
      color: AppPalette.of(context).panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppPalette.of(context).border),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        itemHeight: null,
        isDense: false,
        initialValue: value,
        iconEnabledColor: AppPalette.of(context).text,
        dropdownColor: AppPalette.of(context).panel,
        style: detailsStyle,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppPalette.of(context).text),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppPalette.of(context).border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppPalette.of(context).accent),
          ),
        ),
        items: items,
        onChanged: _scheduleBusy ? null : onChanged,
      ),
    );
  }

  Widget _buildPrayerOptions(String prayerName) {
    final bool enabled = prayerNotifications[prayerName] ?? false;
    final String selectedMode =
        prayerNotificationModes[prayerName] ??
        prayerNotificationModeVibrationOnly;
    final String selectedSound = prayerNotificationSounds[prayerName] ?? "";
    final String fallbackSound = adhanOptions.isNotEmpty
        ? adhanOptions.first
        : "";
    final String resolvedSound = adhanOptions.contains(selectedSound)
        ? selectedSound
        : fallbackSound;
    final bool isPreviewingSound =
        _isPreviewPlaying &&
        _previewPrayerName == prayerName &&
        _previewSoundKey == resolvedSound;
    return ExpansionTile(
      key: PageStorageKey('prayer_options_$prayerName'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(prayerName.tr(), style: detailsStyle),
      subtitle: Text(
        selectedMode == prayerNotificationModeCustomSound
            ? _adhanLabel(resolvedSound)
            : 'Prayer_Notifications_Mode_Vibration_Only'.tr(),
        style: helperStyle,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: ValueKey('prayer_switch_$prayerName'),
            value: enabled,
            onChanged: _scheduleBusy || !_supported
                ? null
                : (value) => _changeSinglePrayerNotification(prayerName, value),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        _buildDropdownField(
          label: "Prayer_Notifications_Mode_Title".tr(),
          value: selectedMode,
          items: [
            DropdownMenuItem(
              value: prayerNotificationModeVibrationOnly,
              child: Text("Prayer_Notifications_Mode_Vibration_Only".tr()),
            ),
            DropdownMenuItem(
              value: prayerNotificationModeCustomSound,
              child: Text("Prayer_Notifications_Mode_Custom_Sound".tr()),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            _changePrayerNotificationMode(prayerName, value);
          },
        ),
        if (selectedMode == prayerNotificationModeCustomSound &&
            adhanOptions.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: "Prayer_Notifications_Sound_Title".tr(),
                  value: resolvedSound,
                  items: adhanOptions
                      .map(
                        (soundKey) => DropdownMenuItem(
                          value: soundKey,
                          child: Text(_adhanLabel(soundKey)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _changePrayerNotificationSound(prayerName, value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: IconButton(
                  tooltip: (isPreviewingSound ? 'Audio_Stop' : 'Audio_Preview')
                      .tr(),
                  icon: Icon(
                    isPreviewingSound ? Icons.stop : Icons.play_arrow,
                    color: AppPalette.of(context).text,
                  ),
                  onPressed: resolvedSound.isEmpty
                      ? null
                      : () => _toggleSoundPreview(prayerName, resolvedSound),
                ),
              ),
            ],
          ),
        PrayerAlertOptionsEditor(
          options: alertOptions[prayerName] ?? const PrayerAlertOptions(),
          adhanEnabled: selectedMode == prayerNotificationModeCustomSound,
          enabled: !_scheduleBusy && _supported,
          sounds: {
            for (final sound in adhanOptions)
              androidRawResourceNameFromSoundKey(sound): _adhanLabel(sound),
            for (final sound in reminderSoundAssets.keys)
              sound: _adhanLabel(sound),
          },
          onChanged: (changes) => _changeAlertOptions(prayerName, changes),
          onPreview: (sound) => _previewReminder(prayerName, sound),
          isPreviewPlaying:
              _isPreviewPlaying && _previewPrayerName == 'reminder_$prayerName',
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previewCompleteSubscription.cancel();
    unawaited(_previewPlayer.stop());
    unawaited(_previewPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Prayer_Notifications_Title".tr(),
          style: TextStyle(color: AppPalette.of(context).text),
        ),
        backgroundColor: AppPalette.of(context).canvas,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
      ),
      backgroundColor: AppPalette.of(context).panel,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.of(context).canvas,
              AppPalette.of(context).panel,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!prayerNotification)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Notifications_Master_Paused'.tr()),
                    ),
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  if (_scheduleBusy)
                    LinearProgressIndicator(
                      color: AppPalette.of(context).accent,
                    ),
                  if (_scheduleFailed)
                    RetryNotice(
                      message: 'Prayer_Notifications_Refresh_Error'.tr(),
                      onRetry: () => _performNotificationChange(() async {}),
                    ),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prayer_Notifications_Title".tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Prayer_Notifications_Desc".tr(),
                          style: helperStyle,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 20,
                    thickness: 5,
                    color: AppPalette.of(context).border,
                  ),
                  _buildCard(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Prayer_Notifications_Enable_Title".tr(),
                                style: detailsStyle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Prayer_Notifications_Enable_Desc".tr(),
                                style: helperStyle,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Switch(
                            activeThumbColor: AppPalette.of(context).text,
                            inactiveThumbColor: Colors.grey,
                            value: prayerNotification,
                            onChanged: _scheduleBusy || !_supported
                                ? null
                                : _changePrayerNotification,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 20,
                    thickness: 5,
                    color: AppPalette.of(context).border,
                  ),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prayer_Notifications_Prayers_Title".tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Prayer_Notifications_Prayers_Desc".tr(),
                          style: helperStyle,
                        ),
                        const SizedBox(height: 8),
                        for (
                          int i = 0;
                          i < PRAYER_NOTIFICATION_NAMES.length;
                          i++
                        ) ...[
                          _buildPrayerOptions(PRAYER_NOTIFICATION_NAMES[i]),
                          if (i != PRAYER_NOTIFICATION_NAMES.length - 1)
                            Divider(
                              color: AppPalette.of(context).border,
                              height: 20,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
