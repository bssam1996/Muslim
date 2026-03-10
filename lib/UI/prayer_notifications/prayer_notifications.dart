import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import '../../utils/helper.dart' as helper;
import '../../utils/notification_service.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;

class PrayerNotificationsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;

  const PrayerNotificationsPageClass({super.key, required this.prefs});

  @override
  State<PrayerNotificationsPageClass> createState() =>
      _PrayerNotificationsPageClassState();
}

class _PrayerNotificationsPageClassState
    extends State<PrayerNotificationsPageClass> {
  static const detailsStyle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor);
  static const helperStyle =
      TextStyle(fontSize: 13, color: highlightedColor, height: 1.4);

  bool prayerNotification = false;
  List<String> adhanOptions = [];
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

  @override
  void initState() {
    super.initState();
    EasyLoading.showInfo("Prayer_Notifications_Loading_Tip".tr());
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
    final bool sharedPrayerNotification =
        await shared_preference_methods.checkExistenceData(
      widget.prefs,
      'prayerNotification',
    );
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
    Map<String, bool> prayerNotificationValues =
        await helper.getPrayerNotificationSettings(
      widget.prefs,
      prayerNotificationValue,
    );
    final List<String> adhanOptionValues = await _loadAdhanOptions();
    Map<String, String> prayerNotificationModeValues =
        await helper.getPrayerNotificationModes(widget.prefs);
    Map<String, String> prayerNotificationSoundValues =
        await helper.getPrayerNotificationSounds(widget.prefs);
    if (!prayerNotificationValue &&
        prayerNotificationValues.values.any((enabled) => enabled)) {
      prayerNotificationValues = {
        for (final prayerName in PRAYER_NOTIFICATION_NAMES) prayerName: false,
      };
      await _savePrayerNotifications(prayerNotificationValues);
    }
    if (prayerNotificationValue &&
        prayerNotificationValues.values.every((enabled) => !enabled)) {
      prayerNotificationValue = false;
      await shared_preference_methods.setBoolData(
        widget.prefs,
        'prayerNotification',
        false,
      );
    }
    prayerNotificationSoundValues = await _normalizePrayerSoundSelections(
      prayerNotificationModeValues,
      prayerNotificationSoundValues,
      adhanOptionValues,
    );

    if (!mounted) {
      EasyLoading.dismiss();
      return;
    }

    setState(() {
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
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> options = manifest
          .listAssets()
          .where(
            (assetPath) =>
                assetPath.startsWith('assets/adhan/') &&
                assetPath.toLowerCase().endsWith('.mp3'),
          )
          .toList()
        ..sort();
      return options;
    } catch (_) {
      return [];
    }
  }

  Future<bool> _savePrayerNotifications(Map<String, bool> values) async {
    bool result = true;
    for (final entry in values.entries) {
      final bool saved = await shared_preference_methods.setBoolData(
        widget.prefs,
        prayerNotificationPreferenceKey(entry.key),
        entry.value,
      );
      result = result && saved;
    }
    return result;
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

  String _adhanLabel(String assetPath) {
    final String fileName = assetPath.split('/').last;
    final String baseName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    return baseName.replaceAll('-', ' ');
  }

  Future<void> _changePrayerNotification(bool value) async {
    if (!Platform.isAndroid) {
      EasyLoading.showError(
        "Prayer_Notifications_Not_Supported".tr(),
        dismissOnTap: true,
      );
      return;
    }

    if (value) {
      final bool notificationGranted =
          await Permission.notification.request().isGranted;
      if (!notificationGranted) {
        EasyLoading.showError(
          "Unable to get notifications permission".tr(),
          dismissOnTap: true,
        );
        return;
      }

      final bool exactAlarmGranted =
          await NotificationService().requestExactAlarmPermissionIfNeeded();
      if (!exactAlarmGranted) {
        EasyLoading.showInfo(
          "Prayer_Notifications_Exact_Alarm_Info".tr(),
          dismissOnTap: true,
        );
      }
    } else {
      await NotificationService().clearAllNotifications();
    }

    final Map<String, bool> nextPrayerNotifications = {
      for (final prayerName in PRAYER_NOTIFICATION_NAMES) prayerName: value,
    };
    final bool mainSaved = await shared_preference_methods.setBoolData(
      widget.prefs,
      'prayerNotification',
      value,
    );
    final bool prayerSaved =
        await _savePrayerNotifications(nextPrayerNotifications);
    if (!mainSaved || !prayerSaved) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
    }
    await _updatePrayerNotifications();
  }

  Future<void> _changeSinglePrayerNotification(
    String prayerName,
    bool value,
  ) async {
    if (!prayerNotification) {
      return;
    }

    final Map<String, bool> nextPrayerNotifications =
        Map<String, bool>.from(prayerNotifications);
    nextPrayerNotifications[prayerName] = value;
    final bool hasEnabledPrayer =
        nextPrayerNotifications.values.any((enabled) => enabled);

    final bool prayerSaved = await shared_preference_methods.setBoolData(
      widget.prefs,
      prayerNotificationPreferenceKey(prayerName),
      value,
    );
    final bool mainSaved = await shared_preference_methods.setBoolData(
      widget.prefs,
      'prayerNotification',
      hasEnabledPrayer,
    );
    if (!prayerSaved || !mainSaved) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
      return;
    }

    if (!hasEnabledPrayer) {
      await NotificationService().clearAllNotifications();
    } else if (!value) {
      await NotificationService().clearNotification(
        PRAYER_NAMES.indexOf(prayerName),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      prayerNotification = hasEnabledPrayer;
      prayerNotifications = nextPrayerNotifications;
    });
  }

  Future<void> _changePrayerNotificationMode(
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

  Future<void> _changePrayerNotificationSound(
    String prayerName,
    String soundAssetPath,
  ) async {
    final Map<String, String> nextSounds = Map<String, String>.from(
      prayerNotificationSounds,
    );
    nextSounds[prayerName] = soundAssetPath;
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

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: settingsWidgetBGColor,
        border: Border.all(color: boxesBorderColor, width: 1),
      ),
      child: child,
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
        initialValue: value,
        iconEnabledColor: textColor,
        dropdownColor: settingsWidgetBGColor,
        style: detailsStyle,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textColor),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: boxesBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: highlightedColor),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrayerOptions(String prayerName) {
    final bool enabled = prayerNotifications[prayerName] ?? false;
    final String selectedMode = prayerNotificationModes[prayerName] ??
        prayerNotificationModeVibrationOnly;
    final String selectedSound = prayerNotificationSounds[prayerName] ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                prayerName.tr(),
                style: detailsStyle,
              ),
            ),
            Expanded(
              child: Switch(
                activeThumbColor: textColor,
                inactiveThumbColor: Colors.grey,
                value: enabled,
                onChanged: prayerNotification
                    ? (value) =>
                        _changeSinglePrayerNotification(prayerName, value)
                    : null,
              ),
            ),
          ],
        ),
        if (enabled) ...[
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
            _buildDropdownField(
              label: "Prayer_Notifications_Sound_Title".tr(),
              value:
                  selectedSound.isNotEmpty ? selectedSound : adhanOptions.first,
              items: adhanOptions
                  .map(
                    (assetPath) => DropdownMenuItem(
                      value: assetPath,
                      child: Text(_adhanLabel(assetPath)),
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
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Prayer_Notifications_Title".tr(),
          style: const TextStyle(color: textColor),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textColor),
      ),
      backgroundColor: thirdColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              interpolatedColor7,
              thirdColor,
              interpolatedColor1,
              interpolatedColor2,
              interpolatedColor3,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prayer_Notifications_Title".tr(),
                          style: const TextStyle(
                            color: textColor,
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
                  const Divider(
                    height: 20,
                    thickness: 5,
                    color: dividerColor,
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
                        Expanded(
                          child: Switch(
                            activeThumbColor: textColor,
                            inactiveThumbColor: Colors.grey,
                            value: prayerNotification,
                            onChanged: _changePrayerNotification,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 20,
                    thickness: 5,
                    color: dividerColor,
                  ),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prayer_Notifications_Prayers_Title".tr(),
                          style: const TextStyle(
                            color: textColor,
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
                        for (int i = 0;
                            i < PRAYER_NOTIFICATION_NAMES.length;
                            i++) ...[
                          _buildPrayerOptions(PRAYER_NOTIFICATION_NAMES[i]),
                          if (i != PRAYER_NOTIFICATION_NAMES.length - 1)
                            const Divider(
                              color: dividerColor,
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
