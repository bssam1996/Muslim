import 'package:flutter/material.dart';
Dialog showdialog(){
  List<DataRow> datarows = [];
  Map<int, String> months = {
    1: "Muharram",
    2: "Safar",
    3: "Rabi al-Awwal",
    4: "Rabi al-Thani",
    5: "Jumada al-Awwal",
    6: "Jumada al-Thani",
    7: "Rajab",
    8: "Shaban",
    9: "Ramadan",
    10: "Shawwal",
    11: "Dhu al-Qadah",
    12: "Dhu al-Hijjah",
  };
  for(int monthNumber = 1; monthNumber < 13; monthNumber++){
    String? monthName = months[monthNumber];
    DataRow dataRow = DataRow(cells: [
      DataCell(Text(monthNumber.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),)),
      DataCell(Text(monthName??"", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),)),
    ]);
    datarows.add(dataRow);
  }
  return Dialog(
    shape: RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(20.0)),
    child: Container(
      constraints: const BoxConstraints(maxHeight: 450),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Center(
                child: Text("-Islamic Calendar-",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
              ),
              Center(
                child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text('Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      DataColumn(
                        label: Text('Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
                      ),
                    ],
                    rows: datarows
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}