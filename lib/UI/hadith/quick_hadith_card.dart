import 'package:muslim/shared/app_theme.dart';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/web_home_style.dart';
import 'package:muslim/utils/hadith_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickHadithCardPageClass extends StatelessWidget {
  const QuickHadithCardPageClass({super.key, required this.hadith});

  final RandomHadith hadith;

  @override
  Widget build(BuildContext context) {
    const double fontSize = 24;
    final styled = useWebHomeStyle(context);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${'HOME_HADITH_TITLE'.tr()}. ${hadith.hadith}',
      hint: 'Hadith_Read_More'.tr(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(styled ? 24 : 16),
          side: styled
              ? BorderSide(color: AppPalette.of(context).border)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: styled
                  ? <Color>[
                      AppPalette.of(context).accentSurface,
                      AppPalette.of(context).panel,
                    ]
                  : <Color>[
                      AppPalette.of(context).canvas,
                      AppPalette.of(context).panel,
                    ],
            ),
          ),
          child: InkWell(
            onTap: () => _showDetails(context),
            child: Padding(
              padding: styled
                  ? const EdgeInsets.fromLTRB(24, 22, 24, 16)
                  : const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_stories_rounded,
                        color: AppPalette.of(context).accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'HOME_HADITH_TITLE'.tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hadith.hadith,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.65,
                      fontFamily: 'Uthman',
                      color: AppPalette.of(context).text,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: ui.TextDirection.rtl,
                  ),
                  const SizedBox(height: 10),
                  Divider(color: AppPalette.of(context).border, height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Hadith_Read_More'.tr(),
                          style: TextStyle(
                            color: AppPalette.of(context).accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppPalette.of(context).accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size screenSize = MediaQuery.sizeOf(dialogContext);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: screenSize.height * .86,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppPalette.of(context).panel,
                    AppPalette.of(context).canvas,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppPalette.of(context).accent.withValues(alpha: .65),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildHeader(dialogContext),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildHadithSection(context),
                            if (hadith.explanation
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                context,
                                Icons.menu_book_rounded,
                                'Hadith_Explanation'.tr(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hadith.explanation,
                                style: TextStyle(
                                  color: AppPalette.of(context).text,
                                  fontSize: 17,
                                  height: 1.7,
                                ),
                                textAlign: TextAlign.start,
                                textDirection: ui.TextDirection.rtl,
                              ),
                            ],
                            if (hadith.explanationLinks.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                context,
                                Icons.link_rounded,
                                'Hadith_Explanation_Links'.tr(),
                              ),
                              const SizedBox(height: 8),
                              ...hadith.explanationLinks.map(
                                (String link) =>
                                    _buildLink(dialogContext, link),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        border: Border(
          bottom: BorderSide(color: AppPalette.of(context).border),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.auto_stories_rounded,
            color: AppPalette.of(context).accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'HOME_HADITH_TITLE'.tr(),
              style: TextStyle(
                color: AppPalette.of(context).text,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close'.tr(),
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: AppPalette.of(context).text),
          ),
        ],
      ),
    );
  }

  Widget _buildHadithSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.of(context).muted.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        hadith.hadith,
        style: TextStyle(
          color: AppPalette.of(context).text,
          fontFamily: 'Uthman',
          fontSize: 21,
          height: 1.7,
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, IconData icon, String title) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppPalette.of(context).accent, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: AppPalette.of(context).accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLink(BuildContext context, String link) {
    final Uri uri = Uri.parse(link);
    final String label = uri.host.replaceFirst(RegExp(r'^www\.'), '');

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            Icons.open_in_new_rounded,
            color: AppPalette.of(context).accent,
          ),
          title: Text(
            label.isEmpty ? link : label,
            style: TextStyle(
              color: AppPalette.of(context).text,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: ui.TextDirection.ltr,
            style: TextStyle(color: AppPalette.of(context).muted),
          ),
          onTap: () => _openLink(context, uri),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('Hadith_Link_Error'.tr())));
    }
  }
}
