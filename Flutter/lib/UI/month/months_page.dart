import 'dart:convert';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;
import '../../utils/helper.dart' as helper;
import 'helper.dart' as helpermodal;

class MonthsPageClass extends StatefulWidget {
  const MonthsPageClass({super.key});

  @override
  State<MonthsPageClass> createState() => _MonthsPageClassState();
}

class _MonthsPageClassState extends State<MonthsPageClass> {
  List<DetailedDates> detailedDates = <DetailedDates>[];
  late DatesDetailsDataSource detailsDatesDataSource =
      DatesDetailsDataSource(datesData: []);
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    EasyLoading.showInfo("Loading timetable...");
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        DateTime currentDate = DateTime.now();
        await updateTable("${currentDate.year}/${currentDate.month}");
        EasyLoading.dismiss();
      });
    } catch (e) {
      EasyLoading.dismiss();
      if (kDebugMode) {
        print(e);
      }
    }
  }

  updateTable(String date) async {
    detailedDates = await getDatesData(date);
    setState(() {
      detailsDatesDataSource = DatesDetailsDataSource(datesData: detailedDates);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Prayer Calendar"),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () async {
                  final selected = await showMonthYearPicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) {
                    updateTable("${selected.year}/${selected.month}");
                  }
                },
                icon: const Icon(
                  Icons.calendar_month,
                  color: Colors.red,
                )),
            IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return helpermodal.showdialog();
                      });
                },
                icon: const Icon(
                  Icons.question_mark_rounded,
                  color: Colors.blue,
                )),
          ],
        ),
        body: Center(
          child: SfDataGrid(
            rowHeight: 60,
            source: detailsDatesDataSource,
            columnWidthMode: ColumnWidthMode.fill,
            columns: <GridColumn>[
              GridColumn(
                  columnName: 'day',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        "Day",
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'gregorian',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Gregorian',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'hijri',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Hijri',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'fajr',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Fajr',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'sunrise',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Sunrise',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'dhuhr',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Dhuhr',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'asr',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Asr',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'maghrib',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Maghrib',
                        overflow: TextOverflow.ellipsis,
                      ))),
              GridColumn(
                  columnName: 'isha',
                  label: Container(
                      padding: const EdgeInsets.all(8.0),
                      alignment: Alignment.center,
                      child: const AutoSizeText(
                        'Isha',
                        overflow: TextOverflow.ellipsis,
                      ))),
            ],
          ),
        ));
  }

  Future<List<DetailedDates>> getDatesData(String date) async {
    if (kDebugMode) {
      print("Fetching from API");
    }
    dynamic jsonData;
    String? jsonEncoded = "";

    var savedLocation =
        await shared_preference_methods.getStringData(_prefs, 'location', true);
    if (savedLocation == null) {
      EasyLoading.showError(
          "Location is unset and it is needed! please go to settings to add a location",
          duration: const Duration(seconds: 10));
      return [];
    }
    var r = await helper.fetchData(
        "calendarByAddress", date, savedLocation, _prefs);
    jsonEncoded = r?.body;
    jsonData = jsonDecode(jsonEncoded!);
    if (jsonData == null || jsonData['code'] != 200) {
      if (kDebugMode) {
        print("JsonData error $jsonData");
      }
      return [];
    }
    List<dynamic> data = jsonData["data"];
    if (data.isEmpty) {
      return [];
    }
    List<DetailedDates> detailsDates = [];
    for (var index = 0; index < data.length; index++) {
      Map<String, dynamic> timings = data[index]["timings"];
      String? fajr = constructTime(timings["Fajr"].toString());
      String? sunrise = constructTime(timings["Sunrise"].toString());
      String? dhuhr = constructTime(timings["Dhuhr"].toString());
      String? asr = constructTime(timings["Asr"].toString());
      String? maghrib = constructTime(timings["Maghrib"].toString());
      String? isha = constructTime(timings["Isha"].toString());
      Map<String, dynamic> dateDetails = data[index]["date"];
      String gregorianDate = dateDetails["gregorian"]["date"];
      String hijriDate = dateDetails["hijri"]["date"];
      String dayName =
          dateDetails["gregorian"]["weekday"]["en"].toString().substring(0, 3);
      DetailedDates detailedDates = DetailedDates(dayName, gregorianDate,
          hijriDate, fajr, sunrise, dhuhr, asr, maghrib, isha);
      detailsDates.add(detailedDates);
    }
    return detailsDates;
  }

  String constructTime(String time) {
    List<String> timingWhole = time.split(" ");
    return timingWhole[0];
  }
}

class DetailedDates {
  /// Creates the employee class with required details.
  DetailedDates(this.day, this.gregorian, this.hijri, this.fajr, this.sunrise,
      this.dhuhr, this.asr, this.maghrib, this.isha);

  final String day;
  final String gregorian;
  final String hijri;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
}

class DatesDetailsDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  DatesDetailsDataSource({required List<DetailedDates> datesData}) {
    _datesData = datesData
        .map<DataGridRow>((e) => DataGridRow(cells: [
              DataGridCell<String>(columnName: 'day', value: e.day),
              DataGridCell<String>(columnName: 'gregorian', value: e.gregorian),
              DataGridCell<String>(columnName: 'hijri', value: e.hijri),
              DataGridCell<String>(columnName: 'fajr', value: e.fajr),
              DataGridCell<String>(columnName: 'sunrise', value: e.sunrise),
              DataGridCell<String>(columnName: 'dhuhr', value: e.dhuhr),
              DataGridCell<String>(columnName: 'asr', value: e.asr),
              DataGridCell<String>(columnName: 'maghrib', value: e.maghrib),
              DataGridCell<String>(columnName: 'isha', value: e.isha),
            ]))
        .toList();
  }

  List<DataGridRow> _datesData = [];

  @override
  List<DataGridRow> get rows => _datesData;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((e) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Text(e.value.toString()),
      );
    }).toList());
  }
}
