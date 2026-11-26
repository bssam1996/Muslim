import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../biographies/biography_scaffold.dart';
import '../biographies/storage/book_storage.dart';
import 'library_book.dart';
import 'book_download.dart';
import 'book_reader_page.dart';

class LibraryBooksPage extends StatefulWidget {
  const LibraryBooksPage({
    super.key,
    required this.titleKey,
    required this.slots,
    this.header,
    this.backgroundAsset,
    this.storage,
    this.validator,
    this.downloadFactory,
  });

  final String titleKey;
  final List<LibraryBookSlot> slots;
  final Widget? header;
  final String? backgroundAsset;
  final BookStorage? storage;
  final BookValidator? validator;
  final BookDownload Function()? downloadFactory;

  @override
  State<LibraryBooksPage> createState() => _LibraryBooksPageState();
}

class _LibraryBooksPageState extends State<LibraryBooksPage> {
  late final BookStorage _storage = widget.storage ?? createBookStorage();
  final Set<String> _downloaded = {};
  final Map<String, String> _selectedEditionIds = {};
  bool _loading = true;
  bool _storageError = false;
  String? _activeId;
  String? _errorId;
  String? _errorKey;
  BookDownload? _download;
  int _received = 0;
  int? _total;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _loading = true;
      _storageError = false;
    });
    try {
      final ids = <String>{};
      for (final book in widget.slots.expand((slot) => slot.editions)) {
        if (await _storage.contains(book.id)) ids.add(book.id);
      }
      if (!mounted) return;
      setState(() {
        _downloaded.clear();
        _downloaded.addAll(ids);
      });
    } catch (_) {
      if (mounted) setState(() => _storageError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadBook(LibraryBook book) async {
    if (_activeId != null || !book.available) return;
    final download = widget.downloadFactory?.call() ?? BookDownload();
    setState(() {
      _download = download;
      _activeId = book.id;
      _errorId = null;
      _errorKey = null;
      _received = 0;
      _total = null;
      _validating = false;
    });
    try {
      await download.run(
        book: book,
        storage: _storage,
        validate: (stored) async {
          if (mounted) setState(() => _validating = true);
          await (widget.validator ?? validateBookPdf)(stored);
        },
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => _downloaded.add(book.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Biography_Download_Complete'.tr())),
      );
    } on BookDownloadCancelled {
      // The original file remains available after cancellation.
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorId = book.id;
          _errorKey = _downloaded.contains(book.id)
              ? 'Biography_Update_Error'
              : 'Biography_Download_Error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeId = null;
          _download = null;
        });
      }
    }
  }

  Future<void> _deleteBook(LibraryBook book) async {
    if (_activeId != null) return;
    setState(() {
      _activeId = book.id;
      _errorId = null;
      _errorKey = null;
    });
    try {
      await _storage.delete(book.id);
      if (!mounted) return;
      setState(() => _downloaded.remove(book.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Biography_Delete_Complete'.tr())));
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorId = book.id;
          _errorKey = 'Biography_Delete_Error';
        });
      }
    } finally {
      if (mounted) setState(() => _activeId = null);
    }
  }

  Future<void> _read(LibraryBook book) async {
    if (_activeId != null) return;
    setState(() {
      _activeId = book.id;
      _errorId = null;
      _errorKey = null;
    });
    try {
      final stored = await _storage.read(book.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookReaderPage(
            book: book,
            sectionTitleKey: widget.titleKey,
            stored: stored,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorId = book.id;
          _errorKey = 'Biography_Reader_Error';
        });
      }
    } finally {
      if (mounted) setState(() => _activeId = null);
    }
  }

  String _size(int bytes) {
    final megabytes = bytes >= 1024 * 1024;
    final amount = bytes / (megabytes ? 1024 * 1024 : 1024);
    final number = NumberFormat(
      megabytes ? '0.#' : '0',
      context.locale.toString(),
    ).format(amount);
    return (megabytes ? 'Biography_Size_MB' : 'Biography_Size_KB').tr(
      namedArgs: {'size': number},
    );
  }

  Widget _bookCard(LibraryBookSlot slot, LibraryBook book) {
    final saved = _downloaded.contains(book.id);
    final downloading = _activeId == book.id && _download != null;
    final busy = _activeId != null;
    final progress = _total != null && _total! > 0
        ? (_received / _total!).clamp(0.0, 1.0)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.titleKey.tr(), style: biographyHeadingStyle),
            const SizedBox(height: 8),
            if (slot.editions.length > 1) ...[
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Books_Choose_Language'.tr(),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey('book_language_${slot.titleKey}'),
                    value: book.id,
                    isExpanded: true,
                    itemHeight: null,
                    items: [
                      for (final edition in slot.editions)
                        DropdownMenuItem(
                          value: edition.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Books_Language_${edition.language}'.tr(),
                            ),
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (id) {
                            if (id == null) return;
                            setState(
                              () => _selectedEditionIds[slot.titleKey] = id,
                            );
                          },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Books_Language'.tr(
                namedArgs: {'language': 'Books_Language_${book.language}'.tr()},
              ),
            ),
            if (book.source != null || book.sourceKey != null) ...[
              const SizedBox(height: 4),
              Text(
                'Books_Source'.tr(
                  namedArgs: {'source': book.sourceKey?.tr() ?? book.source!},
                ),
              ),
            ],
            if (book.noteKey != null) ...[
              const SizedBox(height: 4),
              Text(book.noteKey!.tr()),
            ],
            if (book.language != context.locale.languageCode) ...[
              const SizedBox(height: 4),
              Text('Books_Language_Fallback'.tr()),
            ],
            const SizedBox(height: 8),
            Text(
              saved
                  ? 'Biography_Available_Offline'.tr()
                  : 'Biography_Download_Size'.tr(
                      namedArgs: {'size': _size(book.approximateBytes)},
                    ),
            ),
            const SizedBox(height: 16),
            if (!book.available && !saved)
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.schedule),
                label: Text('Books_Coming_Soon'.tr()),
              )
            else if (downloading) ...[
              LinearProgressIndicator(value: _validating ? null : progress),
              const SizedBox(height: 8),
              Text(
                _validating
                    ? 'Biography_Preparing'.tr()
                    : _total == null
                    ? 'Biography_Downloading'.tr(
                        namedArgs: {'size': _size(_received)},
                      )
                    : 'Biography_Download_Progress'.tr(
                        namedArgs: {
                          'received': _size(_received),
                          'total': _size(_total!),
                        },
                      ),
              ),
              TextButton(
                onPressed: () => _download?.cancel(),
                child: Text('Biography_Cancel'.tr()),
              ),
            ] else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => saved ? _read(book) : _downloadBook(book),
                    icon: Icon(
                      saved
                          ? Icons.menu_book_outlined
                          : Icons.download_outlined,
                    ),
                    label: Text(
                      (saved ? 'Biography_Read' : 'Biography_Download').tr(),
                    ),
                  ),
                  if (saved) ...[
                    OutlinedButton.icon(
                      onPressed: busy || !book.available
                          ? null
                          : () => _downloadBook(book),
                      icon: const Icon(Icons.refresh),
                      label: Text('Biography_Redownload'.tr()),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => _deleteBook(book),
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Biography_Delete_Download'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            if (_errorId == book.id && _errorKey != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorKey!.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slotCard(LibraryBookSlot slot) {
    final selectedId = _selectedEditionIds[slot.titleKey];
    final book =
        slot.editions
            .where((edition) => edition.id == selectedId)
            .firstOrNull ??
        slot.select(context.locale.languageCode);
    if (book != null) return _bookCard(slot, book);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot.titleKey.tr(), style: biographyHeadingStyle),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.schedule),
              label: Text('Books_Coming_Soon'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BiographyScaffold(
    appBar: AppBar(title: Text(widget.titleKey.tr())),
    body: Stack(
      children: [
        if (widget.backgroundAsset != null)
          PositionedDirectional(
            bottom: 16,
            end: 16,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.1,
                  child: ShaderMask(
                    shaderCallback: (rect) => const RadialGradient(
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, 0.55, 1],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      widget.backgroundAsset!,
                      width: 120,
                      height: 120,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _storageError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Biography_Storage_Error'.tr(),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _loadDownloads,
                        child: Text('Biography_Retry'.tr()),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.header != null) widget.header!,
                  Text(
                    'Biography_Choose_Book'.tr(),
                    style: biographyHeadingStyle,
                  ),
                  const SizedBox(height: 8),
                  Text('Biography_Download_Hint'.tr()),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text('Biography_Browser_Storage'.tr()),
                  ],
                  const SizedBox(height: 24),
                  for (final slot in widget.slots) _slotCard(slot),
                ],
              ),
      ],
    ),
  );
}
