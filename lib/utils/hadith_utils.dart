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

class RandomHadith {
  const RandomHadith({
    required this.hadith,
    this.explanation = '',
    this.explanationLinks = const <String>[],
  });

  final String hadith;
  final String explanation;
  final List<String> explanationLinks;

  factory RandomHadith.fromJson(Map<String, dynamic> json) {
    return RandomHadith(
      hadith: json['diacritics']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      explanationLinks: _parseExplanationLinks(json['explaination_links']),
    );
  }

  static List<String> _parseExplanationLinks(dynamic value) {
    final List<String> links = <String>[];

    void addLinks(dynamic item) {
      if (item is Iterable) {
        for (final dynamic child in item) {
          addLinks(child);
        }
      } else if (item is Map) {
        for (final dynamic child in item.values) {
          addLinks(child);
        }
      } else if (item != null) {
        final String link = item.toString().trim();
        final Uri? uri = Uri.tryParse(link);
        if (link.isNotEmpty &&
            uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            !links.contains(link)) {
          links.add(link);
        }
      }
    }

    addLinks(value);
    return List<String>.unmodifiable(links);
  }
}

Future<RandomHadith?> getRandomHadith() async {
  try{
    if(await helper.networkAccess() == false){
        EasyLoading.showError("No_Internet_Error".tr(),
            duration: const Duration(seconds: 15), dismissOnTap: true);
        return null;
    }
    http.Response r = await http.get(Uri.parse('${constants.MUSLIM_API_URL}hadith/get_random_hadith'), headers: {"Access-Control-Allow-Origin": "*"});
    if(r.statusCode != 200){
      return null;
    }
    final dynamic decoded = jsonDecode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final RandomHadith hadith = RandomHadith.fromJson(decoded);
    return hadith.hadith.isEmpty ? null : hadith;
  }catch(e){
    if(kDebugMode){
      print(e);
    }
    EasyLoading.showError(e.toString(),
            duration: const Duration(seconds: 15), dismissOnTap: true);
    return null;
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
