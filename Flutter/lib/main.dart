import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

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
  static const headlineStyle = TextStyle(fontSize: 30,fontWeight: FontWeight.bold);
  static const detailsStyle = TextStyle(fontSize: 20,fontWeight: FontWeight.w500);
  String jsonDataDate = "";
  Map<String, dynamic> jsonTimings = <String, dynamic>{};

  void _fetchAPI() async{
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    String formattedDate = DateFormatter(DateTime.now());
    var r = await fetchData(formattedDate);
    var jsonData = jsonDecode(r.body);
    if(jsonData != null && jsonData['code'] == 200){
      setState(() {
        jsonDataDate = jsonData['data']['date']['readable'];
        jsonTimings = jsonData['data']['timings'];
      });
      EasyLoading.dismiss();
    }else{
      EasyLoading.showError("API didn't return any data!",dismissOnTap: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _fetchAPI();
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
            Text(
              jsonDataDate,
              style: headlineStyle,
            ),
            const Divider(height: 20, thickness: 5, color: Colors.grey,),
            detailsRow('Fajr', jsonTimings['Fajr']),
            Divider(),
            detailsRow('Sunrise', jsonTimings['Sunrise']),
            Divider(),
            detailsRow('Dhuhr', jsonTimings['Dhuhr']),
            Divider(),
            detailsRow('Asr', jsonTimings['Asr']),
            Divider(),
            detailsRow('Maghrib', jsonTimings['Maghrib']),
            Divider(),
            detailsRow('Isha', jsonTimings['Isha']),
            Divider(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAPI,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
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
              child: Text("$headText:", style: detailsStyle),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            width: MediaQuery.of(context).size.width / 2 * 3,
            child: Center(
              child: Text(detailsText, style: detailsStyle),
            ),
          ),
        ),
      ],
    );
  }
}
String DateFormatter(DateTime){
  DateFormat formatter = DateFormat('dd-MM-yyyy');
  String formattedDate = formatter.format(DateTime);
  return formattedDate;
}
Future<http.Response> fetchData(String requiredData) {
  return http.get(Uri.parse('http://api.aladhan.com/v1/timingsByAddress/$requiredData?address=Crawley, UK'));
}
