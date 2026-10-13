import "dart:async";
import "dart:convert";

import "package:easy_localization/easy_localization.dart";
import "package:flutter/foundation.dart";
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:muslim/shared/constants.dart" as constants;
import "package:http/http.dart" as http;
import "package:muslim/utils/helper.dart" as helper;

class HadithCustomSearchObject {
  String hadith;
  String narrator;
  String muhaddith;
  String source;
  String page;
  String ruling;
  HadithCustomSearchObject({
    this.hadith = "",
    this.narrator = "",
    this.muhaddith = "",
    this.source = "",
    this.page = "",
    this.ruling = "",
  });
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
  try {
    // Browsers cannot use the native DNS probe. The request below handles
    // connection failures through its existing error handling.
    if (!kIsWeb && await helper.networkAccess() == false) {
      EasyLoading.showError(
        "No_Internet_Error".tr(),
        duration: const Duration(seconds: 15),
        dismissOnTap: true,
      );
      return null;
    }
    http.Response r = await http.get(
      Uri.parse('${constants.MUSLIM_API_URL}hadith/get_random_hadith'),
      headers: {"Access-Control-Allow-Origin": "*"},
    );
    if (r.statusCode != 200) {
      return null;
    }
    final dynamic decoded = jsonDecode(utf8.decode(r.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final RandomHadith hadith = RandomHadith.fromJson(decoded);
    return hadith.hadith.isEmpty ? null : hadith;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    EasyLoading.showError(
      e.toString(),
      duration: const Duration(seconds: 15),
      dismissOnTap: true,
    );
    return null;
  }
}

class HadithSearchException implements Exception {
  const HadithSearchException();
}

Future<List<HadithCustomSearchObject>> getSimilarHadith(
  String key, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final query = key.trim();
  if (query.isEmpty) return [];
  try {
    final uri = Uri.parse(
      '${constants.MUSLIM_API_URL}hadith/find_hadith',
    ).replace(queryParameters: {'searchQuery': query});
    final response = await (client?.get(uri) ?? http.get(uri)).timeout(timeout);
    if (response.statusCode != 200) throw const HadithSearchException();
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded['results'] is! List) {
      throw const HadithSearchException();
    }
    return (decoded['results'] as List).map((dynamic item) {
      if (item is! Map ||
          item['hadith'] is! String ||
          (item['hadith'] as String).trim().isEmpty) {
        throw const HadithSearchException();
      }
      return HadithCustomSearchObject(
        hadith: item['hadith'] as String,
        narrator: item['narrator']?.toString() ?? '',
        muhaddith: item['muhaddith']?.toString() ?? '',
        source: item['source']?.toString() ?? '',
        page: item['page']?.toString() ?? '',
        ruling: item['ruling']?.toString() ?? '',
      );
    }).toList();
  } catch (_) {
    throw const HadithSearchException();
  }
}
