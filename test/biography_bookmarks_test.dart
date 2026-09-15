import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/biographies/book_bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'bookmarks persist independently for the full book and summary',
    () async {
      final store = BookBookmarks(await SharedPreferences.getInstance());
      await store.save('ibn_kathir_full', {42, 7});
      await store.save('ibn_kathir_summary', {3});

      final reopened = BookBookmarks(await SharedPreferences.getInstance());
      expect(reopened.load('ibn_kathir_full'), {7, 42});
      expect(reopened.load('ibn_kathir_summary'), {3});
      await reopened.save('ibn_kathir_full', {42});
      expect(store.load('ibn_kathir_full'), {42});
      expect(store.load('ibn_kathir_summary'), {3});
      await reopened.save('ibn_kathir_full', {});
      expect(store.load('ibn_kathir_full'), isEmpty);
    },
  );

  test(
    'invalid stored page numbers are ignored and repeated pages appear once',
    () async {
      SharedPreferences.setMockInitialValues({
        'biography_bookmarks_ibn_kathir_full': [
          '0',
          '-1',
          'invalid',
          '4',
          '4',
          '21',
        ],
      });
      final store = BookBookmarks(await SharedPreferences.getInstance());
      expect(store.load('ibn_kathir_full'), {4, 21});
      expect(store.load('ibn_kathir_summary'), isEmpty);
    },
  );
}
