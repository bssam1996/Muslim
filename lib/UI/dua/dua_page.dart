import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/dua/dua_card_page.dart';
import 'package:muslim/UI/dua/dua_collection_page.dart';
import 'package:muslim/UI/dua/dua_items.dart';
import 'package:muslim/UI/dua/dua_list.dart';
import 'package:muslim/UI/dua/dua_search.dart';
import 'package:muslim/shared/constants.dart';

class DuaPageClass extends StatelessWidget {
  const DuaPageClass({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dua_Page_Title',
          style: TextStyle(color: textColor),
        ).tr(),
        iconTheme: const IconThemeData(color: textColor),
        backgroundColor: primaryColor,
      ),
      backgroundColor: thirdColor,
      body: SafeArea(
        child: DuaSearchableList(
          items: duaItems,
          additionalSearchableTerms: _categorySearchableTerms,
          onOpen: _openItem,
        ),
      ),
    );
  }

  static Iterable<String> _categorySearchableTerms(DuaItem item) sync* {
    List<DuaItem>? relatedItems;
    if (item.title == 'Dua_Umrah') {
      relatedItems = umrahDuaItems;
    } else if (item.title == 'Dua_Hajj') {
      relatedItems = hajjDuaItems;
    }

    if (relatedItems == null) {
      return;
    }

    for (final DuaItem relatedItem in relatedItems) {
      yield* DuaSearch.titleTerms(relatedItem.title);
      yield relatedItem.description;
      yield relatedItem.data;
    }
  }

  static void _openItem(BuildContext context, DuaItem item) {
    List<DuaItem>? relatedItems;
    if (item.title == 'Dua_Umrah') {
      relatedItems = umrahDuaItems;
    } else if (item.title == 'Dua_Hajj') {
      relatedItems = hajjDuaItems;
    }

    if (relatedItems != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => DuaCollectionPageClass(
            titleKey: item.title,
            items: relatedItems!,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DuaCardPageClass(title: item.title.tr(), data: item.data),
      ),
    );
  }
}
