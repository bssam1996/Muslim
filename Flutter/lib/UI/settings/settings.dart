import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/sharedpreference_methods.dart' as shared_preference_methods;

class SettingsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;
  const SettingsPageClass({Key? key, required this.prefs}) : super(key: key);

  @override
  State<SettingsPageClass> createState() => _SettingsPageClassState();
}

class _SettingsPageClassState extends State<SettingsPageClass> {

  static const detailsStyle =
  TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
  bool is24 = true;

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
    var exists = await shared_preference_methods.checkExistenceData(widget.prefs, '24system');
    if(exists){
      var shared24 = await shared_preference_methods.getBoolData(widget.prefs, '24system');
      setState(() {
        is24 = shared24;
      });
    }else{
      await shared_preference_methods.setBoolData(widget.prefs, '24system', true);
      setState(() {
        is24 = true;
      });
    }
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
        title: const Text("Setings"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(flex:4, child: Text("Use 24-Hour", style: detailsStyle,)),
                  Expanded(flex:1, child: Switch(
                    value: is24,
                    onChanged: _change24HourSystem,
                  ))
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
