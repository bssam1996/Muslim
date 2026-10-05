import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../biographies/biography_catalog.dart';
import 'library_book.dart';
import '../biographies/biography_scaffold.dart';
import '../biographies/book_bookmarks.dart';
import '../biographies/storage/book_storage.dart';

Future<void> validateBookPdf(StoredBook book) async {
  await pdfrxFlutterInitialize();
  final document = book.path != null
      ? await PdfDocument.openFile(book.path!)
      : await PdfDocument.openData(book.bytes!);
  try {
    if (document.pages.isEmpty) throw const FormatException('Empty PDF');
  } finally {
    await document.dispose();
  }
}

class BookReaderPage extends StatefulWidget {
  const BookReaderPage({
    super.key,
    required this.book,
    this.author,
    this.sectionTitleKey,
    required this.stored,
  }) : assert(author != null || sectionTitleKey != null);

  final LibraryBook book;
  final BiographyAuthor? author;
  final String? sectionTitleKey;
  final StoredBook stored;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final _controller = PdfViewerController();
  SharedPreferences? _preferences;
  bool _loading = true;
  int _initialPage = 1;
  int _page = 1;
  int _pageCount = 0;
  Set<int> _bookmarks = {};
  bool _savingBookmark = false;
  bool _bookmarksLoaded = false;

  String get _positionKey => 'biography_page_${widget.book.id}';

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _initialPage = _preferences?.getInt(_positionKey) ?? 1;
      _bookmarks = BookBookmarks(_preferences!).load(widget.book.id);
      _bookmarksLoaded = true;
    } catch (_) {
      // Reading is still available if preferences cannot be accessed.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePosition(int page) async {
    try {
      await _preferences?.setInt(_positionKey, page);
    } catch (_) {
      // Do not interrupt reading if persisting the position fails.
    }
  }

  Future<void> _changeBookmark(int page, bool add) async {
    if (_savingBookmark) return;
    setState(() => _savingBookmark = true);
    try {
      final preferences = _preferences ??=
          await SharedPreferences.getInstance();
      final store = BookBookmarks(preferences);
      // Retry loading before writing if the initial preferences read failed.
      final updated = Set<int>.of(
        _bookmarksLoaded ? _bookmarks : store.load(widget.book.id),
      );
      if (add) {
        updated.add(page);
      } else {
        updated.remove(page);
      }
      await store.save(widget.book.id, updated);
      if (!mounted) return;
      setState(() {
        _bookmarks = updated;
        _bookmarksLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biography_Bookmark_Save_Error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBookmark = false);
    }
  }

  Future<void> _showBookmarks(BuildContext sheetContext) async {
    if (!_bookmarksLoaded) {
      try {
        final preferences = _preferences ??=
            await SharedPreferences.getInstance();
        final pages = BookBookmarks(preferences).load(widget.book.id);
        if (!mounted || !sheetContext.mounted) return;
        setState(() {
          _bookmarks = pages;
          _bookmarksLoaded = true;
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biography_Bookmark_Load_Error'.tr())),
          );
        }
        return;
      }
    }
    if (!sheetContext.mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: sheetContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          final pages = _bookmarks.toList()..sort();
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Biography_Bookmarks'.tr(),
                            style: biographyHeadingStyle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Biography_Close_Bookmarks'.tr(),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (pages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Biography_No_Bookmarks'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: pages.length,
                          itemBuilder: (context, index) {
                            final page = pages[index];
                            final available = page <= _pageCount;
                            return ListTile(
                              leading: const Icon(Icons.bookmark),
                              title: Text(
                                'Biography_Bookmark_Page'.tr(
                                  namedArgs: {'page': '$page'},
                                ),
                              ),
                              subtitle: available
                                  ? null
                                  : Text('Biography_Bookmark_Unavailable'.tr()),
                              onTap: available && !_savingBookmark
                                  ? () => Navigator.pop(context, page)
                                  : null,
                              trailing: IconButton(
                                tooltip: 'Biography_Remove_Bookmark'.tr(),
                                onPressed: _savingBookmark
                                    ? null
                                    : () async {
                                        final pending = _changeBookmark(
                                          page,
                                          false,
                                        );
                                        refresh(() {});
                                        await pending;
                                        if (context.mounted) refresh(() {});
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (mounted && selected != null && _controller.isReady) {
      await _controller.goToPage(pageNumber: selected);
    }
  }

  Future<void> _jumpToPage(BuildContext dialogContext) async {
    var enteredPage = '$_page';
    final form = GlobalKey<FormState>();
    final selected = await showDialog<int>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text('Biography_Go_To_Page'.tr()),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: enteredPage,
            onChanged: (value) => enteredPage = value,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Biography_Page_Number'.tr(),
            ),
            validator: (value) {
              final page = _parsePage(value ?? '');
              return page == null || page < 1 || page > _pageCount
                  ? 'Biography_Invalid_Page'.tr(
                      namedArgs: {'total': '$_pageCount'},
                    )
                  : null;
            },
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(context, _parsePage(enteredPage));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Biography_Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, _parsePage(enteredPage));
              }
            },
            child: Text('Biography_Go'.tr()),
          ),
        ],
      ),
    );
    if (mounted && selected != null && _controller.isReady) {
      await _controller.goToPage(pageNumber: selected);
    }
  }

  int? _parsePage(String value) {
    var normalized = value.trim();
    for (var i = 0; i < 10; i++) {
      normalized = normalized
          .replaceAll(String.fromCharCode(0x660 + i), '$i')
          .replaceAll(String.fromCharCode(0x6f0 + i), '$i');
    }
    return int.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final params = PdfViewerParams(
      // Updated editions may have fewer pages than the previous download.
      calculateInitialPageNumber: (document, controller) =>
          _initialPage.clamp(1, document.pages.length),
      onViewerReady: (document, controller) {
        if (mounted) {
          setState(() {
            _pageCount = document.pages.length;
            // The viewer may restore its page before emitting onPageChanged.
            // Keep the toolbar and bookmark state aligned with that page.
            _page = controller.pageNumber ?? _initialPage.clamp(1, _pageCount);
          });
        }
      },
      onPageChanged: (page) {
        if (!mounted || page == null) return;
        setState(() => _page = page);
        _savePosition(page);
      },
      loadingBannerBuilder: (context, received, total) =>
          const Center(child: CircularProgressIndicator()),
      errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Biography_Reader_Error'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    return BiographyScaffold(
      appBar: AppBar(
        title: Text(
          '${(widget.sectionTitleKey ?? widget.author!.nameKey).tr()} · ${widget.book.titleKey.tr()}',
        ),
        actions: [
          IconButton(
            tooltip:
                (_bookmarks.contains(_page)
                        ? 'Biography_Remove_Bookmark'
                        : 'Biography_Add_Bookmark')
                    .tr(),
            onPressed: _pageCount == 0 || _savingBookmark
                ? null
                : () => _changeBookmark(_page, !_bookmarks.contains(_page)),
            icon: Icon(
              _bookmarks.contains(_page)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Biography_Bookmarks'.tr(),
              onPressed: _pageCount == 0 || _savingBookmark
                  ? null
                  : () => _showBookmarks(context),
              icon: const Icon(Icons.bookmarks_outlined),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.stored.path != null
          ? PdfViewer.file(
              widget.stored.path!,
              controller: _controller,
              params: params,
              useProgressiveLoading: false,
            )
          : PdfViewer.data(
              widget.stored.bytes!,
              sourceName: widget.book.id,
              controller: _controller,
              params: params,
              useProgressiveLoading: false,
            ),
      bottomNavigationBar: _pageCount == 0
          ? null
          : SafeArea(
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Biography_Previous_Page'.tr(),
                    onPressed: _page > 1
                        ? () => _controller.goToPage(pageNumber: _page - 1)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => _jumpToPage(context),
                        child: Text(
                          'Biography_Page_Count'.tr(
                            namedArgs: {
                              'page': '$_page',
                              'total': '$_pageCount',
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Biography_Next_Page'.tr(),
                    onPressed: _page < _pageCount
                        ? () => _controller.goToPage(pageNumber: _page + 1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
    );
  }
}
