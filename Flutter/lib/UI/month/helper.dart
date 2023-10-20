import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

Dialog showdialog() {
  List<DataRow> datarows = [];
  for (int monthNumber = 1; monthNumber < 13; monthNumber++) {
    String? monthName = hijriMonthsNames[monthNumber];
    DataRow dataRow = DataRow(cells: [
      DataCell(Text(
        monthNumber.toString(),
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
      )),
      DataCell(Text(
        monthName ?? "",
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
      )),
    ]);
    datarows.add(dataRow);
  }
  return Dialog(
    backgroundColor: thirdColor,
    shadowColor: fourthColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
    child: Container(
      constraints: const BoxConstraints(maxHeight: 450),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Center(
                child: Text(
                  "-Islamic Calendar-",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                ),
              ),
              Center(
                child: DataTable(columns: const [
                  DataColumn(
                    label: Text('Number',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                  ),
                  DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                  ),
                ], rows: datarows),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
