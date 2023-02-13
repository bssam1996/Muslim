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
  String jsonDataFajr = "";
  String jsonDataSunrise = "";
  String jsonDataDhuhr = "";
  String jsonDataAsr = "";
  String jsonDataMaghrib = "";
  String jsonDataIsha = "";
  void _fetchAPI() async{
    EasyLoading.show(status: 'loading...', dismissOnTap: false);
    String formattedDate = DateFormatter(DateTime.now());
    var r = await fetchData(formattedDate);
    var jsonData = jsonDecode(r.body);
    if(jsonData != null && jsonData['code'] == 200){
      setState(() {
        jsonDataDate = jsonData['data']['date']['readable'];
        jsonDataFajr = jsonData['data']['timings']['Fajr'];
        jsonDataSunrise = jsonData['data']['timings']['Sunrise'];
        jsonDataDhuhr = jsonData['data']['timings']['Dhuhr'];
        jsonDataAsr = jsonData['data']['timings']['Asr'];
        jsonDataMaghrib = jsonData['data']['timings']['Maghrib'];
        jsonDataIsha = jsonData['data']['timings']['Isha'];
      });
    }
    EasyLoading.dismiss();
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
            detailsRow('Fajr:', jsonDataFajr),
            Divider(),
            detailsRow('Sunrise:', jsonDataSunrise),
            Divider(),
            detailsRow('Dhuhr:', jsonDataDhuhr),
            Divider(),
            detailsRow('Asr:', jsonDataAsr),
            Divider(),
            detailsRow('Maghrib:', jsonDataMaghrib),
            Divider(),
            detailsRow('Isha:', jsonDataIsha),
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
              child: Text(headText, style: detailsStyle),
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
