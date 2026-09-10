import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/dua/dua_items.dart';
import 'package:muslim/UI/dua/dua_search.dart';
import 'package:muslim/shared/constants.dart';

class DuaSearchableList extends StatefulWidget {
  const DuaSearchableList({
    super.key,
    required this.items,
    required this.onOpen,
    this.additionalSearchableTerms,
  });

  final List<DuaItem> items;
  final void Function(BuildContext context, DuaItem item) onOpen;
  final Iterable<String> Function(DuaItem item)? additionalSearchableTerms;

  @override
  State<DuaSearchableList> createState() => _DuaSearchableListState();
}

class _DuaSearchableListState extends State<DuaSearchableList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DuaItem> get _filteredDuas {
    return widget.items.where((DuaItem item) {
      return DuaSearch.matches(_searchQuery, <String>[
        ...DuaSearch.titleTerms(item.title),
        item.description,
        item.data,
        ...?widget.additionalSearchableTerms?.call(item),
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<DuaItem> filteredDuas = _filteredDuas;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _searchController,
            onChanged: (String value) {
              setState(() => _searchQuery = value);
            },
            style: const TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Dua_Search_Hint'.tr(),
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: textColor),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Dua_Search_Clear'.tr(),
                      icon: const Icon(Icons.clear, color: textColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              filled: true,
              fillColor: primaryColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: highlightedTextColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: highlightedTextColor,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredDuas.isEmpty
                ? Center(
                    child: Text(
                      'Dua_Search_No_Results'.tr(),
                      style: const TextStyle(color: textColor, fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: filteredDuas.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DuaItem item = filteredDuas[index];
                      return Column(
                        children: <Widget>[
                          Card(
                            shadowColor: Colors.grey.shade300,
                            color: fourthColor,
                            child: ListTile(
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: textColor,
                                ),
                              ).tr(),
                              onTap: () => widget.onOpen(context, item),
                            ),
                          ),
                          const Divider(color: textColor),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
