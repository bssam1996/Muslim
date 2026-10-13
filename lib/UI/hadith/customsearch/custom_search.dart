import 'package:muslim/shared/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/hadith/customsearch/find_hadith_card.dart';
import 'package:muslim/shared/loading_indicator.dart';
import 'package:muslim/shared/retry_notice.dart';

import '../../../utils/hadith_utils.dart';
import 'landing_default_page.dart';

class HadithCustomSearchClass extends StatefulWidget {
  const HadithCustomSearchClass({super.key, this.search});
  final Future<List<HadithCustomSearchObject>> Function(String)? search;

  @override
  State<HadithCustomSearchClass> createState() =>
      _HadithCustomSearchClassState();
}

class _HadithCustomSearchClassState extends State<HadithCustomSearchClass> {
  bool isLoading = false;
  bool searched = false;
  List<HadithCustomSearchObject> hadithList = [];
  TextEditingController searchController = TextEditingController();
  bool _searchOpen = false;
  bool _failed = false;
  String _lastQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSearchDialogAndFetchResults();
    });
  }

  Future<void> _showSearchDialogAndFetchResults() async {
    // Ensure the context is still valid before showing the dialog
    if (!mounted || isLoading || _searchOpen) return;
    _searchOpen = true;

    String? results = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        backgroundColor: AppPalette.of(context).panel,
        title: Column(
          children: [
            Center(child: Text('Hadith_CustomSerach_Dialogue_Title'.tr())),
            const Divider(),
          ],
        ),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: "Hadith_CustomSearch_Dialogue_TextField".tr(),
            hintStyle: const TextStyle(color: Colors.grey),
          ),
          style: TextStyle(color: AppPalette.of(context).text),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel').tr(),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, searchController.text),
            child: const Text('Search').tr(),
          ),
        ],
      ),
    );
    _searchOpen = false;
    if (!mounted || results == null || results.trim().isEmpty) return;
    await _search(results.trim());
  }

  Future<void> _search(String query) async {
    if (!mounted || isLoading) return;
    setState(() {
      isLoading = true;
      _failed = false;
      _lastQuery = query;
    });
    try {
      final results =
          await (widget.search?.call(query) ?? getSimilarHadith(query));
      if (!mounted) return;
      setState(() {
        hadithList = results;
        searched = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hadith_CustomSearch_Page_Title',
          style: TextStyle(color: AppPalette.of(context).text),
        ).tr(),
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
        backgroundColor: AppPalette.of(context).canvas,
      ),
      backgroundColor: AppPalette.of(context).panel,
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : _showSearchDialogAndFetchResults,
        backgroundColor: AppPalette.of(context).canvas,
        child: Icon(Icons.search, color: AppPalette.of(context).text),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RetryNotice(
                  message: 'Hadith_Search_Error'.tr(),
                  onRetry: () => _search(_lastQuery),
                ),
              ),
            Expanded(
              child: isLoading
                  ? const LoadingIndicator()
                  : searched && hadithList.isEmpty
                  ? const CustomSearchLandingPageClass(
                      text: "Custom_Search_Empty_Page_Text",
                    )
                  : hadithList.isEmpty
                  ? const CustomSearchLandingPageClass(
                      text: "Custom_Search_Landing_Page_Text",
                    )
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
                                color: AppPalette.of(context).muted,
                                child: FindHadithCardClass(
                                  hadith: hadithList[index],
                                ),
                              ),
                              Divider(color: AppPalette.of(context).text),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
