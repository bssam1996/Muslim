import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:muslim/shared/constants.dart';
import 'package:number_inc_dec/number_inc_dec.dart';
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
  TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor);
  bool is24 = true;
  String countryValue = "";
  String stateValue = "";
  String cityValue = "";
  String address = "";
  String selectedMethod = "Default";
  String selectedSchool = "Shafi (Standard)";

  TextEditingController locationController = TextEditingController();
  TextEditingController adjustmentsController = TextEditingController();

  final GlobalKey<CSCPickerState> _cscPickerKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    EasyLoading.showInfo("Loading settings...");
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
        widget.prefs, 'adjustment', 1);
    adjustmentsController.text = adjustment.toString();
    setState(() {
      is24 = shared24;
    });
    EasyLoading.dismiss();
  }

  void _change24HourSystem(value) async{
    var result = await shared_preference_methods.setBoolData(widget.prefs, '24system', value);
    if(!result){
      EasyLoading.showError("Couldn't save data",
          dismissOnTap: true);
    }
    _updateSettings();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      backgroundColor: thirdColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                child: Row(
                  children: [
                    const Expanded(flex:4, child: Text("Use 24-Hour", style: detailsStyle,)),
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
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                disabledDropdownDecoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    color: fourthColor.withOpacity(0.3),
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),

                countrySearchPlaceholder: "Country",
                stateSearchPlaceholder: "State",
                citySearchPlaceholder: "City",

                countryDropdownLabel: "Country",
                stateDropdownLabel: "State",
                cityDropdownLabel: "City",

                selectedItemStyle: const TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),

                dropdownHeadingStyle: const TextStyle(
                    color: fourthColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
                dropdownItemStyle: const TextStyle(
                  color: fourthColor,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                child: TextFormField(
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      fillColor: fourthColor,
                      filled: true,
                      helperText: "Your location in text",
                      helperStyle: TextStyle(color: highlightedColor),
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
              const Divider(
                height: 20,
                thickness: 5,
                color: dividerColor,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                child: Theme(
                  data: ThemeData(
                    textTheme: const TextTheme(titleMedium: TextStyle(color: textColor)),
                  ),
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                        menuProps: MenuProps(
                          backgroundColor: fourthColor,
                        ),
                        fit: FlexFit.loose,
                        showSelectedItems: true,
                    ),
                    items: authorities.keys.toList(),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      baseStyle: TextStyle(color: textColor, fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "Method",
                        labelStyle: TextStyle(color: textColor),
                        helperText: "A prayer times calculation method",
                        helperStyle: TextStyle(color: highlightedColor),
                        suffixIconColor: textColor,
                      ),
                    ),
                    onChanged: saveMethodParameter,
                    selectedItem: selectedMethod,

                  ),
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
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                child: Theme(
                  data: ThemeData(
                    textTheme: const TextTheme(titleMedium: TextStyle(color: textColor)),
                  ),
                  child: DropdownSearch<String>(
                    popupProps: const PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: fourthColor,
                      ),
                      showSelectedItems: true,
                      fit: FlexFit.loose
                    ),
                    items: schools.keys.toList(),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      baseStyle: TextStyle(color: textColor, fontSize: 16),
                      dropdownSearchDecoration: InputDecoration(
                        labelText: "School",
                        labelStyle: TextStyle(color: textColor),
                        helperText: "A prayer times calculation school",
                        helperStyle: TextStyle(color: highlightedColor),
                        suffixIconColor: textColor,
                      ),
                    ),
                    onChanged: saveSchoolParameter,
                    selectedItem: selectedSchool,
                  ),
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
                    color: fourthColor,
                    border:
                    Border.all(color: boxesBorderColor, width: 1)),
                child: Theme(
                  data: ThemeData(
                    textTheme: const TextTheme(titleMedium: TextStyle(color: textColor)),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text("Adjustment hijri date (days)",style: TextStyle(color: textColor),),
                          ],
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width/2,
                        child: NumberInputWithIncrementDecrement(
                          controller: adjustmentsController,
                          onChanged: saveAdjustmentValue,
                          onDecrement: saveAdjustmentValue,
                          onIncrement: saveAdjustmentValue,
                          min: -100,
                          incDecBgColor: textColor,
                        ),
                      ),
                    ],
                  )
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
    );
  }

  void saveLocationAddress() async{
    if (locationController.text.isNotEmpty) {
      EasyLoading.showInfo("Saving location...");
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
        EasyLoading.showError("Couldn't save data", dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Saved successfully");
    }
  }

  void saveMethodParameter(String? value) async{
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Saving method...");
      if (kDebugMode) {
        print("Saving method...");
      }
      bool result = await shared_preference_methods.setStringData(
          widget.prefs, "method", value);
      if (!result) {
        EasyLoading.showError("Couldn't save data", dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Saved successfully");
    }
  }
  void saveSchoolParameter(String? value) async{
    if (value != null && value.isNotEmpty) {
      EasyLoading.showInfo("Saving school...");
      if (kDebugMode) {
        print("Saving school...");
      }
      bool result = await shared_preference_methods.setStringData(
          widget.prefs, "school", value);
      if (!result) {
        EasyLoading.showError("Couldn't save data", dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Saved successfully");
    }
  }


  void saveAdjustmentValue(num? newValue) async{
    if(newValue != null) {
      EasyLoading.showInfo("Saving adjustment...");
      if (kDebugMode) {
        print("Saving school...");
      }
      bool result = await shared_preference_methods.setIntegerData(
          widget.prefs, "adjustment", newValue.toInt());
      if (!result) {
        EasyLoading.showError("Couldn't save data", dismissOnTap: true);
        return;
      }
      EasyLoading.showSuccess("Saved successfully");
    }
  }
}

