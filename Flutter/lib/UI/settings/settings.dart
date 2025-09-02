import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/shared/constants.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
import 'package:seeip_client/seeip_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/shared_preference_methods.dart' as shared_preference_methods;
import 'package:csc_picker/csc_picker.dart';
import '../../utils/helper.dart' as helper;

class SettingsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;
  const SettingsPageClass({Key? key, required this.prefs}) : super(key: key);

  @override
  State<SettingsPageClass> createState() => _SettingsPageClassState();
}

class _SettingsPageClassState extends State<SettingsPageClass> {

  static const detailsStyle =
  TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor);
  bool is24 = true;
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";
  String address = "";
  String selectedMethod = "Default";
  String selectedSchool = "Shafi (Standard)";
  String selectedlocale = "";
  TextEditingController locationController = TextEditingController();
  TextEditingController adjustmentsController = TextEditingController();

  final GlobalKey<CSCPickerState> _cscPickerKey = GlobalKey();
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

  void _updateSettings() async{
    // 24 System
    var shared24Exists = await shared_preference_methods.checkExistenceData(widget.prefs, '24system');
    var shared24 = true;
    if(shared24Exists){
      var shared24Setting = await shared_preference_methods.getBoolData(widget.prefs, '24system');
      shared24 = shared24Setting;
    }else{
      await shared_preference_methods.setBoolData(widget.prefs, '24system', shared24);
    }
    var location = await shared_preference_methods.getStringData(
        widget.prefs, 'location', true);
    if (location != null) {
      locationController.text = location['location'];
    }
    var method = await shared_preference_methods.getStringData(
        widget.prefs, 'method', false);
    if (method != null) {
      selectedMethod = method;
    }
    var school = await shared_preference_methods.getStringData(
        widget.prefs, 'school', false);
    if (school != null) {
      selectedSchool = school;
    }
    var adjustment = await shared_preference_methods.getIntegerData(
        widget.prefs, 'adjustment', 0);
    adjustmentsController.text = adjustment.toString();
    setState(() {
      is24 = shared24;
    });

    if(context.locale.toString() == "ar_EG"){
      selectedlocale = "العربية";
    }else if(context.locale.toString() == "en_US"){
      selectedlocale = "English";
    }
    EasyLoading.dismiss();
  }

  void _change24HourSystem(value) async{
    var result = await shared_preference_methods.setBoolData(widget.prefs, '24system', value);
    if(!result){
      EasyLoading.showError("Couldn't save data".tr(),
          dismissOnTap: true);
    }
    _updateSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings_Title".tr(), style: const TextStyle(color: textColor),),
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
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: settingsWidgetBGColor,
                        ),
                        showSelectedItems: true,
                        fit: FlexFit.loose,
                    ),
                    items: (filter, infiniteScrollProps) => ["العربية", "English"],
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Settings_Language_Title".tr(),
                        labelStyle: const TextStyle(color: textColor),
                        helperText: "Settings_Language_Desc".tr(),
                        helperStyle: const TextStyle(color: highlightedColor),
                        suffixIconColor: textColor,
                      ),
                    ),
                    onChanged: _changelanguage,
                    selectedItem: selectedlocale,
                  ),
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  child: Row(
                    children: [
                      Expanded(flex:4, child: const Text("Settings_Use24Hour", style: detailsStyle,).tr()),
                      Expanded(flex:1, child: Switch(
                        activeColor: textColor,
                        inactiveThumbColor: Colors.grey,
                        value: is24,
                        onChanged: _change24HourSystem,
                      ))
                    ],
                  ),
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                CSCPicker(
                  key: _cscPickerKey,
                  showStates: true,
                  showCities: true,
                  flagState: CountryFlag.DISABLE,
                  dropdownDecoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  disabledDropdownDecoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor.withOpacity(0.3),
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),

                  countrySearchPlaceholder: "Settings_Country".tr(),
                  stateSearchPlaceholder: "Settings_State".tr(),
                  citySearchPlaceholder: "Settings_City".tr(),

                  countryDropdownLabel: "Settings_Country".tr(),
                  stateDropdownLabel: "Settings_State".tr(),
                  cityDropdownLabel: "Settings_City".tr(),

                  selectedItemStyle: const TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),

                  dropdownHeadingStyle: const TextStyle(
                      color: settingsWidgetBGColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                  dropdownItemStyle: const TextStyle(
                    color: settingsWidgetBGColor,
                    fontSize: 14,
                  ),
                  dropdownDialogRadius: 10.0,
                  searchBarRadius: 10.0,
                  onCountryChanged: (value) {
                    setState(() {
                      countryValue = value;
                    });
                  },
                  onStateChanged: (value) {
                    setState(() {
                      stateValue = value??"";
                    });
                  },
                  onCityChanged: (value) {
                    setState(() {
                      cityValue = value??"";
                      address = "";
                      if(countryValue.isNotEmpty){
                        address = countryValue;
                      }
                      if(stateValue.isNotEmpty){
                        address = "$stateValue, $countryValue";
                      }
                      if(cityValue.isNotEmpty) {
                        address = "$cityValue, $stateValue, $countryValue";
                      }
                      locationController.text = address;
                      saveLocationAddress();
                      helper.invalidateTodayCachedData(widget.prefs);
                    });
                  },
                ),
                const SizedBox(height: 10,),
                Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            color: settingsWidgetBGColor,
                            border:
                            Border.all(color: boxesBorderColor, width: 1)),
                        child: TextFormField(
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                              fillColor: settingsWidgetBGColor,
                              filled: true,
                              helperText: "Settings_ManualLocation_Desc".tr(),
                              helperStyle: const TextStyle(color: highlightedColor),
                              suffixIconColor: textColor,
                          ),
                          style: detailsStyle,
                          controller: locationController,
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () {
                            saveLocationAddress();
                            helper.invalidateTodayCachedData(widget.prefs);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
                        child: IconButton(
                          onPressed: () async{
                            EasyLoading.showInfo("Settings_Saving_Location".tr());
                            var seeip = SeeipClient();
                            var ip = await seeip.getIP();
                            var geoLocation = await seeip.getGeoIP(ip.ip);
                            String loc = "${geoLocation.city}, ${geoLocation.region}, ${geoLocation.country}";
                            locationController.text = loc;
                            saveLocationAddress();
                          },
                          icon: const Icon(
                            Icons.language,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: settingsWidgetBGColor,
                        ),
                        fit: FlexFit.loose,
                        showSelectedItems: true,
                    ),
                    items: (filter, infiniteScrollProps) => authorities.keys.toList(),
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Settings_Method".tr(),
                        labelStyle: const TextStyle(color: textColor),
                        helperText: "Settings_Method_Desc".tr(),
                        helperStyle: const TextStyle(color: highlightedColor),
                        suffixIconColor: textColor,
                      ),
                    ),
                    onChanged: saveMethodParameter,
                    selectedItem: selectedMethod,

                  ),
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: settingsWidgetBGColor,
                      ),
                      showSelectedItems: true,
                      fit: FlexFit.loose
                    ),
                    items: (filter, infiniteScrollProps) => schools.keys.toList(),
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Settings_School".tr(),
                        labelStyle: const TextStyle(color: textColor),
                        helperText: "Settings_School_Desc".tr(),
                        helperStyle: const TextStyle(color: highlightedColor),
                        suffixIconColor: textColor,
                      ),
                    ),
                    onChanged: saveSchoolParameter,
                    selectedItem: selectedSchool,
                  ),
                ),
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      color: settingsWidgetBGColor,
                      border:
                      Border.all(color: boxesBorderColor, width: 1)),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Text("Settings_Adj_Hij_Desc",style: TextStyle(color: textColor),).tr(),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width/2,
                        child: NumberInputWithIncrementDecrement(
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
                const Divider(
                  height: 20,
                  thickness: 5,
                  color: dividerColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void saveLocationAddress() async{
    if (locationController.text.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_Location".tr());
      if (kDebugMode) {
        print("Saving Location...");
      }
      Map<String, dynamic> location = {
        "location": locationController.text,
        "type": "address"
      };
      bool result = await shared_preference_methods.setStringData(
      widget.prefs, "location", json.encode(location));
      if (!result) {
        EasyLoading.showError("Settings_Unable_To_Save".tr(), dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }

  void saveMethodParameter(String? value) async{
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_Method".tr());
      if (kDebugMode) {
        print("Saving method...");
      }
      bool result = await shared_preference_methods.setStringData(
          widget.prefs, "method", value);
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }
  void saveSchoolParameter(String? value) async{
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Settings_Saving_School".tr());
      if (kDebugMode) {
        print("Saving school...");
      }
      bool result = await shared_preference_methods.setStringData(
          widget.prefs, "school", value);
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }


  void saveAdjustmentValue(num? newValue) async{
    if(newValue != null) {
      EasyLoading.showInfo("Settings_Saving_Adjustment".tr());
      if (kDebugMode) {
        print("Saving school...");
      }
      bool result = await shared_preference_methods.setIntegerData(
          widget.prefs, "adjustment", newValue.toInt());
      if (!result) {
        EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Settings_Success_Save".tr());
    }
  }
  void _changelanguage(String? val) {
    print(val);
    if(val == "English"){
      context.setLocale(Locale("en","US"));
    }else if(val == "العربية"){
      context.setLocale(Locale("ar","EG"));
    }
  }
}

