import '../../utils/snapshot_cache.dart';
import 'package:muslim/shared/app_theme.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:month_year_picker/month_year_picker.dart';
import 'package:flutter/material.dart';
import 'package:muslim/shared/retry_notice.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/helper.dart' as helper;
import '../../utils/api_utils.dart' as api_utils;
import 'helper.dart' as helpermodal;

class MonthsPageClass extends StatefulWidget {
  const MonthsPageClass({super.key, this.loadMonth, this.fetchMonth});
  final Future<List<DetailedDates>> Function(DateTime month)? loadMonth;
  final Future<String> Function(String path)? fetchMonth;

  @override
  State<MonthsPageClass> createState() => _MonthsPageClassState();
}

class _MonthsPageClassState extends State<MonthsPageClass> {
  List<DetailedDates> detailedDates = <DetailedDates>[];
  late DatesDetailsDataSource detailsDatesDataSource = DatesDetailsDataSource(
    datesData: [],
  );
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  DateTime currentDate = DateTime.now();
  bool _isLoading = false;
  String? _errorKey;
  DateTime? _displayedMonth;
  int _requestId = 0;
  bool _usingCache = false;
  bool _monthFetchFailed = false;
  DateTime? _savedAt;
  String _locationLabel = '';
  String _methodLabel = 'Default';
  late final DataGridController _scrollController;
  double _tableRowHeight = 36;
  double _monthSwipeDistance = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = DataGridController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMonth() => _loadMonth(currentDate);

  Future<void> _loadMonth(DateTime month) async {
    if (!mounted) return;
    final requestId = ++_requestId;
    final requestedMonth = DateTime(month.year, month.month, 1);
    setState(() {
      currentDate = requestedMonth;
      _isLoading = true;
      _errorKey = null;
      _usingCache = false;
      _monthFetchFailed = false;
    });
    try {
      final dates =
          await (widget.loadMonth?.call(requestedMonth) ??
              getDatesData(
                '${requestedMonth.year}/${requestedMonth.month}',
                requestId: requestId,
              ));
      if (!mounted || requestId != _requestId) return;
      if (dates.isEmpty) throw const FormatException('Empty calendar');
      setState(() {
        detailedDates = dates;
        if (_monthFetchFailed) _errorKey = 'Calendar_Cached_Offline';
        _displayedMonth = requestedMonth;
        detailsDatesDataSource = DatesDetailsDataSource(
          datesData: dates,
          palette: AppPalette.of(context),
        );
      });
      await _scrollToToday(requestId);
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _errorKey = error is CalendarLocationException
            ? 'Location_Missing_Error'
            : 'Months_Load_Error';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scrollToToday(int requestId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || requestId != _requestId || detailedDates.isEmpty) return;
    final now = DateTime.now();
    for (var i = 0; i < detailedDates.length; i++) {
      final parts = detailedDates[i].fullGregorian.split('-');
      if (parts.length == 3 &&
          int.tryParse(parts[0]) == now.day &&
          int.tryParse(parts[1]) == now.month &&
          int.tryParse(parts[2]) == now.year) {
        final targetOffset =
            (i * _tableRowHeight - MediaQuery.sizeOf(context).height / 2).clamp(
              0.0,
              double.infinity,
            );
        _scrollController.scrollToVerticalOffset(targetOffset);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    detailsDatesDataSource.palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Months_Title'.tr()),
        backgroundColor: AppPalette.of(context).canvas,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
        actions: [
          IconButton(
            tooltip: 'Calendar_Today'.tr(),
            onPressed: () => _loadMonth(DateTime.now()),
            icon: const Icon(Icons.today),
          ),
          IconButton(
            tooltip: 'Months_Select'.tr(),
            onPressed: () async {
              final selected = await showMonthYearPicker(
                context: context,
                initialDate: currentDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                locale: context.locale,
              );
              if (mounted && selected != null) await _loadMonth(selected);
            },
            icon: const Icon(Icons.calendar_month, color: Colors.red),
          ),
          IconButton(
            tooltip: 'Months_Helper_Title'.tr(),
            onPressed: () async {
              final prefs = await _prefs;
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return helpermodal.showdialog(
                    context,
                    calendarMethod:
                        prefs.getString('calendarMethod') ??
                        'High Judicial Council of Saudi Arabia',
                    adjustment:
                        prefs.getString('calendarMethod') == 'MATHEMATICAL'
                        ? prefs.getInt('adjustment') ?? 0
                        : null,
                  );
                },
              );
            },
            icon: const Icon(Icons.question_mark_rounded, color: Colors.blue),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragStart: (_) => _monthSwipeDistance = 0,
          onHorizontalDragUpdate: (details) =>
              _monthSwipeDistance += details.delta.dx,
          onHorizontalDragCancel: () => _monthSwipeDistance = 0,
          onHorizontalDragEnd: (_) {
            final distance = _monthSwipeDistance;
            _monthSwipeDistance = 0;
            if (distance.abs() < 48) return;
            final direction = Directionality.of(context) == TextDirection.rtl
                ? -1
                : 1;
            navigateTable(distance * direction < 0);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_locationLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '$_locationLabel \u00b7 ${(_methodLabel == 'Default' ? 'Settings_Default_Method'.tr() : _methodLabel.tr())}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppPalette.of(context).muted),
                        ),
                      ),
                    if (_usingCache && _savedAt != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Calendar_Saved_At'.tr(
                            namedArgs: {
                              'date': DateFormat.yMMMd(
                                context.locale.toString(),
                              ).add_Hm().format(_savedAt!.toLocal()),
                            },
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Months_Previous'.tr(),
                          onPressed: () => navigateTable(false),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        Expanded(
                          child: Text(
                            '${helpermodal.convertGregorianMonthToString(currentDate.month)?.tr()} ${currentDate.year}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Months_Next'.tr(),
                          onPressed: () => navigateTable(true),
                          icon: const Icon(Icons.arrow_forward_ios),
                        ),
                      ],
                    ),
                    if (_errorKey != null ||
                        (_displayedMonth != null &&
                            _displayedMonth != currentDate))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: RetryNotice(
                          message:
                              _displayedMonth != null &&
                                  _displayedMonth != currentDate
                              ? (_errorKey == null
                                        ? 'Months_Previous_Loading'
                                        : 'Months_Previous_Error')
                                    .tr(
                                      namedArgs: {
                                        'month':
                                            '${_displayedMonth!.month}/${_displayedMonth!.year}',
                                      },
                                    )
                              : _errorKey!.tr(),
                          onRetry: _isLoading ? null : _loadCurrentMonth,
                        ),
                      ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (detailedDates.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _buildTable();
                      },
                    ),
                    if (_isLoading && detailedDates.isEmpty)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 650;
      final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
      final fontSize = (constraints.maxWidth / (compact ? 32 : 80)).clamp(
        10.0,
        14.0,
      );
      final dateWidth = (constraints.maxWidth * .16).clamp(48.0, 80.0);
      final columnWidth = compact
          ? (constraints.maxWidth - dateWidth) / 6
          : constraints.maxWidth / 9;
      final labels = <String, String>{
        if (compact)
          'date': 'Calendar_Date'.tr()
        else ...{
          'day': 'Months_Column_Day'.tr(),
          'gregorian': 'Months_Column_Gregorian'.tr(),
          'hijri': 'Months_Column_Hijri'.tr(),
        },
        'fajr': 'Months_Column_Fajr'.tr(),
        'sunrise': 'Months_Column_Sunrise'.tr(),
        'dhuhr': 'Months_Column_Dhuhr'.tr(),
        'asr': 'Months_Column_Asr'.tr(),
        'maghrib': 'Months_Column_Maghrib'.tr(),
        'isha': 'Months_Column_Isha'.tr(),
      };
      var headerHeight = 34.0;
      for (final entry in labels.entries) {
        final painter =
            TextPainter(
              text: TextSpan(
                text: entry.value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: fontFamily,
                  height: 1.15,
                ),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: (entry.key == 'date' ? dateWidth : columnWidth) - 4,
            );
        if (painter.height + 10 > headerHeight) {
          headerHeight = painter.height + 10;
        }
        painter.dispose();
      }
      final scaledFont = MediaQuery.textScalerOf(context).scale(fontSize);
      var rowHeight = compact
          ? (MediaQuery.textScalerOf(
                          context,
                        ).scale((fontSize - 2).clamp(9.0, 12.0)) *
                        2.4 +
                    6)
                .clamp(30.0, double.infinity)
          : (scaledFont * 1.6 + 4).clamp(28.0, double.infinity);
      for (final day in detailedDates) {
        final painter = TextPainter(
          text: TextSpan(
            text: compact
                ? '${day.day} ${day.gregorian.split('-').first}\n${day.hijri}'
                : day.gregorian,
            style: TextStyle(
              fontSize: compact ? (fontSize - 2).clamp(9.0, 12.0) : fontSize,
              height: 1.15,
              fontFamily: fontFamily,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: (compact ? dateWidth : columnWidth) - 2);
        if (painter.height + 6 > rowHeight) rowHeight = painter.height + 6;
        painter.dispose();
      }
      _tableRowHeight = rowHeight;
      detailsDatesDataSource
        ..compact = compact
        ..fontSize = fontSize
        ..fontFamily = fontFamily;
      return SfDataGridTheme(
        data: SfDataGridThemeData(gridLineStrokeWidth: .5),
        child: SfDataGrid(
          key: const ValueKey('calendar_month_table'),
          controller: _scrollController,
          gridLinesVisibility: GridLinesVisibility.both,
          headerGridLinesVisibility: GridLinesVisibility.both,
          rowHeight: rowHeight,
          headerRowHeight: headerHeight,
          source: detailsDatesDataSource,
          columnWidthMode: ColumnWidthMode.fill,
          horizontalScrollPhysics: const NeverScrollableScrollPhysics(),
          columns: [
            for (final entry in labels.entries)
              generateColumn(
                entry.key,
                AppPalette.of(context).panel,
                entry.value,
                AppPalette.of(context).text,
                fontSize: fontSize,
                width: compact && entry.key == 'date' ? dateWidth : double.nan,
              ),
          ],
        ),
      );
    },
  );

  Future<List<DetailedDates>> getDatesData(
    String date, {
    int? requestId,
  }) async {
    final savedLocation = await api_utils.getSavedLocation();
    if (savedLocation['error'] != '') throw const CalendarLocationException();
    final prefs = await _prefs;
    final path = await helper.constructAPIParameters(
      'calendar',
      date,
      savedLocation,
      _prefs,
    );
    if (path == null) throw const CalendarLocationException();
    final monthParts = date.split('/').map(int.parse).toList();
    final month = DateTime(monthParts[0], monthParts[1]);
    final cache = SnapshotCache(prefs, 'calendar-cache-v1/');
    final snapshot = cache.read(path);
    List<DetailedDates>? cached;
    if (snapshot != null) {
      try {
        cached = parseCalendarResponse(
          snapshot.payload,
          use24Hour: prefs.getBool('24system') ?? true,
        );
        validateCalendarMonth(cached, month);
        if (mounted && requestId == _requestId) {
          setState(() {
            detailedDates = cached!;
            _displayedMonth = month;
            _usingCache = true;
            _savedAt = snapshot.savedAt;
            detailsDatesDataSource = DatesDetailsDataSource(
              datesData: cached,
              palette: AppPalette.of(context),
            );
          });
        }
      } catch (_) {
        cached = null;
      }
    }
    if (mounted && requestId == _requestId) {
      setState(() {
        _locationLabel = helper.getAddressLocation(savedLocation);
        _methodLabel = prefs.getString('method') ?? 'Default';
      });
    }
    try {
      String body;
      if (widget.fetchMonth != null) {
        body = await widget.fetchMonth!(path).timeout(
          const Duration(seconds: 15),
        );
      } else {
        final response = await helper.fetchData(
          'calendar',
          date,
          savedLocation,
          _prefs,
        );
        if (response == null || response.statusCode != 200) {
          throw const FormatException('Calendar request failed');
        }
        body = response.body;
      }
      final dates = parseCalendarResponse(
        body,
        use24Hour: prefs.getBool('24system') ?? true,
      );
      validateCalendarMonth(dates, month);
      try {
        await cache.write(path, body);
      } catch (_) {
        /* Valid live data remains readable when storage is unavailable. */
      }
      if (mounted && requestId == _requestId) {
        _usingCache = false;
        _savedAt = DateTime.now();
      }
      return dates;
    } catch (_) {
      if (cached == null) rethrow;
      if (mounted && requestId == _requestId) {
        _usingCache = true;
        _monthFetchFailed = true;
      }
      return cached;
    }
  }

  void navigateTable(bool forward) {
    _loadMonth(
      DateTime(currentDate.year, currentDate.month + (forward ? 1 : -1), 1),
    );
  }
}

class CalendarLocationException implements Exception {
  const CalendarLocationException();
}

List<DetailedDates> parseCalendarResponse(
  String body, {
  bool use24Hour = true,
}) {
  final dynamic decoded = jsonDecode(body);
  if (decoded is! Map ||
      decoded['code'] != 200 ||
      decoded['data'] is! List ||
      (decoded['data'] as List).isEmpty) {
    throw const FormatException('Invalid calendar response');
  }
  return (decoded['data'] as List).map((dynamic item) {
    if (item is! Map || item['timings'] is! Map || item['date'] is! Map) {
      throw const FormatException('Incomplete calendar day');
    }
    final dynamic gregorian = item['date']['gregorian'];
    if (gregorian is! Map ||
        gregorian['date'] is! String ||
        gregorian['weekday'] is! Map ||
        gregorian['weekday']['en'] is! String ||
        (gregorian['weekday']['en'] as String).length < 3) {
      throw const FormatException('Invalid calendar date');
    }
    final fullGregorian = gregorian['date'] as String;
    final parts = fullGregorian.split('-');
    if (parts.length != 3) throw const FormatException('Invalid date');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      throw const FormatException('Invalid date');
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid date');
    }
    String clock(String prayer) {
      final dynamic raw = item['timings'][prayer];
      if (raw is! String) throw const FormatException('Missing prayer time');
      final match = RegExp(r'^(\d{2}):(\d{2})(?:\s|$)').firstMatch(raw);
      if (match == null ||
          int.parse(match[1]!) > 23 ||
          int.parse(match[2]!) > 59) {
        throw const FormatException('Invalid prayer time');
      }
      final time = '${match[1]}:${match[2]}';
      return use24Hour ? time : shared24Convert(time);
    }

    final dynamic hijri = item['date']['hijri'];
    final dynamic hijriDate = hijri is Map ? hijri['date'] : null;
    final hijriParts = hijriDate is String ? hijriDate.split('-') : <String>[];
    return DetailedDates(
      (gregorian['weekday']['en'] as String).substring(0, 3).tr(),
      '${parts[0]}-${parts[1]}',
      hijriParts.length >= 2 ? '${hijriParts[0]}-${hijriParts[1]}' : '-',
      clock('Fajr'),
      clock('Sunrise'),
      clock('Dhuhr'),
      clock('Asr'),
      clock('Maghrib'),
      clock('Isha'),
      fullGregorian,
    );
  }).toList();
}

void validateCalendarMonth(List<DetailedDates> dates, DateTime month) {
  final expected = DateTime(month.year, month.month + 1, 0).day;
  final suffix = '-${month.month.toString().padLeft(2, '0')}-${month.year}';
  if (dates.length != expected ||
      dates.map((day) => day.fullGregorian).toSet().length != expected ||
      dates.any((day) => !day.fullGregorian.endsWith(suffix))) {
    throw const FormatException('Calendar does not cover requested month');
  }
}

String constructTime(String time) {
  List<String> timingWhole = time.split(" ");
  return timingWhole[0];
}

GridColumn generateColumn(
  String id,
  Color color,
  String labelName,
  Color foregroundColor, {
  double fontSize = 14,
  double width = double.nan,
}) {
  return GridColumn(
    columnName: id,
    width: width,
    label: Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(2.0, 0, 2.0, 0),
      alignment: Alignment.center,
      child: Text(
        labelName,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          height: 1.15,
        ),
      ),
    ),
  );
}

class DetailedDates {
  /// Creates the employee class with required details.
  DetailedDates(
    this.day,
    this.gregorian,
    this.hijri,
    this.fajr,
    this.sunrise,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
    this.fullGregorian,
  );

  final String day;
  final String gregorian;
  final String hijri;
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String fullGregorian;
}

class DatesDetailsDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  DatesDetailsDataSource({
    required List<DetailedDates> datesData,
    AppPalette? palette,
  }) : palette =
           palette ?? AppPalette(AppTheme.build(Brightness.light).colorScheme) {
    _datesData = datesData
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<String>(columnName: 'day', value: e.day),
              DataGridCell<String>(columnName: 'gregorian', value: e.gregorian),
              DataGridCell<String>(columnName: 'hijri', value: e.hijri),
              DataGridCell<String>(columnName: 'fajr', value: e.fajr),
              DataGridCell<String>(columnName: 'sunrise', value: e.sunrise),
              DataGridCell<String>(columnName: 'dhuhr', value: e.dhuhr),
              DataGridCell<String>(columnName: 'asr', value: e.asr),
              DataGridCell<String>(columnName: 'maghrib', value: e.maghrib),
              DataGridCell<String>(columnName: 'isha', value: e.isha),
              DataGridCell<String>(
                columnName: 'fullGregorian',
                value: e.fullGregorian,
              ),
            ],
          ),
        )
        .toList();
    _compactDatesData = _datesData.map((row) {
      final cells = row.getCells();
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'date',
            value:
                '${cells[0].value} ${cells[1].value.toString().split('-').first}\n${cells[2].value}',
          ),
          ...cells.skip(3),
        ],
      );
    }).toList();
  }

  AppPalette palette;
  bool compact = false;
  double fontSize = 14;
  String? fontFamily;
  List<DataGridRow> _datesData = [];
  List<DataGridRow> _compactDatesData = [];

  @override
  List<DataGridRow> get rows => compact ? _compactDatesData : _datesData;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    Color backgroundColor = palette.canvas;
    String fullDate = row
        .getCells()
        .firstWhere((cell) => cell.columnName == 'fullGregorian')
        .value
        .toString();
    List<String> parts = fullDate.split("-");
    if (parts.length == 3) {
      if (int.parse(parts[0]) == DateTime.now().day &&
          int.parse(parts[1]) == DateTime.now().month &&
          int.parse(parts[2]) == DateTime.now().year) {
        backgroundColor = palette.accentSurface;
      }
    }
    return DataGridRowAdapter(
      cells: row
          .getCells()
          .where((cell) => cell.columnName != 'fullGregorian')
          .map<Widget>((e) {
            final isDate = [
              'date',
              'day',
              'gregorian',
              'hijri',
            ].contains(e.columnName);
            return Container(
              color: isDate && backgroundColor != palette.accentSurface
                  ? palette.panel
                  : backgroundColor,
              alignment: Alignment.center,
              // padding: const EdgeInsets.all(8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final value = e.value.toString();
                  var style = TextStyle(
                    color: palette.text,
                    fontFamily: fontFamily,
                    fontSize: compact && isDate
                        ? (fontSize - 2).clamp(9.0, 12.0)
                        : fontSize,
                    height: 1.15,
                  );
                  final painter = TextPainter(
                    text: TextSpan(text: value, style: style),
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final splitClock =
                      !isDate && painter.width > constraints.maxWidth - 2;
                  painter.dispose();
                  if (splitClock) {
                    final hour = TextPainter(
                      text: TextSpan(
                        text: value.split(':').first,
                        style: style,
                      ),
                      textDirection: TextDirection.ltr,
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    if (hour.width > constraints.maxWidth - 2) {
                      style = style.copyWith(
                        fontSize:
                            style.fontSize! *
                            (constraints.maxWidth - 2) /
                            hour.width,
                      );
                    }
                    hour.dispose();
                  }
                  return Semantics(
                    label: isDate ? fullDate : value,
                    excludeSemantics: true,
                    child: Text(
                      splitClock ? value.replaceFirst(':', '\n') : value,
                      textAlign: TextAlign.center,
                      textDirection: isDate ? null : TextDirection.ltr,
                      style: style,
                    ),
                  );
                },
              ),
            );
          })
          .toList(),
    );
  }
}

String shared24Convert(String time) {
  List<String> splittedTime = time.split(":");
  int integerHour = int.parse(splittedTime[0]);
  if (integerHour > 12) {
    splittedTime[0] = (integerHour - 12).toString();
  }
  return "${splittedTime[0]}:${splittedTime[1]}";
}
