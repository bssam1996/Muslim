import 'package:easy_localization/easy_localization.dart';
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
        monthName?.tr() ?? "",
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
              Center(
                child: Text(
                  "Months_Helper_Title".tr(),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                ),
              ),
              Center(
                child: DataTable(columns: [
                  DataColumn(
                    label: Text('Months_Helper_Number'.tr(),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                  ),
                  DataColumn(
                    label: Text(
                      'Months_Helper_Name'.tr(),
                      style: const TextStyle(
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
