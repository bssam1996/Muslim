import 'package:flutter/material.dart';

const MUSLIM_API_URL = "https://muslim-api-mu.vercel.app/";
const MUSLIM_GOOGLE_PLAY_URI = "https://play.google.com/store/apps/details?id=com.bplusplus.muslim";
const primaryColor = Color.fromRGBO(23, 21, 59, 1.0);
const secondaryColor = Color.fromRGBO(40, 42, 58, 1);
const thirdColor = Color.fromRGBO(55, 48, 107, 1.0);
const fourthColor = Color.fromRGBO(122, 133, 193, 1.0);
const interpolatedColor1 = Color.fromRGBO(68, 65, 124, 1.0);
const interpolatedColor2 = Color.fromRGBO(82, 82, 141, 1.0);
const interpolatedColor3 = Color.fromRGBO(95, 99, 159, 1.0);
const interpolatedColor4 = Color.fromRGBO(109, 116, 176, 1.0);
const interpolatedColor5 = Color.fromRGBO(31, 28, 71, 1.0);
const interpolatedColor6 = Color.fromRGBO(39, 35, 83, 1.0);
const interpolatedColor7 = Color.fromRGBO(47, 41, 95, 1.0);
const highlightedMonthDayColor = Color.fromRGBO(14, 107, 159, 1.0);
const highlightedColor = Color.fromRGBO(99, 164, 175, 1.0);
const highlightedTextColor = Color.fromRGBO(146, 232, 246, 1.0);
const textColor = Color.fromRGBO(255, 255, 255, 1);
const dividerColor = Colors.white24;
const highlightedBoxesBorderColor = Color.fromRGBO(146, 232, 246, 1.0);
const boxesBorderColor = Color.fromRGBO(7, 88, 126, 1.0);

const settingsWidgetBGColor = Color.fromRGBO(39, 35, 83, 1.0);

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
int NUMBER_OF_DAYS = 7;

List<String> PRAYER_NAMES = [
  'Fajr',
  'Sunrise',
  'Dhuhr',
  'Asr',
  'Maghrib',
  'Isha'
];