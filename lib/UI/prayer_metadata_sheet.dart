import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:muslim/shared/constants.dart';

/// A readable summary of the calculation inputs returned with prayer times.
class PrayerMetadataSheet extends StatelessWidget {
  const PrayerMetadataSheet({
    super.key,
    required this.locationName,
    required this.metadata,
  });

  final String locationName;
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> method = _asMap(metadata['method']);
    final String methodName = _value(method['name']);
    final String methodId = _value(method['id']);
    final String timezone = _value(metadata['timezone']);
    final String coordinates = _coordinates();
    final String methodSelection = _methodSelection(
      _value(metadata['methodSelection']),
    );
    final String methodRegion = _value(
      _asMap(metadata['methodResolution'])['region'],
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: thirdColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: highlightedColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: highlightedTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Home_Page_Meta_Title'.tr(),
                          style: const TextStyle(
                            color: highlightedTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Close'.tr(),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: textColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _methodCard(methodName, methodId, methodSelection, methodRegion),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      SizedBox(
                        width: cardWidth,
                        child: _summaryCard(
                          Icons.language_outlined,
                          'Home_Page_Meta_Timezone'.tr(),
                          timezone,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryCard(
                          Icons.explore_outlined,
                          'Home_Page_Meta_Coordinates'.tr(),
                          coordinates,
                          ltr: true,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryCard(
                          Icons.school_outlined,
                          'Home_Page_Meta_School'.tr(),
                          _value(metadata['school']),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _summaryCard(
                          Icons.nightlight_outlined,
                          'Home_Page_Meta_Midnight'.tr(),
                          _readableMidnightMode(
                            _value(metadata['midnightMode']),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(
                'Home_Page_Meta_Calculation_Details'.tr(),
                style: const TextStyle(
                  color: highlightedTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _detailsCard(<Widget>[
                _detailRow(
                  Icons.my_location_outlined,
                  'Home_Page_Meta_Timezone_Source'.tr(),
                  _value(metadata['timezoneSource']),
                ),
                _detailRow(
                  Icons.wb_twilight_outlined,
                  'Home_Page_Meta_High_Latitude'.tr(),
                  _value(metadata['polarCircleResolution']),
                ),
                if (_value(metadata['polarReferenceLatitude']).isNotEmpty)
                  _detailRow(
                    Icons.straighten_outlined,
                    'Home_Page_Meta_Reference_Latitude'.tr(),
                    _formatCoordinate(metadata['polarReferenceLatitude']),
                    ltr: true,
                  ),
                if (_value(metadata['latitudeAdjustmentMethod']).isNotEmpty)
                  _detailRow(
                    Icons.tune_outlined,
                    'Home_Page_Meta_Latitude_Adjustment'.tr(),
                    _value(metadata['latitudeAdjustmentMethod']),
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _methodCard(
    String methodName,
    String methodId,
    String methodSelection,
    String methodRegion,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlightedColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.calculate_outlined, color: highlightedTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Home_Page_Meta_Method'.tr(),
                  style: const TextStyle(color: highlightedColor, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  methodName.isEmpty ? '-' : methodName,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (methodSelection.isNotEmpty || methodId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      <String>[
                        if (methodSelection.isNotEmpty) methodSelection,
                        if (methodRegion.isNotEmpty) methodRegion,
                        if (methodId.isNotEmpty) 'ID $methodId',
                      ].join(' · '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    IconData icon,
    String label,
    String value, {
    bool ltr = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: settingsWidgetBGColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: boxesBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: highlightedTextColor),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(color: highlightedColor, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: ltr ? TextDirection.ltr : null,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: boxesBorderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool ltr = false,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: highlightedColor, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      subtitle: Text(
        value.isEmpty ? '-' : value,
        textDirection: ltr ? TextDirection.ltr : null,
        style: const TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _coordinates() {
    final String latitude = _formatCoordinate(metadata['latitude']);
    final String longitude = _formatCoordinate(metadata['longitude']);
    if (latitude.isEmpty || longitude.isEmpty) return '';
    return '$latitude, $longitude';
  }

  String _formatCoordinate(dynamic value) {
    if (value is num) return value.toStringAsFixed(4);
    return _value(value);
  }

  String _methodSelection(String selection) {
    switch (selection) {
      case 'location_default':
        return 'Home_Page_Meta_Method_Location_Default'.tr();
      case 'explicit':
        return 'Home_Page_Meta_Method_Explicit'.tr();
      default:
        return selection;
    }
  }

  String _readableMidnightMode(String value) {
    switch (value) {
      case 'JAFARI':
        return 'Home_Page_Meta_Midnight_Jafari'.tr();
      case 'STANDARD':
        return 'Home_Page_Meta_Midnight_Standard'.tr();
      default:
        return value;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  String _value(dynamic value) => value?.toString() ?? '';
}
