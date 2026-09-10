import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'pilgrimage_models.dart';

bool pilgrimageArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';
String pilgrimageLabel(BuildContext context, String en, String ar) =>
    pilgrimageArabic(context) ? ar : en;

class PilgrimageSources extends StatelessWidget {
  const PilgrimageSources({super.key, required this.sources});
  final List<PilgrimageSource> sources;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 32),
      Text(
        pilgrimageLabel(context, 'Sources and verification', 'المصادر والتحقق'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        pilgrimageLabel(
          context,
          'References stay available offline. Reading the linked pages requires internet.',
          'المراجع متاحة دون اتصال. قراءة الصفحات المرتبطة تتطلب الإنترنت.',
        ),
      ),
      for (final source in sources)
        SourceCitation(source: source, expanded: true),
    ],
  );
}

class SourceCitation extends StatelessWidget {
  const SourceCitation({
    super.key,
    required this.source,
    this.expanded = false,
  });
  final PilgrimageSource source;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ar = pilgrimageArabic(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(source.title.resolve(ar)),
      subtitle: expanded ? Text(source.status.resolve(ar)) : null,
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SourceReader(source: source),
      ),
    );
  }
}

class SourceReader extends StatefulWidget {
  const SourceReader({super.key, required this.source});
  final PilgrimageSource source;
  @override
  State<SourceReader> createState() => _SourceReaderState();
}

class _SourceReaderState extends State<SourceReader> {
  bool _busy = false;
  String? _error;

  Future<void> _open(LaunchMode mode) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(widget.source.url);
      // A launched browser does not report offline failures to Flutter. Check
      // reachability first on native platforms; web HEAD is subject to CORS.
      if (!kIsWeb) {
        await http.head(uri).timeout(const Duration(seconds: 6));
      }
      if (!mounted) return;
      if (!await launchUrl(uri, mode: mode)) {
        throw StateError('No browser available');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = pilgrimageLabel(
            context,
            'Could not open the source. Check your connection or try your browser. The reference remains below.',
            'تعذر فتح المصدر. تحقق من الاتصال أو جرب المتصفح. المرجع محفوظ أدناه.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = pilgrimageArabic(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.source.title.resolve(ar),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(widget.source.status.resolve(ar)),
          const SizedBox(height: 12),
          SelectableText(widget.source.url, textDirection: TextDirection.ltr),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, semanticsLabel: _error),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _open(LaunchMode.inAppBrowserView),
            icon: const Icon(Icons.menu_book),
            label: Text(
              pilgrimageLabel(context, 'Read source', 'قراءة المصدر'),
            ),
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => _open(LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser),
            label: Text(
              pilgrimageLabel(context, 'Open in browser', 'فتح في المتصفح'),
            ),
          ),
        ],
      ),
    );
  }
}
