import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;
import 'package:muslim/shared/constants.dart';
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

  DateTime currentDate = DateTime.now();
  bool _isLoading = false;
  late final DataGridController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = DataGridController();
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await _loadCurrentMonth();
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMonth() async {
    setState(() => _isLoading = true);
    try {
      await updateTable("${currentDate.year}/${currentDate.month}");
      await _scrollToToday();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scrollToToday() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || detailedDates.isEmpty) return;
    for (var i = 0; i < detailedDates.length; i++) {
      final parts = detailedDates[i].gregorian.split("-");
      if (parts.length == 2 &&
          int.parse(parts[0]) == DateTime.now().day &&
          int.parse(parts[1]) == DateTime.now().month) {
        final targetOffset = i * 60.0 - (context.size!.height / 2);
        _scrollController.scrollToVerticalOffset(targetOffset);
        return;
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
          centerTitle: true,
          title: FittedBox(
              fit: BoxFit.fitWidth,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      navigateTable(false);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white54,
                    ),
                  ),
                  Text("${"Months_Title".tr()}(${helpermodal.convertGregorianMonthToString(currentDate.month)?.tr()} - ${currentDate.year})",
                    style: const TextStyle(color: textColor)),
                  IconButton(
                    onPressed: () {
                      navigateTable(true);
                    },
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white54,
                    ),
                  ),
                ],
              )),
          backgroundColor: primaryColor,
          iconTheme: const IconThemeData(color: textColor),
          actions: [
            IconButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  final selected = await showMonthYearPicker(
                    context: context,
                    initialDate: currentDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    locale: context.locale
                  );
                  if (selected != null) {
                    currentDate = DateTime(
                      selected.year,
                      selected.month,
                      1
                    );
                    await updateTable("${selected.year}/${selected.month}");
                    if(DateTime.now().year == selected.year && DateTime.now().month == selected.month){
                      await _scrollToToday();
                    }
                  }
                  setState(() => _isLoading = false);
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
        body: SafeArea(
          child: GestureDetector(
          onPanEnd: (details) {
            // Swiping in right direction (Previous month).
            if (details.velocity.pixelsPerSecond.dx > 0) {
              navigateTable(false);
            }
            // Swiping in left direction (Next month).
            if (details.velocity.pixelsPerSecond.dx < 0) {
              navigateTable(true);
            }
          },
          child: Stack(
            children: [
              SfDataGridTheme(
                data: SfDataGridThemeData(
                  gridLineStrokeWidth: 0.8,
                ),
                child: SfDataGrid(
                  controller: _scrollController,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  rowHeight: 60,
                  source: detailsDatesDataSource,
                  swipeMaxOffset: 0.1,
                  allowSwiping: true,
                  columnWidthMode: ColumnWidthMode.fill,
              columns: <GridColumn>[
                generateColumn("day", thirdColor, "Months_Column_Day".tr(), textColor),
                generateColumn("gregorian", thirdColor, "Months_Column_Gregorian".tr(), textColor),
                generateColumn("hijri", thirdColor, "Months_Column_Hijri".tr(), textColor),
                generateColumn("fajr", thirdColor, "Months_Column_Fajr".tr(), textColor),
                generateColumn("sunrise", thirdColor, "Months_Column_Sunrise".tr(), textColor),
                generateColumn("dhuhr", thirdColor, "Months_Column_Dhuhr".tr(), textColor),
                generateColumn("asr", thirdColor, "Months_Column_Asr".tr(), textColor),
                generateColumn("maghrib", thirdColor, "Months_Column_Maghrib".tr(), textColor),
                generateColumn("isha", thirdColor, "Months_Column_Isha".tr(), textColor),
              ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
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
          "Location_Missing_Error".tr(),
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

    var exists =
        await shared_preference_methods.checkExistenceData(_prefs, '24system');
    bool shared24 = true;
    if (exists) {
      shared24 =
          await shared_preference_methods.getBoolData(_prefs, '24system');
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
      if (shared24 == false) {
        fajr = shared24Convert(fajr);
        sunrise = shared24Convert(sunrise);
        dhuhr = shared24Convert(dhuhr);
        asr = shared24Convert(asr);
        maghrib = shared24Convert(maghrib);
        isha = shared24Convert(isha);
      }
      Map<String, dynamic> dateDetails = data[index]["date"];
      List<String> splittedGregorianDate =
          dateDetails["gregorian"]["date"].split("-");
      String gregorianDate =
          "${splittedGregorianDate[0]}-${splittedGregorianDate[1]}";
      List<String> splittedhijriDate = dateDetails["hijri"]["date"].split("-");
      String hijriDate = "${splittedhijriDate[0]}-${splittedhijriDate[1]}";
      String dayName =
          dateDetails["gregorian"]["weekday"]["en"].toString().substring(0, 3);
      String fullGregorian = dateDetails["gregorian"]["date"].toString();
      DetailedDates detailedDates = DetailedDates(dayName.tr(), gregorianDate,
          hijriDate, fajr, sunrise, dhuhr, asr, maghrib, isha, fullGregorian);
      detailsDates.add(detailedDates);
    }
    return detailsDates;
  }

  void navigateTable(bool forward) async {
    setState(() => _isLoading = true);
    if(forward){
      currentDate = DateTime(
          currentDate.year,
          currentDate.month + 1,
          1
      );
    }else{
      currentDate = DateTime(
          currentDate.year,
          currentDate.month - 1,
          1
      );
    }
    await updateTable("${currentDate.year}/${currentDate.month}");
    if(DateTime.now().year == currentDate.year && DateTime.now().month == currentDate.month){
      await _scrollToToday();
    }
    setState(() => _isLoading = false);
  }
}
String constructTime(String time) {
  List<String> timingWhole = time.split(" ");
  return timingWhole[0];
}
GridColumn generateColumn(
    String id, Color color, String labelName, Color textColor) {
  return GridColumn(
      columnName: id,
      label: Container(
          color: color,
          padding: const EdgeInsets.fromLTRB(2.0,0,2.0,0),
          alignment: Alignment.center,
          child: FittedBox(
            child: AutoSizeText(
              labelName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor),
              minFontSize: 4,
            ),
          )));
}

class DetailedDates {
  /// Creates the employee class with required details.
  DetailedDates(this.day, this.gregorian, this.hijri, this.fajr, this.sunrise,
      this.dhuhr, this.asr, this.maghrib, this.isha, this.fullGregorian);

  final String day;
  final String gregorian;
  final String hijri;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String fullGregorian;
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
              DataGridCell<String>(columnName: 'fullGregorian', value: e.fullGregorian),
            ]))
        .toList();
  }

  List<DataGridRow> _datesData = [];

  @override
  List<DataGridRow> get rows => _datesData;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    Color backgroundColor = interpolatedColor3;
    String fullDate = row.getCells()[9].value.toString();
    List<String> parts = fullDate.split("-");
    if(parts.length == 3){
      if(int.parse(parts[0]) == DateTime.now().day &&
         int.parse(parts[1]) == DateTime.now().month &&
         int.parse(parts[2]) == DateTime.now().year){
        backgroundColor = highlightedMonthDayColor;
      }
    }
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((e) {
          return Container(
            color: (e.columnName == "day" || e.columnName == "gregorian" || e.columnName == "hijri")? thirdColor:backgroundColor,
            alignment: Alignment.center,
            // padding: const EdgeInsets.all(8.0),
            child: FittedBox(
                child: AutoSizeText(
                  e.value.toString(),
                  style: const TextStyle(color: textColor),
            )),
          );
    }).toList());
  }
}

String shared24Convert(String time) {
  List<String> splittedTime = time.split(":");
  int integerHour = int.parse(splittedTime[0]);
  if (integerHour > 12) {
    splittedTime[0] = (integerHour - 12).toString();
  }
  return "${splittedTime[0]}:${splittedTime[1]}";
}
