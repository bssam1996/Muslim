import 'dart:async';
import 'dart:io' show Platform;
import '../../utils/serial_task_queue.dart';
import '../../utils/prayer_data_repository.dart';
import '../../utils/prayer_schedule.dart';
import '../prayer_notifications/prayer_notifications.dart';
import 'package:muslim/shared/app_theme.dart';
import 'package:muslim/shared/appearance_picker.dart';
import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/shared/number_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;
import '../../utils/helper.dart' as helper;
import '../../utils/api_utils.dart' as api_utils;
import '../../utils/prayer_location_utils.dart';

class SettingsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;
  final bool openLocation;
  const SettingsPageClass({
    Key? key,
    required this.prefs,
    this.openLocation = false,
  }) : super(key: key);

  @override
  State<SettingsPageClass> createState() => _SettingsPageClassState();
}

class _SettingsPageClassState extends State<SettingsPageClass> {
  TextStyle get detailsStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppPalette.of(context).text,
  );
  final _saves = SerialTaskQueue();
  String? _saveFeedback;
  int _saveRevision = 0;
  PrayerDay? _previewDay;
  Map<String, int> _previewOffsets = {};
  bool is24 = true;
  bool _hasSavedLocation = false;
  bool _didPromptForInitialLocation = false;
  String locationDisplayName = "";
  String selectedMethod = "Default";
  String selectedSchool = "Shafi (Standard)";
  String selectedlocale = "";
  String selectedCalendarMethod = "High Judicial Council of Saudi Arabia";
  TextEditingController adjustmentsController = TextEditingController();
  final Map<String, TextEditingController> tuneControllers = {
    for (final prayerName in PRAYER_NAMES) prayerName: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();

    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        _updateSettings();
      });
    } catch (e) {
      if (kDebugMode) {
        EasyLoading.dismiss();
        print(e);
      }
    }
  }

  @override
  void dispose() {
    adjustmentsController.dispose();
    for (final controller in tuneControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _updateSettings() async {
    if (!mounted) return;
    // 24 System
    var shared24Exists = await shared_preference_methods.checkExistenceData(
      widget.prefs,
      '24system',
    );
    var shared24 = true;
    if (shared24Exists) {
      var shared24Setting = await shared_preference_methods.getBoolData(
        widget.prefs,
        '24system',
      );
      shared24 = shared24Setting;
    } else {
      await shared_preference_methods.setBoolData(
        widget.prefs,
        '24system',
        shared24,
      );
    }
    var location = await shared_preference_methods.getStringData(
      widget.prefs,
      'location',
      true,
    );
    if (location != null) {
      locationDisplayName = helper.getAddressLocation(location);
    }
    _hasSavedLocation = location != null;
    var method = await shared_preference_methods.getStringData(
      widget.prefs,
      'method',
      false,
    );
    if (method != null) {
      selectedMethod = method;
    }
    var school = await shared_preference_methods.getStringData(
      widget.prefs,
      'school',
      false,
    );
    if (school != null) {
      selectedSchool = school;
    }
    var calendarMethod = await shared_preference_methods.getStringData(
      widget.prefs,
      'calendarMethod',
      false,
    );
    if (calendarMethod != null) {
      selectedCalendarMethod = calendarMethod;
    }
    var adjustment = await shared_preference_methods.getIntegerData(
      widget.prefs,
      'adjustment',
      0,
    );
    if (!mounted) return;
    adjustmentsController.text = adjustment.toString();
    final Map<String, int> tuneSettings = await helper
        .getPrayerTimeTuneSettings(widget.prefs);
    if (!mounted) return;
    for (final prayerName in PRAYER_NAMES) {
      tuneControllers[prayerName]?.text = (tuneSettings[prayerName] ?? 0)
          .toString();
    }
    setState(() {
      is24 = shared24;
    });

    if (context.locale.toString() == "ar_EG") {
      selectedlocale = "العربية";
    } else if (context.locale.toString() == "en_US") {
      selectedlocale = "English";
    }
    EasyLoading.dismiss();
    unawaited(_loadPreview());
    if ((!_hasSavedLocation || widget.openLocation) &&
        !_didPromptForInitialLocation) {
      _didPromptForInitialLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLocationPicker();
      });
    }
  }

  void _change24HourSystem(value) =>
      unawaited(_saveSetting('24system', value as bool));

  Future<void> _loadPreview() async {
    try {
      final window = await loadSavedPrayerWindow(cacheOnly: true);
      final offsets = await helper.getPrayerTimeTuneSettings(widget.prefs);
      if (!mounted) return;
      setState(() {
        _previewDay = window.days
            .where((day) => day.date == window.date)
            .firstOrNull;
        _previewOffsets = offsets;
      });
    } catch (_) {
      // An unavailable preview does not prevent changing settings.
    }
  }

  Future<bool> _saveSetting(
    String key,
    Object value, {
    bool prayerData = true,
  }) {
    final revision = ++_saveRevision;
    if (mounted) setState(() => _saveFeedback = 'Settings_Saving_Inline');
    return _saves.run(() async {
      try {
        final prefs = await widget.prefs;
        final saved = switch (value) {
          String text => await prefs.setString(key, text),
          int number => await prefs.setInt(key, number),
          bool enabled => await prefs.setBool(key, enabled),
          _ => false,
        };
        if (!saved) throw StateError('Preference write failed');
        if (prayerData && key != '24system') {
          await helper.invalidateTodayCachedData(widget.prefs);
        }
        if (mounted) {
          setState(() {
            if (key == 'method') selectedMethod = value as String;
            if (key == 'school') selectedSchool = value as String;
            if (key == 'calendarMethod') {
              selectedCalendarMethod = value as String;
            }
            if (key == '24system') is24 = value as bool;
            if (key == 'location' || key == 'method' || key == 'school') {
              _previewDay = null;
            }
            if (revision == _saveRevision) {
              _saveFeedback = 'Settings_Success_Save';
            }
          });
        }
        if (prayerData) unawaited(_refreshPrayerSettings(revision));
        return true;
      } catch (_) {
        if (mounted && revision == _saveRevision) {
          setState(() => _saveFeedback = 'Settings_Unable_To_Save');
        }
        return false;
      }
    });
  }

  Future<void> _refreshPrayerSettings(int revision) async {
    try {
      final updated = await refreshSavedPrayerConfiguration();
      if (!mounted || revision != _saveRevision) return;
      if (!updated) {
        setState(() => _saveFeedback = 'Settings_Saved_Update_Pending');
      }
      await _loadPreview();
    } catch (_) {
      if (mounted && revision == _saveRevision) {
        setState(() => _saveFeedback = 'Settings_Saved_Update_Pending');
      }
    }
  }

  PopupProps<String> _settingsPopupProps({bool showSearchBox = true}) {
    return PopupProps.menu(
      showSearchBox: showSearchBox,
      showSelectedItems: true,
      fit: FlexFit.loose,
      constraints: const BoxConstraints(maxHeight: 360),
      menuProps: MenuProps(
        backgroundColor: AppPalette.of(context).panel,
        surfaceTintColor: AppPalette.of(context).panel,
        elevation: 12,
        shadowColor: Colors.black54,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      searchFieldProps: TextFieldProps(
        style: TextStyle(color: AppPalette.of(context).text),
        cursorColor: AppPalette.of(context).accent,
        decoration: InputDecoration(
          hintText: "Settings_Dropdown_Search".tr(),
          hintStyle: TextStyle(color: AppPalette.of(context).accent),
          prefixIcon: Icon(Icons.search, color: AppPalette.of(context).accent),
          filled: true,
          fillColor: AppPalette.of(context).canvas,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppPalette.of(context).border),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppPalette.of(context).accent,
              width: 1.5,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      itemBuilder: _buildSettingsDropdownItem,
      emptyBuilder: (BuildContext context, String searchEntry) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "Settings_Dropdown_No_Results".tr(),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.of(context).accent),
        ),
      ),
    );
  }

  DropDownDecoratorProps _settingsDropdownDecorator({
    required String label,
    required String helperText,
  }) {
    return DropDownDecoratorProps(
      baseStyle: TextStyle(
        color: AppPalette.of(context).text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppPalette.of(context).accent),
        helperText: helperText,
        helperStyle: TextStyle(color: AppPalette.of(context).accent),
        suffixIconColor: AppPalette.of(context).accent,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.of(context).border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppPalette.of(context).accent,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsDropdownItem(
    BuildContext context,
    String item,
    bool isDisabled,
    bool isSelected,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Material(
      color: isSelected
          ? AppPalette.of(context).accentSurface
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(
          color: isSelected
              ? AppPalette.of(context).accent
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        title: Text(
          item,
          style: TextStyle(
            color: isDisabled
                ? AppPalette.of(context).muted
                : AppPalette.of(context).text,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check, color: AppPalette.of(context).accent)
            : null,
      ),
    ),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    key: ValueKey('settings_section_$title'),
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _dropdown(
    String title,
    String description,
    List<String> values,
    String selected,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownSearch<String>(
      popupProps: _settingsPopupProps(showSearchBox: values.length > 3),
      items: (filter, infiniteScrollProps) => values,
      decoratorProps: _settingsDropdownDecorator(
        label: title.tr(),
        helperText: description.tr(),
      ),
      selectedItem: selected,
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Settings_Title'.tr())),
    body: SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey('settings_scroll'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saveFeedback != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _saveFeedback!.tr(),
                    key: const ValueKey('settings_save_feedback'),
                    style: TextStyle(color: AppPalette.of(context).muted),
                  ),
                ),
              ),
            _section('Settings_Location_Title', [_buildLocationSelector()]),
            _section('Settings_Appearance_Section', [
              const AppearancePicker(),
              const SizedBox(height: 12),
              _dropdown(
                'Settings_Language_Title',
                'Settings_Language_Desc',
                const ['English', 'العربية'],
                selectedlocale,
                _changelanguage,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Settings_Use24Hour'.tr()),
                value: is24,
                onChanged: _change24HourSystem,
              ),
            ]),
            _section('Settings_Prayer_Section', [
              _dropdown(
                'Settings_Method',
                'Settings_Method_Desc',
                authorities.keys.toList(),
                selectedMethod,
                saveMethodParameter,
              ),
              _dropdown(
                'Settings_School',
                'Settings_School_Desc',
                schools.keys.toList(),
                selectedSchool,
                saveSchoolParameter,
              ),
              _dropdown(
                'Settings_Calendar_Methods',
                'Settings_Calendar_Methods_Desc',
                CalendarMethods.keys.toList(),
                selectedCalendarMethod,
                saveCalendarMethodParameter,
              ),
              if (selectedCalendarMethod == 'MATHEMATICAL')
                AppNumberField(
                  controller: adjustmentsController,
                  label: 'Settings_Adj_Hij_Desc'.tr(),
                  onChanged: saveAdjustmentValue,
                ),
              ExpansionTile(
                key: const PageStorageKey('settings_advanced'),
                tilePadding: EdgeInsets.zero,
                title: Text('Settings_Advanced'.tr()),
                children: [
                  Text('Settings_Tune_Desc'.tr()),
                  const SizedBox(height: 12),
                  for (final name in PRAYER_NAMES)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppNumberField(
                            key: ValueKey('tune_input_$name'),
                            controller: tuneControllers[name]!,
                            label: name.tr(),
                            onChanged: (value) => saveTuneValue(name, value),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: tuneControllers[name]!,
                            builder: (_, value, __) => Text(
                              _offsetPreview(
                                name,
                                int.tryParse(value.text) ?? 0,
                              ),
                              style: TextStyle(
                                color: AppPalette.of(context).muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    key: const ValueKey('reset_prayer_adjustments'),
                    onPressed: _resetAdjustments,
                    icon: const Icon(Icons.restore),
                    label: Text('Settings_Reset_Adjustments'.tr()),
                  ),
                ],
              ),
            ]),
            _section('Prayer_Notifications_Title', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: Text('Prayer_Notifications_Title'.tr()),
                subtitle: Text(
                  (!kIsWeb && Platform.isAndroid
                          ? 'Prayer_Notifications_Desc'
                          : 'Prayer_Notifications_Not_Supported')
                      .tr(),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: !kIsWeb && Platform.isAndroid
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PrayerNotificationsPageClass(prefs: widget.prefs),
                        ),
                      )
                    : null,
              ),
            ]),
            _section('Settings_Storage_Section', [
              _buildClearPrayerCacheButton(),
            ]),
          ],
        ),
      ),
    ),
  );

  String _offsetPreview(String name, int offset) {
    final raw = _previewDay?.timings[name];
    final adjusted = prayerTimeOnDate(raw, _previewDay?.date ?? DateTime.now());
    if (adjusted == null) {
      return 'Settings_Offset_Effect'.tr(
        namedArgs: {'minutes': offset.toString()},
      );
    }
    final base = adjusted.subtract(
      Duration(minutes: _previewOffsets[name] ?? 0),
    );
    final formatter = DateFormat(is24 ? 'HH:mm' : 'h:mm a');
    return 'Settings_Offset_Preview'.tr(
      namedArgs: {
        'before': formatter.format(base),
        'after': formatter.format(base.add(Duration(minutes: offset))),
      },
    );
  }

  Future<void> _resetAdjustments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settings_Reset_Adjustments'.tr()),
        content: Text('Settings_Reset_Adjustments_Confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Settings_Reset_Adjustments'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await widget.prefs;
    final old = {
      for (final name in PRAYER_NAMES)
        prayerTunePreferenceKey(name): prefs.getInt(
          prayerTunePreferenceKey(name),
        ),
    };
    final revision = ++_saveRevision;
    await _saves.run(() async {
      try {
        for (final key in old.keys) {
          if (!await prefs.setInt(key, 0)) throw StateError('Reset failed');
        }
        await helper.invalidateTodayCachedData(widget.prefs);
        if (mounted) {
          setState(() {
            for (final c in tuneControllers.values) {
              c.text = '0';
            }
            _saveFeedback = 'Settings_Success_Save';
          });
        }
        unawaited(_refreshPrayerSettings(revision));
      } catch (_) {
        for (final entry in old.entries) {
          if (entry.value == null) {
            await prefs.remove(entry.key);
          } else {
            await prefs.setInt(entry.key, entry.value!);
          }
        }
        if (mounted) setState(() => _saveFeedback = 'Settings_Unable_To_Save');
      }
    });
  }

  Widget _buildLocationSelector() {
    final String subtitle = locationDisplayName.isEmpty
        ? "Settings_Location_Desc".tr()
        : locationDisplayName;
    return Material(
      color: AppPalette.of(context).panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: BorderSide(color: AppPalette.of(context).border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          Icons.location_on_outlined,
          color: AppPalette.of(context).text,
        ),
        title: Text("Settings_Location_Title".tr(), style: detailsStyle),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppPalette.of(context).accent, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: AppPalette.of(context).text),
        onTap: _showLocationPicker,
      ),
    );
  }

  Widget _buildClearPrayerCacheButton() {
    return Align(
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: _confirmClearPrayerCache,
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text("Settings_Clear_Prayer_Cache".tr()),
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.of(context).muted,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Future<void> _confirmClearPrayerCache() async {
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text("Settings_Clear_Prayer_Cache".tr()),
        content: Text("Settings_Clear_Prayer_Cache_Confirm".tr()),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel".tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Settings_Clear".tr()),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;

    final int cleared = await api_utils.clearPrayerTimesCache(widget.prefs);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Settings_Clear_Prayer_Cache_Success".tr(
            args: <String>[cleared.toString()],
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationPicker() async {
    final TextEditingController searchController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController latitudeController = TextEditingController();
    final TextEditingController longitudeController = TextEditingController();
    List<PrayerLocation> searchResults = <PrayerLocation>[];
    bool isSearching = false;
    final bool showIpEstimate = !_hasSavedLocation;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppPalette.of(context).panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext sheetContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setSheetState) {
              Future<void> useCurrentLocation() async {
                setSheetState(() => isSearching = true);
                try {
                  final PrayerLocation location =
                      await getCurrentPrayerLocation();
                  await _savePrayerLocation(location);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } on PrayerLocationException catch (error) {
                  EasyLoading.showError(
                    error.translationKey.tr(),
                    dismissOnTap: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSearching = false);
                  }
                }
              }

              Future<void> useIpEstimate() async {
                setSheetState(() => isSearching = true);
                try {
                  final String estimatedAddress = await getIpLocationEstimate();
                  final List<PrayerLocation> matches =
                      await searchPrayerLocations(estimatedAddress);
                  if (matches.isEmpty) {
                    throw const PrayerLocationException(
                      'Settings_Location_Ip_Estimate_Unavailable',
                    );
                  }
                  final PrayerLocation resolvedLocation =
                      await resolvePrayerLocationCoordinates(
                        matches.first.latitude,
                        matches.first.longitude,
                        source: 'ip',
                      );
                  if (!sheetContext.mounted) return;
                  final bool? confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text("Settings_Location_Ip_Confirm_Title".tr()),
                      content: Text(
                        "Settings_Location_Ip_Confirm_Desc".tr(
                          args: <String>[resolvedLocation.cityCountry],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            "Settings_Location_Ip_Confirm_Cancel".tr(),
                          ),
                        ),
                        FilledButton(
                          style: _locationPrimaryButtonStyle,
                          onPressed: () => Navigator.pop(context, true),
                          child: Text("Settings_Location_Ip_Confirm_Use".tr()),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _saveAddressLocation(
                      estimatedAddress,
                      resolvedLocation,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  }
                } on PrayerLocationException catch (error) {
                  EasyLoading.showError(
                    error.translationKey.tr(),
                    dismissOnTap: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSearching = false);
                  }
                }
              }

              Future<void> search() async {
                setSheetState(() => isSearching = true);
                try {
                  final List<PrayerLocation> results =
                      await searchPrayerLocations(searchController.text);
                  if (sheetContext.mounted) {
                    setSheetState(() => searchResults = results);
                  }
                } on PrayerLocationException catch (error) {
                  EasyLoading.showError(
                    error.translationKey.tr(),
                    dismissOnTap: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSearching = false);
                  }
                }
              }

              Future<void> saveCoordinates() async {
                final double? latitude = double.tryParse(
                  latitudeController.text.trim(),
                );
                final double? longitude = double.tryParse(
                  longitudeController.text.trim(),
                );
                if (latitude == null ||
                    longitude == null ||
                    latitude < -90 ||
                    latitude > 90 ||
                    longitude < -180 ||
                    longitude > 180) {
                  EasyLoading.showError(
                    "Settings_Location_Invalid_Coordinates".tr(),
                    dismissOnTap: true,
                  );
                  return;
                }
                setSheetState(() => isSearching = true);
                try {
                  final PrayerLocation location =
                      await resolvePrayerLocationCoordinates(
                        latitude,
                        longitude,
                        source: 'manual',
                      );
                  await _savePrayerLocation(location);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } on PrayerLocationException catch (error) {
                  EasyLoading.showError(
                    error.translationKey.tr(),
                    dismissOnTap: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSearching = false);
                  }
                }
              }

              Future<void> saveTypedAddress() async {
                final String address = addressController.text.trim();
                if (address.isEmpty) {
                  EasyLoading.showError(
                    "Settings_Location_Address_Required".tr(),
                    dismissOnTap: true,
                  );
                  return;
                }
                setSheetState(() => isSearching = true);
                try {
                  final List<PrayerLocation> matches =
                      await searchPrayerLocations(address);
                  if (matches.isEmpty) {
                    EasyLoading.showError(
                      "Settings_Location_No_Results".tr(),
                      dismissOnTap: true,
                    );
                    return;
                  }
                  final PrayerLocation resolvedLocation =
                      await resolvePrayerLocationCoordinates(
                        matches.first.latitude,
                        matches.first.longitude,
                        source: 'address',
                      );
                  await _saveAddressLocation(address, resolvedLocation);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } on PrayerLocationException catch (error) {
                  EasyLoading.showError(
                    error.translationKey.tr(),
                    dismissOnTap: true,
                  );
                } finally {
                  if (sheetContext.mounted) {
                    setSheetState(() => isSearching = false);
                  }
                }
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          "Settings_Location_Change".tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Settings_Location_Sheet_Desc".tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: isSearching ? null : useCurrentLocation,
                          style: _locationPrimaryButtonStyle,
                          icon: const Icon(Icons.my_location),
                          label: Text("Settings_Location_Current".tr()),
                        ),
                        if (showIpEstimate) ...<Widget>[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: isSearching ? null : useIpEstimate,
                            style: _locationSecondaryButtonStyle,
                            icon: const Icon(Icons.language_outlined),
                            label: Text("Settings_Location_Ip_Estimate".tr()),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Settings_Location_Ip_Estimate_Desc".tr(),
                            style: TextStyle(
                              color: AppPalette.of(context).accent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          "Settings_Location_Search".tr(),
                          style: detailsStyle,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                style: detailsStyle,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => search(),
                                decoration: InputDecoration(
                                  hintText: "Settings_Location_Search_Hint"
                                      .tr(),
                                  hintStyle: TextStyle(
                                    color: AppPalette.of(context).accent,
                                  ),
                                  filled: true,
                                  fillColor: AppPalette.of(context).panel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSearching ? null : search,
                              icon: Icon(
                                Icons.search,
                                color: AppPalette.of(context).text,
                              ),
                              tooltip: "Settings_Location_Search".tr(),
                            ),
                          ],
                        ),
                        if (isSearching)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (!isSearching &&
                            searchController.text.trim().isNotEmpty &&
                            searchResults.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              "Settings_Location_No_Results".tr(),
                              style: TextStyle(
                                color: AppPalette.of(context).accent,
                              ),
                            ),
                          ),
                        ...searchResults.map(
                          (PrayerLocation result) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.place_outlined,
                              color: AppPalette.of(context).text,
                            ),
                            title: Text(
                              result.displayName,
                              style: detailsStyle,
                            ),
                            onTap: () async {
                              setSheetState(() => isSearching = true);
                              try {
                                final PrayerLocation resolvedLocation =
                                    await resolvePrayerLocationCoordinates(
                                      result.latitude,
                                      result.longitude,
                                      source: 'address',
                                    );
                                await _saveAddressLocation(
                                  result.displayName,
                                  resolvedLocation,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } on PrayerLocationException catch (error) {
                                EasyLoading.showError(
                                  error.translationKey.tr(),
                                  dismissOnTap: true,
                                );
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => isSearching = false);
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.edit_location_alt_outlined,
                            color: AppPalette.of(context).text,
                          ),
                          title: Text(
                            "Settings_Location_Manual_Address".tr(),
                            style: detailsStyle,
                          ),
                          children: <Widget>[
                            Text(
                              "Settings_Location_Manual_Address_Desc".tr(),
                              style: TextStyle(
                                color: AppPalette.of(context).accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: addressController,
                              style: detailsStyle,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => saveTypedAddress(),
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: "Settings_Location_Address_Hint".tr(),
                                hintStyle: TextStyle(
                                  color: AppPalette.of(context).accent,
                                ),
                                filled: true,
                                fillColor: AppPalette.of(context).panel,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: saveTypedAddress,
                                style: _locationPrimaryButtonStyle,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  "Settings_Location_Save_Address".tr(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.tune,
                            color: AppPalette.of(context).text,
                          ),
                          title: Text(
                            "Settings_Location_Advanced".tr(),
                            style: detailsStyle,
                          ),
                          children: <Widget>[
                            Text(
                              "Settings_Location_Coordinates_Desc".tr(),
                              style: TextStyle(
                                color: AppPalette.of(context).accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: latitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    style: detailsStyle,
                                    decoration: InputDecoration(
                                      labelText: "Settings_Location_Latitude"
                                          .tr(),
                                      labelStyle: TextStyle(
                                        color: AppPalette.of(context).text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: longitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    style: detailsStyle,
                                    decoration: InputDecoration(
                                      labelText: "Settings_Location_Longitude"
                                          .tr(),
                                      labelStyle: TextStyle(
                                        color: AppPalette.of(context).text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: saveCoordinates,
                                style: _locationPrimaryButtonStyle,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  "Settings_Location_Save_Coordinates".tr(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
      addressController.dispose();
      latitudeController.dispose();
      longitudeController.dispose();
    }
  }

  Future<void> _savePrayerLocation(PrayerLocation location) async {
    if (await _saveSetting('location', jsonEncode(location.toJson())) &&
        mounted) {
      setState(() {
        locationDisplayName = location.cityCountry;
        _hasSavedLocation = true;
      });
    }
  }

  Future<void> _saveAddressLocation(
    String address,
    PrayerLocation resolvedLocation,
  ) async {
    if (await _saveSetting(
          'location',
          jsonEncode({
            'type': 'address',
            'location': address,
            'latitude': resolvedLocation.latitude,
            'longitude': resolvedLocation.longitude,
            'cityCountry': resolvedLocation.cityCountry,
            'source': 'address',
          }),
        ) &&
        mounted) {
      setState(() {
        locationDisplayName = resolvedLocation.cityCountry;
        _hasSavedLocation = true;
      });
    }
  }

  ButtonStyle get _locationPrimaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppPalette.of(context).accent,
    foregroundColor: AppPalette.of(context).canvas,
    disabledBackgroundColor: AppPalette.of(
      context,
    ).accent.withValues(alpha: 0.45),
    disabledForegroundColor: AppPalette.of(
      context,
    ).canvas.withValues(alpha: 0.6),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
  );

  ButtonStyle get _locationSecondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppPalette.of(context).accent,
    side: BorderSide(color: AppPalette.of(context).accent),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
  );

  void saveMethodParameter(String? value) {
    if (value != null) unawaited(_saveSetting('method', value));
  }

  void saveSchoolParameter(String? value) {
    if (value != null) unawaited(_saveSetting('school', value));
  }

  void saveCalendarMethodParameter(String? value) {
    if (value != null) unawaited(_saveSetting('calendarMethod', value));
  }

  void saveAdjustmentValue(num? value) {
    if (value != null) unawaited(_saveSetting('adjustment', value.toInt()));
  }

  void saveTuneValue(String name, num? value) {
    if (value != null) {
      unawaited(_saveSetting(prayerTunePreferenceKey(name), value.toInt()));
    }
  }

  void _changelanguage(String? val) {
    if (val == null) return;
    setState(() => selectedlocale = val);
    if (val == "English") {
      context.setLocale(const Locale("en", "US"));
    } else if (val == "العربية") {
      context.setLocale(const Locale("ar", "EG"));
    }
  }
}
