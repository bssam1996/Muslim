import 'package:shared_preferences/shared_preferences.dart';

class BookBookmarks {
  BookBookmarks(this.preferences);

  final SharedPreferences preferences;

  String _key(String bookId) => 'biography_bookmarks_$bookId';

  Set<int> load(String bookId) => {
    for (final value in preferences.getStringList(_key(bookId)) ?? <String>[])
      if (int.tryParse(value) case final int page when page > 0) page,
  };

  Future<void> save(String bookId, Set<int> pages) async {
    final sorted = pages.where((page) => page > 0).toList()..sort();
    final saved = await preferences.setStringList(
      _key(bookId),
      sorted.map((page) => '$page').toList(),
    );
    if (!saved) throw StateError('Could not save bookmarks');
  }
}
