import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/shared/constants.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;
import '../../utils/helper.dart' as helper;
import '../../utils/prayer_location_utils.dart';

class SettingsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;
  const SettingsPageClass({Key? key, required this.prefs}) : super(key: key);

  @override
  State<SettingsPageClass> createState() => _SettingsPageClassState();
}

class _SettingsPageClassState extends State<SettingsPageClass> {
  static const detailsStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textColor,
  );
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
    EasyLoading.showInfo("Settings_Loading_Tip");
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

  void _updateSettings() async {
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
    adjustmentsController.text = adjustment.toString();
    final Map<String, int> tuneSettings = await helper
        .getPrayerTimeTuneSettings(widget.prefs);
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
    if (!_hasSavedLocation && !_didPromptForInitialLocation) {
      _didPromptForInitialLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLocationPicker();
      });
    }
  }

  void _change24HourSystem(value) async {
    var result = await shared_preference_methods.setBoolData(
      widget.prefs,
      '24system',
      value,
    );
    if (!result) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
    }
    _updateSettings();
  }

  PopupProps<String> _settingsPopupProps({bool showSearchBox = true}) {
    return PopupProps.menu(
      showSearchBox: showSearchBox,
      showSelectedItems: true,
      fit: FlexFit.loose,
      constraints: const BoxConstraints(maxHeight: 360),
      menuProps: const MenuProps(
        backgroundColor: settingsWidgetBGColor,
        surfaceTintColor: settingsWidgetBGColor,
        elevation: 12,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      searchFieldProps: TextFieldProps(
        style: const TextStyle(color: textColor),
        cursorColor: highlightedTextColor,
        decoration: InputDecoration(
          hintText: "Settings_Dropdown_Search".tr(),
          hintStyle: const TextStyle(color: highlightedColor),
          prefixIcon: const Icon(Icons.search, color: highlightedTextColor),
          filled: true,
          fillColor: primaryColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: boxesBorderColor),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: highlightedTextColor, width: 1.5),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      itemBuilder: _buildSettingsDropdownItem,
      emptyBuilder: (BuildContext context, String searchEntry) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "Settings_Dropdown_No_Results".tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: highlightedColor),
        ),
      ),
    );
  }

  DropDownDecoratorProps _settingsDropdownDecorator({
    required String label,
    required String helperText,
  }) {
    return DropDownDecoratorProps(
      baseStyle: const TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: highlightedTextColor),
        helperText: helperText,
        helperStyle: const TextStyle(color: highlightedColor),
        suffixIconColor: highlightedTextColor,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: boxesBorderColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: highlightedTextColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSettingsDropdownItem(
    BuildContext context,
    String item,
    bool isDisabled,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? highlightedColor.withValues(alpha: 0.22) : null,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: isSelected
            ? Border.all(color: highlightedColor)
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          item,
          style: TextStyle(
            color: isDisabled ? Colors.white38 : textColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: highlightedTextColor)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings_Title".tr(),
          style: const TextStyle(color: textColor),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textColor),
        // actions: [
        //   IconButton(onPressed: (){
        //     _updateSettings();
        //   }, icon: const Icon(Icons.save, color: Colors.white54,))
        // ],
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
              // interpolatedColor4,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: DropdownSearch<String>(
                      popupProps: _settingsPopupProps(showSearchBox: false),
                      items: (filter, infiniteScrollProps) => [
                        "العربية",
                        "English",
                      ],
                      decoratorProps: _settingsDropdownDecorator(
                        label: "Settings_Language_Title".tr(),
                        helperText: "Settings_Language_Desc".tr(),
                      ),
                      onChanged: _changelanguage,
                      selectedItem: selectedlocale,
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: const Text(
                            "Settings_Use24Hour",
                            style: detailsStyle,
                          ).tr(),
                        ),
                        Expanded(
                          flex: 1,
                          child: Switch(
                            activeThumbColor: textColor,
                            inactiveThumbColor: Colors.grey,
                            value: is24,
                            onChanged: _change24HourSystem,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  _buildLocationSelector(),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: DropdownSearch<String>(
                      popupProps: _settingsPopupProps(),
                      items: (filter, infiniteScrollProps) =>
                          authorities.keys.toList(),
                      decoratorProps: _settingsDropdownDecorator(
                        label: "Settings_Method".tr(),
                        helperText: "Settings_Method_Desc".tr(),
                      ),
                      onChanged: saveMethodParameter,
                      selectedItem: selectedMethod,
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: DropdownSearch<String>(
                      popupProps: _settingsPopupProps(showSearchBox: false),
                      items: (filter, infiniteScrollProps) =>
                          schools.keys.toList(),
                      decoratorProps: _settingsDropdownDecorator(
                        label: "Settings_School".tr(),
                        helperText: "Settings_School_Desc".tr(),
                      ),
                      onChanged: saveSchoolParameter,
                      selectedItem: selectedSchool,
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Settings_Tune_Title".tr(), style: detailsStyle),
                        const SizedBox(height: 4),
                        Text(
                          "Settings_Tune_Desc".tr(),
                          style: const TextStyle(
                            color: highlightedColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final prayerName in PRAYER_NAMES)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    prayerName.tr(),
                                    style: detailsStyle,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: NumberInputWithIncrementDecrement(
                                    key: ValueKey("tune_input_$prayerName"),
                                    initialValue: int.parse(
                                      tuneControllers[prayerName]!.text.isEmpty
                                          ? "0"
                                          : tuneControllers[prayerName]!.text,
                                    ),
                                    controller: tuneControllers[prayerName]!,
                                    onChanged: (newValue) =>
                                        saveTuneValue(prayerName, newValue),
                                    onDecrement: (newValue) =>
                                        saveTuneValue(prayerName, newValue),
                                    onIncrement: (newValue) =>
                                        saveTuneValue(prayerName, newValue),
                                    min: -100,
                                    incDecBgColor: textColor,
                                    style: const TextStyle(color: textColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border: Border.all(color: boxesBorderColor, width: 1),
                    ),
                    child: DropdownSearch<String>(
                      popupProps: _settingsPopupProps(),
                      items: (filter, infiniteScrollProps) =>
                          CalendarMethods.keys.toList(),
                      decoratorProps: _settingsDropdownDecorator(
                        label: "Settings_Calendar_Methods".tr(),
                        helperText: "Settings_Calendar_Methods_Desc".tr(),
                      ),
                      onChanged: saveCalendarMethodParameter,
                      selectedItem: selectedCalendarMethod,
                    ),
                  ),
                  Visibility(
                    visible: selectedCalendarMethod == "MATHEMATICAL",
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        color: settingsWidgetBGColor,
                        border: Border.all(color: boxesBorderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Text(
                                  "Settings_Adj_Hij_Desc",
                                  style: TextStyle(color: textColor),
                                ).tr(),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2,
                            child: NumberInputWithIncrementDecrement(
                              initialValue: int.parse(
                                (adjustmentsController.text == "")
                                    ? "0"
                                    : adjustmentsController.text,
                              ),
                              controller: adjustmentsController,
                              onChanged: saveAdjustmentValue,
                              onDecrement: saveAdjustmentValue,
                              onIncrement: saveAdjustmentValue,
                              min: -100,
                              incDecBgColor: textColor,
                              style: const TextStyle(color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20, thickness: 5, color: dividerColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    final String subtitle = locationDisplayName.isEmpty
        ? "Settings_Location_Desc".tr()
        : locationDisplayName;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: settingsWidgetBGColor,
        border: Border.all(color: boxesBorderColor, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.location_on_outlined, color: textColor),
        title: Text("Settings_Location_Title".tr(), style: detailsStyle),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: highlightedColor, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: textColor),
        onTap: _showLocationPicker,
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
        backgroundColor: settingsWidgetBGColor,
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
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Settings_Location_Sheet_Desc".tr(),
                          style: const TextStyle(color: highlightedColor),
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
                            style: const TextStyle(
                              color: highlightedColor,
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
                                  hintStyle: const TextStyle(
                                    color: highlightedColor,
                                  ),
                                  filled: true,
                                  fillColor: thirdColor,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSearching ? null : search,
                              icon: const Icon(Icons.search, color: textColor),
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
                              style: const TextStyle(color: highlightedColor),
                            ),
                          ),
                        ...searchResults.map(
                          (PrayerLocation result) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.place_outlined,
                              color: textColor,
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
                          leading: const Icon(
                            Icons.edit_location_alt_outlined,
                            color: textColor,
                          ),
                          title: Text(
                            "Settings_Location_Manual_Address".tr(),
                            style: detailsStyle,
                          ),
                          children: <Widget>[
                            Text(
                              "Settings_Location_Manual_Address_Desc".tr(),
                              style: const TextStyle(color: highlightedColor),
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
                                hintStyle: const TextStyle(
                                  color: highlightedColor,
                                ),
                                filled: true,
                                fillColor: thirdColor,
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
                          leading: const Icon(Icons.tune, color: textColor),
                          title: Text(
                            "Settings_Location_Advanced".tr(),
                            style: detailsStyle,
                          ),
                          children: <Widget>[
                            Text(
                              "Settings_Location_Coordinates_Desc".tr(),
                              style: const TextStyle(color: highlightedColor),
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
                                      labelStyle: const TextStyle(
                                        color: textColor,
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
                                      labelStyle: const TextStyle(
                                        color: textColor,
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
    EasyLoading.showInfo("Settings_Saving_Location".tr());
    final bool result = await shared_preference_methods.setStringData(
      widget.prefs,
      "location",
      json.encode(location.toJson()),
    );
    if (!result) {
      EasyLoading.showError("Settings_Unable_To_Save".tr(), dismissOnTap: true);
      return;
    }
    await helper.invalidateTodayCachedData(widget.prefs);
    if (mounted) {
      setState(() {
        locationDisplayName = location.cityCountry;
        _hasSavedLocation = true;
      });
    }
    EasyLoading.showSuccess("Settings_Success_Save".tr());
  }

  Future<void> _saveAddressLocation(
    String address,
    PrayerLocation resolvedLocation,
  ) async {
    EasyLoading.showInfo("Settings_Saving_Location".tr());
    final bool result = await shared_preference_methods.setStringData(
      widget.prefs,
      "location",
      json.encode(<String, dynamic>{
        "type": "address",
        "location": address,
        "latitude": resolvedLocation.latitude,
        "longitude": resolvedLocation.longitude,
        "cityCountry": resolvedLocation.cityCountry,
        "source": "address",
      }),
    );
    if (!result) {
      EasyLoading.showError("Settings_Unable_To_Save".tr(), dismissOnTap: true);
      return;
    }
    await helper.invalidateTodayCachedData(widget.prefs);
    if (mounted) {
      setState(() {
        locationDisplayName = resolvedLocation.cityCountry;
        _hasSavedLocation = true;
      });
    }
    EasyLoading.showSuccess("Settings_Success_Save".tr());
  }

  static final ButtonStyle _locationPrimaryButtonStyle = FilledButton.styleFrom(
    backgroundColor: highlightedColor,
    foregroundColor: primaryColor,
    disabledBackgroundColor: highlightedColor.withValues(alpha: 0.45),
    disabledForegroundColor: primaryColor.withValues(alpha: 0.6),
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
  );

  static final ButtonStyle _locationSecondaryButtonStyle =
      OutlinedButton.styleFrom(
        foregroundColor: highlightedTextColor,
        side: const BorderSide(color: highlightedColor),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      );

  void saveMethodParameter(String? value) async {
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_Method".tr());
      if (kDebugMode) {
        print("Saving method...");
      }
      bool result = await shared_preference_methods.setStringData(
        widget.prefs,
        "method",
        value,
      );
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      await helper.invalidateTodayCachedData(widget.prefs);
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }

  void saveSchoolParameter(String? value) async {
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_School".tr());
      if (kDebugMode) {
        print("Saving school...");
      }
      bool result = await shared_preference_methods.setStringData(
        widget.prefs,
        "school",
        value,
      );
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      await helper.invalidateTodayCachedData(widget.prefs);
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }

  void saveCalendarMethodParameter(String? value) async {
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_Calendar_Method".tr());
      if (kDebugMode) {
        print("Saving Calendar method...");
      }
      bool result = await shared_preference_methods.setStringData(
        widget.prefs,
        "calendarMethod",
        value,
      );
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      await helper.invalidateTodayCachedData(widget.prefs);
      setState(() {
        selectedCalendarMethod = value;
        EasyLoading.showSuccess("Settings_Success_Save".tr());
      });
    }
  }

  void saveAdjustmentValue(num? newValue) async {
    if (newValue != null) {
      EasyLoading.showInfo("Settings_Saving_Adjustment".tr());
      if (kDebugMode) {
        print("Saving Adjustment Value...");
      }
      bool result = await shared_preference_methods.setIntegerData(
        widget.prefs,
        "adjustment",
        newValue.toInt(),
      );
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      await helper.invalidateTodayCachedData(widget.prefs);
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }

  void saveTuneValue(String prayerName, num? newValue) async {
    if (newValue != null) {
      EasyLoading.showInfo("Settings_Saving_Tune".tr());
      if (kDebugMode) {
        print("Saving tune value for $prayerName...");
      }
      bool result = await shared_preference_methods.setIntegerData(
        widget.prefs,
        prayerTunePreferenceKey(prayerName),
        newValue.toInt(),
      );
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      await helper.invalidateTodayCachedData(widget.prefs);
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }

  void _changelanguage(String? val) {
    print(val);
    if (val == "English") {
      context.setLocale(Locale("en", "US"));
    } else if (val == "العربية") {
      context.setLocale(Locale("ar", "EG"));
    }
  }
}
