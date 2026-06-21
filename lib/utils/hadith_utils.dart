import "dart:convert";

import "package:easy_localization/easy_localization.dart";
import "package:flutter/foundation.dart";
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:muslim/shared/constants.dart" as constants;
import "package:http/http.dart" as http;
import "package:muslim/utils/helper.dart" as helper;

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
  try{
    if(await helper.networkAccess() == false){
        EasyLoading.showError("No_Internet_Error".tr(),
            duration: const Duration(seconds: 15), dismissOnTap: true);
        return "";
    }
    http.Response r = await http.get(Uri.parse('${constants.MUSLIM_API_URL}hadith/get_random_hadith'), headers: {"Access-Control-Allow-Origin": "*"});
    if(r.statusCode != 200){
      return "";
    }
    dynamic jsonData = jsonDecode(utf8.decode(r.bodyBytes));
    return jsonData["diacritics"];
  }catch(e){
    if(kDebugMode){
      print(e);
    }
    EasyLoading.showError(e.toString(),
            duration: const Duration(seconds: 15), dismissOnTap: true);
    return "";
  }
}

Future<List<HadithCustomSearchObject>> getSimilarHadith(String key) async{
  http.Response r = await http.get(Uri.parse('${constants.MUSLIM_API_URL}hadith/find_hadith?searchQuery=$key'), headers: {"Access-Control-Allow-Origin": "*"});
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