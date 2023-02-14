import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muslim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Muslim guide'),
      builder: EasyLoading.init(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  TextEditingController locationController = TextEditingController();
  static const headlineStyle = TextStyle(fontSize: 30,fontWeight: FontWeight.bold);
  static const detailsStyle = TextStyle(fontSize: 20,fontWeight: FontWeight.w500);
  static const highlightedDetailsStyle = TextStyle(fontSize: 20,fontWeight: FontWeight.w500, color: Colors.green);
  List<String> prayerNames = ['Fajr','Sunrise','Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  String nextPray = 'Fajr';

  String jsonDataDate = "Date";
  Map<String, dynamic> jsonTimings = <String, dynamic>{};

  void _fetchAPI() async{
    final SharedPreferences prefs = await _prefs;
    bool saveLocation = false;
    // Check location
    if(locationController.text.isEmpty){
      EasyLoading.showError("Location is needed!");
      return;
    }else{
      // Compare input with saved location
      var savedLocation = await checkSavedLocation();
      if(savedLocation == null || savedLocation['location'] != locationController.text){
        saveLocation = true;
      }
    }
    var jsonData;
    String jsonEncoded = "";
    bool fitchedFromSharedPreferences = false;
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    
    String formattedDate = dateFormatter(DateTime.now());
    final String? sharedData = prefs.getString(formattedDate);
    if(sharedData != null){
      fitchedFromSharedPreferences = true;
      print("Fetching from shared-preferences");
      Map<String,dynamic> decodedMap = json.decode(sharedData);
      jsonData = decodedMap;
    }else{
      print("Fetching from API");
      var r = await fetchData(formattedDate, locationController.text);
      jsonEncoded = r.body;
      jsonData = jsonDecode(jsonEncoded);

    }
    if(jsonData != null && jsonData['code'] == 200){
      if(!fitchedFromSharedPreferences){
        print("Setting in shared-preferences");
        await prefs.setString(formattedDate, jsonEncoded);
      }
      if(saveLocation){
        print("Saving Location...");
        Map<String, dynamic> location = {
          "location": locationController.text,
          "type": "address"
        };
        await prefs.setString("location", json.encode(location));
      }
      Map<String, dynamic> timings = jsonData['data']['timings'];
      int prayerIndex = 0;
      bool found = false;
      for(prayerIndex=0;prayerIndex < prayerNames.length;prayerIndex++){
        String name = prayerNames[prayerIndex];
        DateTime currentDateTime = DateTime.now();
        List<String> timingWhole = timings[name].toString().split(":");
        int timingHour = int.parse(timingWhole[0]);
        int timingMinute = int.parse(timingWhole[1]);
        DateTime constructedDateTime = DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day,timingHour,timingMinute,DateTime.now().second);
        if(constructedDateTime.compareTo(currentDateTime) > 0){
          found = true;
          break;
        }
      }
      if(found){
        nextPray = prayerNames[prayerIndex];
      }else{
        nextPray = prayerNames[0];
      }
      setState(() {
        jsonDataDate = jsonData['data']['date']['readable'];
        jsonTimings = jsonData['data']['timings'];
      });
      EasyLoading.dismiss();
    }else{
      EasyLoading.showError("API didn't return any data!",dismissOnTap: true);
      if(fitchedFromSharedPreferences){
        invalidateSharedData(formattedDate);
      }
    }
  }
  void invalidateSharedData(String name) async{
    final SharedPreferences prefs = await _prefs;
    final success = await prefs.remove(name);
    print("Removed from sharedPreferences");
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      var location = await checkSavedLocation();
      if(location != null) {
        setState(() {
          locationController.text = location['location'];
        });
        _fetchAPI();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextFormField(
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  filled: true,
                  hintText: "What is your location",
                  labelText: "Location..."
              ),
              style: detailsStyle,
              controller: locationController,
            ),
            const Divider(),
            Text(
              jsonDataDate,
              style: headlineStyle,
            ),
            const Divider(height: 20, thickness: 5, color: Colors.grey,),
            Expanded(
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prayerNames.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Column(
                      children: [
                        detailsRow(prayerNames[index], jsonTimings[prayerNames[index]]??"-"),
                        const Divider(),
                      ],
                    );
                  }),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAPI,
        tooltip: 'Fetch',
        child: const Icon(Icons.get_app),
      ),
    );
  }

  Widget detailsRow(String headText, String detailsText){
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Center(
              child: Text("$headText:", style: nextPray==headText?highlightedDetailsStyle:detailsStyle),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            width: MediaQuery.of(context).size.width / 2 * 3,
            child: Center(
              child: Text(detailsText, style: nextPray==headText?highlightedDetailsStyle:detailsStyle),
            ),
          ),
        ),
      ],
    );
  }

  checkSavedLocation() async{
    final SharedPreferences prefs = await _prefs;
    final String? sharedData = prefs.getString("location");
    var whatToReturn;
    if(sharedData != null){
      whatToReturn = json.decode(sharedData);
    }
    return whatToReturn;
  }
}
String dateFormatter(DateTime d){
  DateFormat formatter = DateFormat('dd-MM-yyyy');
  String formattedDate = formatter.format(d);
  return formattedDate;
}
Future<http.Response> fetchData(String requiredData, String location) {
  return http.get(Uri.parse('http://api.aladhan.com/v1/timingsByAddress/$requiredData?address=$location'));
}
