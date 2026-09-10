import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart' as app;
import '../dua/dua_search.dart';
import 'azkar_card_page.dart';
import 'azkar_list.dart';
import 'azkar_style.dart';

class AzkarPageClass extends StatefulWidget {
  const AzkarPageClass({super.key});
  @override
  State<AzkarPageClass> createState() => _AzkarPageClassState();
}

class _AzkarPageClassState extends State<AzkarPageClass> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AzkarStyle(
    child: Builder(
      builder: (context) {
        final categories = AzkarCategories.keys.where((key) {
          final names = azkarNames[key];
          return DuaSearch.matches(_query, [
            if (names != null) '${names.$1} ${names.$2}',
          ]);
        }).toList();
        return Scaffold(
          appBar: AppBar(title: Text(azkarLabel(context, 'Azkar', 'الأذكار'))),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [app.primaryColor, app.thirdColor],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.spa_outlined,
                            color: app.highlightedTextColor,
                            size: 36,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            azkarLabel(
                              context,
                              'A moment of remembrance',
                              'لحظات من الذكر',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            azkarLabel(
                              context,
                              'Read at your pace. Count each repetition. Return where you left off.',
                              'اقرأ على مهل، وعدّ التكرارات، وواصل من حيث توقفت.',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('azkar-search'),
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        labelText: azkarLabel(
                          context,
                          'Find a collection',
                          'ابحث عن مجموعة أذكار',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: azkarLabel(
                                  context,
                                  'Clear search',
                                  'مسح البحث',
                                ),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      azkarLabel(
                        context,
                        'Your daily collections',
                        'مجموعات أذكارك اليومية',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          azkarLabel(
                            context,
                            'No matching collections.',
                            'لا توجد مجموعات مطابقة.',
                          ),
                        ),
                      ),
                    for (final key in categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: InkWell(
                            key: ValueKey('category-$key'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AzkarCardPageClass(keyname: key),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  AzkarIcon(
                                    icon:
                                        azkarIcons[key] ??
                                        Icons.auto_stories_outlined,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          azkarName(context, key),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          azkarLabel(
                                            context,
                                            '${AzkarCategories[key]!.length} adhkar · Read & count',
                                            '${AzkarCategories[key]!.length} ذكرًا · قراءة وعدّ',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      azkarLabel(
                        context,
                        'Available offline. Your counts stay on this device until you start again.',
                        'متاحة دون إنترنت. تبقى تكراراتك على هذا الجهاز حتى تبدأ من جديد.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
