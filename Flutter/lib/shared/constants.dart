import 'package:flutter/material.dart';

const primaryColor = Color.fromRGBO(4, 28, 50, 1);
const secondaryColor = Color.fromRGBO(40, 42, 58, 1);
const thirdColor = Color.fromRGBO(4, 41, 85, 1);
const fourthColor = Color.fromRGBO(6, 70, 99, 1);
const highlightedColor = Color.fromRGBO(236, 179, 101, 1);
const textColor = Color.fromRGBO(255, 255, 255, 1);
const dividerColor = Colors.white24;
const boxesBorderColor = Color.fromRGBO(10, 98, 140, 1.0);

String declaration = "*Please note that prayer timings might not always match your local mosque or government authority. Their timings are likely tuned or adjusted.";

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