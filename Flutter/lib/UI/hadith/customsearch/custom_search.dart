import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/hadith/customsearch/find_hadith_card.dart';
import 'package:muslim/shared/loading_indicator.dart';

import '../../../shared/constants.dart';
import '../../../utils/hadith_utils.dart';
import 'landing_default_page.dart';

class HadithCustomSearchClass extends StatefulWidget {
  const HadithCustomSearchClass({super.key});

  @override
  State<HadithCustomSearchClass> createState() =>
      _HadithCustomSearchClassState();
}

class _HadithCustomSearchClassState extends State<HadithCustomSearchClass> {
  bool isLoading = false;
  bool searched = false;
  List<HadithCustomSearchObject> hadithList = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSearchDialogAndFetchResults();
    });
  }

  Future<void> _showSearchDialogAndFetchResults() async {
    // Ensure the context is still valid before showing the dialog
    if (!mounted) return;

    String? results = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: Colors.grey[200],
        title: Column(
          children: [
            Center(
                child: Text('Hadith_CustomSerach_Dialogue_Title'.tr())),
            const Divider(),
          ],
        ),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
              hintText: "Hadith_CustomSearch_Dialogue_TextField".tr(),
              hintStyle: TextStyle(color: Colors.grey)),
          style: TextStyle(color: Colors.black),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Cancel').tr()),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, searchController.text),
              child: const Text('Search').tr()),
        ],
      ),
    );
    if (results != null) {
      if (!mounted) return; // Check mounted again before calling setState
      setState(() {
        isLoading = true;
      });
      hadithList = await getSimilarHadith(results);
      if (!mounted) return; // And again
      setState(() {
        isLoading = false;
        searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hadith_CustomSearch_Page_Title',
          style: TextStyle(color: textColor),
        ).tr(),
        iconTheme: const IconThemeData(color: textColor),
        backgroundColor: primaryColor,
      ),
      backgroundColor: thirdColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showSearchDialogAndFetchResults,
        backgroundColor: primaryColor,
        child: const Icon(
          Icons.search,
          color: textColor,
        ),
      ),
      body: isLoading
          ? const LoadingIndicator()
          : searched && hadithList.isEmpty
              ? const CustomSearchLandingPageClass(
                  text: "Custom_Search_Empty_Page_Text",
                )
              : hadithList.isEmpty
                  ? const CustomSearchLandingPageClass(
                      text: "Custom_Search_Landing_Page_Text")
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: hadithList.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              Card(
                                shadowColor: Colors.grey.shade300,
                                color: fourthColor,
                                child: FindHadithCardClass(hadith: hadithList[index]),
                              ),
                              const Divider(color: textColor,)
                            ],
                          );
                        },
                      )
                  ),
    );
  }
}
