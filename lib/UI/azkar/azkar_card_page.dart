import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dua/dua_search.dart';
import 'azkar_items.dart';
import 'azkar_list.dart';
import 'azkar_session.dart';
import 'azkar_style.dart';

class AzkarCardPageClass extends StatefulWidget {
  final String keyname;
  const AzkarCardPageClass({super.key, required this.keyname});

  @override
  State<AzkarCardPageClass> createState() => _AzkarCardPageClassState();
}

class _AzkarCardPageClassState extends State<AzkarCardPageClass> {
  late final _session = AzkarSession(
    widget.keyname,
    AzkarCategories[widget.keyname] ?? [],
  );
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _session.load();
  }

  @override
  void dispose() {
    _session.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    _session.select(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _reset(BuildContext context) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AzkarStyle(
        child: AlertDialog(
          scrollable: true,
          icon: const Icon(Icons.restart_alt),
          title: Text(
            azkarLabel(
              context,
              'Start this collection again?',
              'تبدأ هذه المجموعة من جديد؟',
            ),
          ),
          content: Text(
            azkarLabel(
              context,
              'This clears all counts in this collection. Your text size and other collections stay unchanged.',
              'سيُمسح عدّ التكرارات لهذه المجموعة فقط. لن يتغير حجم النص أو تقدمك في المجموعات الأخرى.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                azkarLabel(context, 'Keep reading', 'متابعة القراءة'),
              ),
            ),
            FilledButton(
              key: const ValueKey('confirm-azkar-reset'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(azkarLabel(context, 'Start again', 'البدء من جديد')),
            ),
          ],
        ),
      ),
    );
    if (reset == true && mounted) {
      _session.reset();
      _select(0);
    }
  }

  Future<void> _browse(BuildContext context) async {
    String query = '';
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => AzkarStyle(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final matches = [
              for (var i = 0; i < _session.items.length; i++)
                if (DuaSearch.matches(query, [
                  _session.items[i].data,
                  _session.items[i].description,
                ]))
                  i,
            ];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .65,
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        azkarLabel(context, 'Choose a dhikr', 'اختر ذكرًا'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        key: const ValueKey('azkar-reader-search'),
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        decoration: InputDecoration(
                          labelText: azkarLabel(
                            context,
                            'Search the Arabic text',
                            'ابحث في نص الأذكار',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            azkarLabel(
                              context,
                              'No matching adhkar.',
                              'لا توجد أذكار مطابقة.',
                            ),
                          ),
                        ),
                      ),
                    for (final i in matches)
                      Builder(
                        builder: (context) {
                          final item = _session.items[i];
                          final done = _session.countAt(i) == item.count;
                          return ListTile(
                            key: ValueKey('browse-dhikr-$i'),
                            selected: i == _session.index,
                            leading: done
                                ? const Icon(Icons.check_circle_outline)
                                : Text('${i + 1}'),
                            title: Text(
                              item.data,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(fontFamily: 'Uthman'),
                            ),
                            subtitle: Text(
                              azkarLabel(
                                context,
                                '${_session.countAt(i)} / ${item.count}',
                                '${_session.countAt(i)} من ${item.count}',
                              ),
                            ),
                            onTap: () => Navigator.pop(context, i),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (selected != null && mounted) _select(selected);
  }

  Future<void> _copy(BuildContext context, AzkarItem item) async {
    try {
      await Clipboard.setData(ClipboardData(text: item.data));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(azkarLabel(context, 'Dhikr copied', 'تم نسخ الذكر')),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              azkarLabel(context, 'Could not copy the text.', 'تعذر نسخ النص.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AzkarStyle(
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final items = _session.items;
          return Scaffold(
            appBar: AppBar(
              title: Text(azkarName(context, widget.keyname)),
              actions: [
                IconButton(
                  key: const ValueKey('azkar-reset'),
                  tooltip: azkarLabel(context, 'Start again', 'البدء من جديد'),
                  onPressed: _session.loaded && _session.repetitions > 0
                      ? () => _reset(context)
                      : null,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            body: !_session.loaded
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Text(
                      azkarLabel(
                        context,
                        'This collection is unavailable.',
                        'هذه المجموعة غير متاحة.',
                      ),
                    ),
                  )
                : SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          key: ValueKey('azkar-reader-${_session.index}'),
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            Row(
                              children: [
                                AzkarIcon(
                                  icon:
                                      azkarIcons[widget.keyname] ??
                                      Icons.auto_stories_outlined,
                                  size: 48,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        azkarLabel(
                                          context,
                                          'Your session',
                                          'جلستك',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        azkarLabel(
                                          context,
                                          '${_session.completed} of ${items.length} adhkar completed',
                                          'اكتمل ${_session.completed} من ${items.length} ذكرًا',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            LinearProgressIndicator(
                              value: _session.completed / items.length,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(8),
                              semanticsLabel: azkarLabel(
                                context,
                                'Collection progress',
                                'تقدم المجموعة',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              azkarLabel(
                                context,
                                'Counts resume here until you choose Start again.',
                                'يمكنك متابعة العدّ هنا حتى تختار البدء من جديد.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_session.storageError)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  azkarLabel(
                                    context,
                                    'Progress could not be restored or saved. You can keep reading, but it may not be available next time.',
                                    'تعذر استعادة التقدم أو حفظه. يمكنك مواصلة القراءة، لكن قد لا تجده في المرة القادمة.',
                                  ),
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            if (_session.finished)
                              Container(
                                key: const ValueKey('azkar-complete'),
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline),
                                    const SizedBox(height: 8),
                                    Text(
                                      azkarLabel(
                                        context,
                                        'Collection completed',
                                        'اكتملت المجموعة',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      azkarLabel(
                                        context,
                                        'You can revisit any dhikr or start again.',
                                        'يمكنك العودة لأي ذكر أو البدء من جديد.',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 18),
                            Card(
                              color: colors.surfaceContainerLow,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  children: [
                                    Text(
                                      azkarLabel(
                                        context,
                                        'Text size',
                                        'حجم النص',
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          key: const ValueKey(
                                            'azkar-font-minus',
                                          ),
                                          tooltip: azkarLabel(
                                            context,
                                            'Decrease text size',
                                            'تصغير النص',
                                          ),
                                          onPressed:
                                              _session.fontSize >
                                                  AzkarSession.minFontSize
                                              ? () => _session.resize(-2)
                                              : null,
                                          icon: const Icon(Icons.text_decrease),
                                        ),
                                        Text(
                                          '${_session.fontSize.round()}',
                                          key: const ValueKey(
                                            'azkar-font-value',
                                          ),
                                        ),
                                        IconButton(
                                          key: const ValueKey(
                                            'azkar-font-plus',
                                          ),
                                          tooltip: azkarLabel(
                                            context,
                                            'Increase text size',
                                            'تكبير النص',
                                          ),
                                          onPressed:
                                              _session.fontSize <
                                                  AzkarSession.maxFontSize
                                              ? () => _session.resize(2)
                                              : null,
                                          icon: const Icon(Icons.text_increase),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _DhikrCard(
                              key: ValueKey('dhikr-${_session.index}'),
                              item: items[_session.index],
                              number: _session.index + 1,
                              total: items.length,
                              count: _session.countAt(_session.index),
                              fontSize: _session.fontSize,
                              onIncrement: () => _session.changeCount(1),
                              onDecrement: () => _session.changeCount(-1),
                              onCopy: () =>
                                  _copy(context, items[_session.index]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            bottomNavigationBar: !_session.loaded || items.isEmpty
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            key: const ValueKey('azkar-previous'),
                            tooltip: azkarLabel(
                              context,
                              'Previous dhikr',
                              'الذكر السابق',
                            ),
                            onPressed: _session.index > 0
                                ? () => _select(_session.index - 1)
                                : null,
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              key: const ValueKey('azkar-browse'),
                              onPressed: () => _browse(context),
                              icon: const Icon(Icons.format_list_numbered),
                              label: Text(
                                azkarLabel(
                                  context,
                                  'Browse adhkar',
                                  'تصفح الأذكار',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            key: const ValueKey('azkar-next'),
                            tooltip: azkarLabel(
                              context,
                              'Next dhikr',
                              'الذكر التالي',
                            ),
                            onPressed: _session.index < items.length - 1
                                ? () => _select(_session.index + 1)
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    ),
  );
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    super.key,
    required this.item,
    required this.number,
    required this.total,
    required this.count,
    required this.fontSize,
    required this.onIncrement,
    required this.onDecrement,
    required this.onCopy,
  });
  final AzkarItem item;
  final int number, total, count;
  final double fontSize;
  final VoidCallback onIncrement, onDecrement, onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = count >= item.count;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    azkarLabel(
                      context,
                      'Dhikr $number of $total',
                      'الذكر $number من $total',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: colors.primary),
                  ),
                ),
                IconButton(
                  tooltip: azkarLabel(context, 'Copy dhikr', 'نسخ الذكر'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              item.data,
              key: const ValueKey('azkar-text'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Uthman',
                fontSize: fontSize,
                height: 1.9,
              ),
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              ExpansionTile(
                // Existing descriptions can contain timing instructions, not
                // just virtues. Keep them visible unless the reader folds them.
                initiallyExpanded: true,
                key: ValueKey('description-$number'),
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(
                  azkarLabel(context, 'About this dhikr', 'حول هذا الذكر'),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      item.description,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Uthman',
                        fontSize: fontSize * .8,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: count / item.count,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
              semanticsLabel: azkarLabel(context, 'Repetitions', 'التكرارات'),
            ),
            const SizedBox(height: 18),
            Text(
              azkarLabel(
                context,
                'Repetitions · $count / ${item.count}',
                'التكرارات · $count من ${item.count}',
              ),
              key: const ValueKey('azkar-count'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('azkar-count-button'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: done ? null : onIncrement,
              icon: Icon(
                done ? Icons.check_circle_outline : Icons.add_circle_outline,
              ),
              label: Text(
                azkarLabel(
                  context,
                  done ? 'Completed' : 'Tap to count',
                  done ? 'اكتمل' : 'اضغط للعدّ',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('azkar-undo'),
              onPressed: count > 0 ? onDecrement : null,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(
                azkarLabel(context, 'Undo one count', 'إنقاص تكرار واحد'),
              ),
            ),
            Text(
              azkarLabel(
                context,
                'Tap once after each recitation. Move on when you are ready.',
                'اضغط مرة بعد كل تلاوة، ثم انتقل عندما تكون مستعدًا.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
