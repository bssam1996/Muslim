import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart' as constants;
import 'package:muslim/utils/hadith_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickHadithCardPageClass extends StatelessWidget {
  const QuickHadithCardPageClass({super.key, required this.hadith});

  final RandomHadith hadith;

  @override
  Widget build(BuildContext context) {
    const double fontSize = kIsWeb ? 32 : 20;

    return FittedBox(
      fit: BoxFit.fitHeight,
      child: Center(
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: constants.fourthColor,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _showDetails(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      hadith.hadith,
                      style: const TextStyle(
                        fontSize: fontSize,
                        fontFamily: 'Uthman',
                        color: constants.textColor,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: ui.TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: constants.highlightedTextColor,
                    ),
                  ],
                ),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[constants.thirdColor, constants.primaryColor],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: constants.highlightedBoxesBorderColor.withValues(
                    alpha: .65,
                  ),
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
                            _buildHadithSection(),
                            if (hadith.explanation
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                Icons.menu_book_rounded,
                                'Hadith_Explanation'.tr(),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hadith.explanation,
                                style: const TextStyle(
                                  color: constants.textColor,
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
      decoration: const BoxDecoration(
        color: Colors.white10,
        border: Border(bottom: BorderSide(color: constants.dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.auto_stories_rounded,
            color: constants.highlightedTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'HOME_HADITH_TITLE'.tr(),
              style: const TextStyle(
                color: constants.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close'.tr(),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: constants.textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHadithSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: constants.fourthColor.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        hadith.hadith,
        style: const TextStyle(
          color: constants.textColor,
          fontFamily: 'Uthman',
          fontSize: 21,
          height: 1.7,
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: <Widget>[
        Icon(icon, color: constants.highlightedTextColor, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: constants.highlightedTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
          leading: const Icon(
            Icons.open_in_new_rounded,
            color: constants.highlightedTextColor,
          ),
          title: Text(
            label.isEmpty ? link : label,
            style: const TextStyle(
              color: constants.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: ui.TextDirection.ltr,
            style: const TextStyle(color: Colors.white60),
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
