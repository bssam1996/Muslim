import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dua_catalog.dart';
import 'dua_style.dart';

class DuaSourceIndex extends StatelessWidget {
  const DuaSourceIndex({super.key, required this.catalog});
  final DuaCatalog catalog;
  @override
  Widget build(BuildContext context) => DuaStyle(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(dl(context, 'Library sources', 'مصادر المكتبة')),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: DuaSources(sources: catalog.sourcesFor(catalog.entries)),
          ),
        ),
      ),
    ),
  );
}

class DuaSources extends StatelessWidget {
  const DuaSources({super.key, required this.sources});
  final List<DuaSource> sources;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      Text(
        dl(context, 'Sources and verification', 'المصادر والتحقق'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        dl(
          context,
          'Citations are available offline. Linked pages require internet.',
          'المراجع متاحة دون إنترنت. الصفحات المرتبطة تتطلب الاتصال.',
        ),
      ),
      for (final source in sources)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(dt(context, source.title)),
          subtitle: Text(dt(context, source.authority)),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => DuaStyle(child: DuaSourceReader(source: source)),
          ),
        ),
    ],
  );
}

class DuaSourceReader extends StatefulWidget {
  const DuaSourceReader({super.key, required this.source});
  final DuaSource source;
  @override
  State<DuaSourceReader> createState() => _DuaSourceReaderState();
}

class _DuaSourceReaderState extends State<DuaSourceReader> {
  bool _busy = false, _error = false;
  Future<void> _open(LaunchMode mode) async {
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      // Open directly: a server rejecting HEAD is not proof a browser cannot read it.
      final opened = await launchUrl(Uri.parse(widget.source.url), mode: mode);
      if (mounted) setState(() => _error = !opened);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dt(context, widget.source.title),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(dt(context, widget.source.authority)),
          Text(dt(context, widget.source.narrator)),
          const SizedBox(height: 12),
          SelectableText(widget.source.url, textDirection: TextDirection.ltr),
          if (_busy) const LinearProgressIndicator(),
          if (_error)
            Text(
              dl(
                context,
                'Could not open the source. Check your connection or try the browser.',
                'تعذر فتح المصدر. تحقق من الاتصال أو جرّب المتصفح.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _open(LaunchMode.inAppBrowserView),
                child: Text(dl(context, 'Read source', 'قراءة المصدر')),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _open(LaunchMode.externalApplication),
                child: Text(dl(context, 'Open in browser', 'فتح في المتصفح')),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(dl(context, 'Copy citation', 'نسخ المرجع')),
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${dt(context, widget.source.title)}\n${widget.source.url}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            dl(context, 'Citation copied', 'تم نسخ المرجع'),
                          ),
                        ),
                      );
                    }
                  } catch (_) {
                    if (mounted) setState(() => _error = true);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
