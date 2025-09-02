import "dart:convert";

import "package:flutter/foundation.dart";
import "package:muslim/shared/constants.dart" as constants;
import "package:http/http.dart" as http;

class HadithCustomSearchObject{
  String hadith;
  String narrator;
  String muhaddith;
  String source;
  String page;
  String ruling;
  HadithCustomSearchObject({this.hadith = "", this.narrator = "", this.muhaddith = "", this.source = "", this.page = "", this.ruling = ""});
}

Future<String> getRandomHadith() async {
  http.Response r = await http.get(Uri.parse('${constants.MUSLIM_API_URL}/hadith/get_random_hadith'));
  if(r.statusCode != 200){
    return "";
  }
  try{
    dynamic jsonData = jsonDecode(utf8.decode(r.bodyBytes));
    return jsonData["diacritics"];
  }catch(e){
    if(kDebugMode){
      print(e);
    }
    return "";
  }
}

Future<List<HadithCustomSearchObject>> getSimilarHadith(String key) async{
  http.Response r = await http.get(Uri.parse('${constants.MUSLIM_API_URL}/hadith/find_hadith?searchQuery=$key'));
  if(r.statusCode != 200){
    return [];
  }
  try {
    Map<String, dynamic> jsonData = jsonDecode(utf8.decode(r.bodyBytes));
    print(jsonData);
    if(!jsonData.containsKey("results")){
      return [];
    }
    List<HadithCustomSearchObject> listOfHadiths = [];
    // append
    for(int i = 0; i < jsonData["results"].length; i++){
      HadithCustomSearchObject hadith = HadithCustomSearchObject(
        hadith: jsonData["results"][i]["hadith"]??"",
        narrator: jsonData["results"][i]["narrator"]??"",
        muhaddith: jsonData["results"][i]["muhaddith"]??"",
        source: jsonData["results"][i]["source"]??"",
        page: jsonData["results"][i]["page"]??"",
        ruling: jsonData["results"][i]["ruling"]??"",
      );
      if (kDebugMode) {
        print(jsonData["results"][i]);
      }
      listOfHadiths.add(hadith);
    }
    return listOfHadiths;
  }catch (e){
    if(kDebugMode){
      print(e);
    }
    return [];
  }
}