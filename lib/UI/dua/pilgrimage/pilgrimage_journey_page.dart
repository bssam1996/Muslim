import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muslim/shared/constants.dart' as app;
import '../dua_search.dart';
import 'journey_route.dart';
import 'pilgrimage_content.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_routes.dart';
import 'pilgrimage_sources.dart';

class PilgrimageJourneyPage extends StatefulWidget {
  const PilgrimageJourneyPage({super.key, required this.hajj});
  final bool hajj;
  @override
  State<PilgrimageJourneyPage> createState() => _PilgrimageJourneyPageState();
}

class _PilgrimageJourneyPageState extends State<PilgrimageJourneyPage> {
  bool _journey = true;
  bool _loaded = false;
  bool _allSources = false;
  HajjType _type = HajjType.ifrad;
  String? _selected;
  String _query = '';
  final _search = TextEditingController();
  SharedPreferences? _preferences;
  String get _preferenceKey => 'pilgrimage.${widget.hajj ? 'hajj' : 'umrah'}';
  List<PilgrimageStep> get _steps =>
      widget.hajj ? hajjRoute(_type) : umrahRoute();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _preferences = prefs;
      _journey = prefs.getBool('$_preferenceKey.journey') ?? true;
      final storedType = prefs.getString('pilgrimage.hajj.type');
      _type =
          HajjType.values.where((t) => t.name == storedType).firstOrNull ??
          HajjType.ifrad;
    } catch (_) {
      // Storage is optional; all content is usable without it.
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      await _preferences?.setBool('$_preferenceKey.journey', _journey);
      if (widget.hajj) {
        await _preferences?.setString('pilgrimage.hajj.type', _type.name);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pilgrimageLabel(
                context,
                'This view could not be saved for next time.',
                'تعذر حفظ طريقة العرض للمرة القادمة.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(BuildContext context, List<PilgrimageStep> steps, int index) {
    setState(() => _selected = steps[index].id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PilgrimageStyle(
          child: JourneyStepDetails(
            steps: steps,
            initialIndex: index,
            onSelected: (id) {
              if (mounted) setState(() => _selected = id);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PilgrimageStyle(
    child: Builder(
      builder: (context) {
        final ar = pilgrimageArabic(context);
        final steps = _steps;
        final visible = steps
            .where((s) => DuaSearch.matches(_query, [s.searchTerms.join(' ')]))
            .toList();
        final sources = [...sourcesForSteps(_allSources ? steps : visible)];
        if (widget.hajj && !sources.any((s) => s.id == ritesSource.id)) {
          sources.add(ritesSource);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.hajj
                  ? pilgrimageLabel(context, 'Hajj journey', 'رحلة الحج')
                  : pilgrimageLabel(context, 'Umrah journey', 'رحلة العمرة'),
            ),
          ),
          body: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: ListView(
                        key: const PageStorageKey('pilgrimage-route'),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            pilgrimageLabel(
                              context,
                              widget.hajj
                                  ? 'Your Hajj, step by step'
                                  : 'Your Umrah, step by step',
                              widget.hajj
                                  ? 'حجك خطوة بخطوة'
                                  : 'عمرتك خطوة بخطوة',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pilgrimageLabel(
                              context,
                              'Tap a stop to read its duaa, guidance and sources. You can open any step.',
                              'اضغط على أي محطة لقراءة الدعاء والإرشادات والمصادر. يمكنك فتح أي خطوة.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                key: const ValueKey('journey-view'),
                                avatar: const Icon(Icons.route, size: 18),
                                label: Text(
                                  pilgrimageLabel(
                                    context,
                                    'Journey view',
                                    'عرض الرحلة',
                                  ),
                                ),
                                selected: _journey,
                                onSelected: (_) {
                                  setState(() => _journey = true);
                                  _save();
                                },
                              ),
                              ChoiceChip(
                                key: const ValueKey('list-view'),
                                avatar: const Icon(Icons.list, size: 18),
                                label: Text(
                                  pilgrimageLabel(
                                    context,
                                    'List view',
                                    'عرض القائمة',
                                  ),
                                ),
                                selected: !_journey,
                                onSelected: (_) {
                                  setState(() => _journey = false);
                                  _save();
                                },
                              ),
                            ],
                          ),
                          if (widget.hajj) ...[
                            const SizedBox(height: 20),
                            Text(
                              pilgrimageLabel(
                                context,
                                'Your Hajj type',
                                'نوع النسك',
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final type in HajjType.values)
                                  ChoiceChip(
                                    key: ValueKey('hajj-${type.name}'),
                                    label: Text(
                                      hajjTypeNames[type]!.resolve(ar),
                                    ),
                                    selected: type == _type,
                                    onSelected: (_) {
                                      setState(() {
                                        _type = type;
                                        _selected = null;
                                      });
                                      _save();
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(hajjTypeDescriptions[_type]!.resolve(ar)),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('journey-search'),
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              labelText: pilgrimageLabel(
                                context,
                                'Search steps or duaa (Arabic / English)',
                                'ابحث عن خطوة أو دعاء بالعربية أو الإنجليزية',
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: pilgrimageLabel(
                                        context,
                                        'Clear search',
                                        'مسح البحث',
                                      ),
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                pilgrimageLabel(
                                  context,
                                  'No matching steps.',
                                  'لا توجد خطوات مطابقة.',
                                ),
                              ),
                            ),
                          for (final step in visible)
                            JourneyStepMarker(
                              step: step,
                              number: steps.indexOf(step) + 1,
                              total: steps.length,
                              selected: step.id == _selected,
                              visual: _journey,
                              onTap: () =>
                                  _open(context, steps, steps.indexOf(step)),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            journeyNote.resolve(ar),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_query.isNotEmpty)
                            SwitchListTile.adaptive(
                              title: Text(
                                pilgrimageLabel(
                                  context,
                                  'Show all route sources',
                                  'عرض جميع مصادر المسار',
                                ),
                              ),
                              value: _allSources,
                              onChanged: (v) => setState(() => _allSources = v),
                            ),
                          PilgrimageSources(sources: sources),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    ),
  );
}

/// Scoped styling preserves the existing violet/teal palette. The root app
/// currently disables text scaling; restore the device setting for this flow.
class PilgrimageStyle extends StatelessWidget {
  const PilgrimageStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final colors = ColorScheme.fromSeed(
      seedColor: app.thirdColor,
      brightness: brightness,
      secondary: app.highlightedColor,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      appBarTheme: const AppBarTheme(
        backgroundColor: app.primaryColor,
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: colors.surface,
      inputDecorationTheme: const InputDecorationTheme(
        alignLabelWithHint: true,
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQueryData.fromView(View.of(context)).textScaler,
      ),
      child: Theme(data: theme, child: child),
    );
  }
}

class JourneyStepDetails extends StatefulWidget {
  const JourneyStepDetails({
    super.key,
    required this.steps,
    required this.initialIndex,
    this.onSelected,
  });
  final List<PilgrimageStep> steps;
  final int initialIndex;
  final ValueChanged<String>? onSelected;
  @override
  State<JourneyStepDetails> createState() => _JourneyStepDetailsState();
}

class _JourneyStepDetailsState extends State<JourneyStepDetails> {
  late int _index = widget.initialIndex;
  bool _transliteration = false;
  bool _allSources = false;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _index = index;
      _allSources = false;
    });
    // Reset after the new step has laid out. Resetting against the old content
    // lets viewport anchoring skip the next step's heading and instructions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _index == index && _scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
    widget.onSelected?.call(widget.steps[index].id);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final ar = pilgrimageArabic(context);
    return Scaffold(
      appBar: AppBar(title: Text(step.title.resolve(ar))),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              key: ValueKey('details-${step.id}'),
              controller: _scroll,
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  pilgrimageLabel(
                    context,
                    'Step ${_index + 1} of ${widget.steps.length}',
                    'الخطوة ${_index + 1} من ${widget.steps.length}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(step.stage.resolve(ar)),
                // Keep actions discoverable even when several long duaa cards
                // precede them (especially the two rak'ahs after Tawaf).
                if (step.content.any((c) => c.kind != ContentKind.instruction))
                  for (final content in step.content.where(
                    (c) => c.action != null,
                  ))
                    Card(
                      key: ValueKey('action-summary-${content.id}'),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(content.title.resolve(ar)),
                            const SizedBox(height: 4),
                            Text(
                              content.action!.resolve(ar),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (step.condition != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(step.condition!.resolve(ar)),
                    ),
                  ),
                for (final source in step.sources)
                  SourceCitation(source: source),
                if (step.content.any((c) => c.transliteration.isNotEmpty))
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      pilgrimageLabel(
                        context,
                        'Show transliteration',
                        'إظهار النطق بالحروف اللاتينية',
                      ),
                    ),
                    value: _transliteration,
                    onChanged: (v) => setState(() => _transliteration = v),
                  ),
                for (final content in step.content)
                  _ContentCard(
                    content: content,
                    transliteration: _transliteration,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('previous-step'),
                      onPressed: _index == 0 ? null : () => _go(_index - 1),
                      child: Text(
                        pilgrimageLabel(
                          context,
                          'Previous step',
                          'الخطوة السابقة',
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const ValueKey('next-step'),
                      onPressed: _index == widget.steps.length - 1
                          ? null
                          : () => _go(_index + 1),
                      child: Text(
                        pilgrimageLabel(context, 'Next step', 'الخطوة التالية'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    pilgrimageLabel(
                      context,
                      'Show all route sources',
                      'عرض جميع مصادر المسار',
                    ),
                  ),
                  value: _allSources,
                  onChanged: (v) => setState(() => _allSources = v),
                ),
                PilgrimageSources(
                  sources: sourcesForSteps(_allSources ? widget.steps : [step]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content, required this.transliteration});
  final PilgrimageContent content;
  final bool transliteration;
  @override
  Widget build(BuildContext context) {
    final ar = pilgrimageArabic(context);
    final kind = switch (content.kind) {
      ContentKind.riteDhikr => pilgrimageLabel(
        context,
        'Reported rite dhikr',
        'ذكر مأثور للنسك',
      ),
      ContentKind.generalDua => pilgrimageLabel(
        context,
        'General duaa / remembrance',
        'دعاء أو ذكر عام',
      ),
      ContentKind.instruction => pilgrimageLabel(
        context,
        'What to do',
        'ما عليك فعله',
      ),
    };
    return Card(
      key: ValueKey('content-${content.id}'),
      color: content.kind == ContentKind.instruction
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kind,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.title.resolve(ar),
              style: content.action == null
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.labelLarge,
            ),
            if (content.action != null) ...[
              const SizedBox(height: 8),
              Text(
                content.action!.resolve(ar),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            Text(content.guidance.resolve(ar)),
            if (content.kind == ContentKind.instruction) ...[
              const SizedBox(height: 12),
              Text(
                pilgrimageLabel(
                  context,
                  'Action guidance — no fixed duaa text is supplied in this card.',
                  'إرشادات للعمل — لا نورد نص دعاء خاص في هذه البطاقة.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (content.arabic.isNotEmpty) ...[
              const SizedBox(height: 20),
              SelectableText(
                content.arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Uthman',
                  fontSize: 27,
                  height: 1.8,
                ),
              ),
              if (!ar) ...[
                const SizedBox(height: 16),
                Text(content.meaning, textDirection: TextDirection.ltr),
              ],
              if (transliteration && content.transliteration.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  content.transliteration,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ],
            for (final source in content.sources)
              SourceCitation(source: source),
          ],
        ),
      ),
    );
  }
}
