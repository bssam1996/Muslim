import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/dua/dua_card_page.dart';
import 'package:muslim/UI/dua/dua_collection_page.dart';
import 'package:muslim/UI/dua/dua_items.dart';
import 'package:muslim/UI/dua/dua_list.dart';
import 'package:muslim/shared/constants.dart';

class LegacyDuaPageClass extends StatelessWidget {
  const LegacyDuaPageClass({super.key});

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
        child: DuaSearchableList(items: duaItems, onOpen: _openItem),
      ),
    );
  }

  static void _openItem(BuildContext context, DuaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DuaCardPageClass(title: item.title.tr(), data: item.data),
      ),
    );
  }
}
