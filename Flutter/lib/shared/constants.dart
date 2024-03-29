import 'package:flutter/material.dart';

const primaryColor = Color.fromRGBO(4, 28, 50, 1);
const secondaryColor = Color.fromRGBO(40, 42, 58, 1);
const thirdColor = Color.fromRGBO(4, 41, 85, 1);
const fourthColor = Color.fromRGBO(6, 70, 99, 1);
const highlightedMonthDayColor = Color.fromRGBO(14, 107, 159, 1.0);
const highlightedColor = Color.fromRGBO(236, 179, 101, 1);
const textColor = Color.fromRGBO(255, 255, 255, 1);
const dividerColor = Colors.white24;
const boxesBorderColor = Color.fromRGBO(10, 98, 140, 1.0);
const gloabalAppName = "Muslim";
const HOME_WIDGET_GROUP_ID = "com.bplusplus.muslim";

const authorities = <String, int>{
  "Default":-1,
  "Shia Ithna-Ansari":0,
  "University of Islamic Sciences, Karachi":1,
  "Islamic Society of North America":2,
  "Muslim World League":3,
  "Umm Al-Qura University, Makkah":4,
  "Egyptian General Authority of Survey":5,
  "Institute of Geophysics, University of Tehran":7,
  "Gulf Region":8,
  "Kuwait":9,
  "Qatar":10,
  "Majlis Ugama Islam Singapura, Singapore":11,
  "Union Organization islamic de France":12,
  "Diyanet İşleri Başkanlığı, Turkey":13,
  "Spiritual Administration of Muslims of Russia":14,
};

const schools = <String, int>{
  "Shafi (Standard)":0,
  "Hanafi":1,
};

Map<int, String> hijriMonthsNames = {
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