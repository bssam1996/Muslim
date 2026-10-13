import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/snapshot_cache.dart';
import '../../utils/mosque_search_cache.dart';
import '../../shared/retry_notice.dart';
import 'package:muslim/shared/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:muslim/utils/mosque_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class NearestMosquePageClass extends StatefulWidget {
  const NearestMosquePageClass({super.key, this.loadSearch, this.mapBuilder});
  final Future<(MosqueSearchLocation, MosqueSearchResult)> Function(int radius)?
  loadSearch;

  final Widget Function(
    MosqueSearchLocation location,
    List<MosquePlace> mosques,
  )?
  mapBuilder;

  @override
  State<NearestMosquePageClass> createState() => _NearestMosquePageClassState();
}

class _NearestMosquePageClassState extends State<NearestMosquePageClass> {
  static const List<int> _radiusOptionsMeters = <int>[
    1000,
    3000,
    5000,
    10000,
    25000,
  ];

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _mapTilesFailed = false;
  bool _showMap = false;
  bool _fromCache = false;
  DateTime? _savedAt;
  String? _selectedMosque;
  int _requestId = 0;
  int _selectedRadiusMeters = 3000;
  int _searchedRadiusMeters = 3000;
  bool _loading = true;
  String? _errorKey;
  MosqueSearchLocation? _location;
  List<MosquePlace> _mosques = <MosquePlace>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreAndSearch();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _restoreAndSearch() async {
    {
      try {
        final snapshot = SnapshotCache(
          await SharedPreferences.getInstance(),
          'mosque-search-cache-v1/',
        ).latest();
        if (snapshot != null) {
          final (location, result) = decodeMosqueSearch(snapshot.payload);
          if (mounted) {
            setState(() {
              _location = location;
              _mosques = result.mosques;
              _searchedRadiusMeters = result.radiusMeters;
              _savedAt = snapshot.savedAt;
              _fromCache = true;
            });
          }
        }
      } catch (_) {
        /* Ignore invalid saved results. */
      }
    }
    if (mounted) await _searchMosques();
  }

  Future<void> _searchMosques() async {
    if (!mounted) return;
    final request = ++_requestId;
    final radius = _selectedRadiusMeters;
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      final (
        location,
        result,
      ) = await (widget.loadSearch?.call(radius) ?? _loadSearch(radius))
          .timeout(const Duration(seconds: 25));
      if (!mounted || request != _requestId) return;
      setState(() {
        _location = location;
        _mosques = result.mosques;
        _searchedRadiusMeters = result.radiusMeters;
        _loading = false;
        _fromCache = false;
        _savedAt = DateTime.now();
        _selectedMosque = null;
        _mapTilesFailed = false;
        _mapReady = false;
      });
      try {
        await SnapshotCache(
          await SharedPreferences.getInstance(),
          'mosque-search-cache-v1/',
        ).write(
          '${location.latitude},${location.longitude}/$radius',
          encodeMosqueSearch(location, result),
        );
      } catch (_) {
        /* Successful live results remain usable without a cache write. */
      }
    } on MosqueLocationException catch (error) {
      if (mounted && request == _requestId) {
        setState(() {
          _errorKey = error.translationKey;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _requestId) {
        setState(() {
          _errorKey = 'Nearest_Mosque_Search_Error';
          _loading = false;
        });
      }
    }
  }

  Future<(MosqueSearchLocation, MosqueSearchResult)> _loadSearch(
    int radius,
  ) async {
    final location = await getMosqueSearchLocation();
    final result = await findNearbyMosques(
      latitude: location.latitude,
      longitude: location.longitude,
      initialRadiusMeters: radius,
    );
    return (location, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.of(context).canvas,
      appBar: AppBar(
        backgroundColor: AppPalette.of(context).canvas,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
        title: Text(
          'Nearest_Mosque_Title'.tr(),
          style: TextStyle(color: AppPalette.of(context).text),
        ),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).panel,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSearchControls(),
                    if (_loading) const LinearProgressIndicator(),
                    if (_location != null) _buildSearchSummary(),
                    if (_location != null && _errorKey != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: RetryNotice(
                          message:
                              '${_errorKey!.tr()} ${'Mosque_Previous_Results'.tr()}',
                          onRetry: _loading ? null : _searchMosques,
                        ),
                      ),
                  ],
                ),
              ),
              SliverFillRemaining(hasScrollBody: true, child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final radius = DropdownButtonFormField<int>(
            isExpanded: true,
            itemHeight: null,
            isDense: false,
            initialValue: _selectedRadiusMeters,
            dropdownColor: AppPalette.of(context).canvas,
            decoration: InputDecoration(
              labelText: 'Nearest_Mosque_Radius'.tr(),
              labelStyle: TextStyle(color: AppPalette.of(context).text),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.of(context).border),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.of(context).muted),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppPalette.of(context).accent),
              ),
            ),
            iconEnabledColor: AppPalette.of(context).text,
            iconDisabledColor: AppPalette.of(context).muted,
            style: TextStyle(color: AppPalette.of(context).text),
            items: _radiusOptionsMeters
                .map(
                  (int radius) => DropdownMenuItem<int>(
                    value: radius,
                    child: Text(
                      formatMosqueDistance(radius.toDouble()),
                      style: TextStyle(color: AppPalette.of(context).text),
                    ),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (int? value) {
                    if (value == null) return;
                    setState(() {
                      _selectedRadiusMeters = value;
                    });
                  },
          );
          final search = ElevatedButton.icon(
            onPressed: _loading ? null : _searchMosques,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.of(context).accent,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              disabledBackgroundColor: AppPalette.of(context).panel,
              disabledForegroundColor: AppPalette.of(context).text,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
            icon: const Icon(Icons.search),
            label: Text('Search'.tr()),
          );
          return constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [radius, const SizedBox(height: 8), search],
                )
              : Row(
                  children: [
                    Expanded(child: radius),
                    const SizedBox(width: 12),
                    search,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildSearchSummary() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        if (_location!.fromFallback)
          Text(
            'Nearest_Mosque_Using_Last_Location'.tr(),
            textAlign: TextAlign.center,
          ),
        if (_fromCache && _savedAt != null)
          Text(
            'Mosque_Saved_Search'.tr(
              namedArgs: {
                'date': DateFormat.yMMMd(
                  context.locale.toString(),
                ).add_Hm().format(_savedAt!.toLocal()),
              },
            ),
            textAlign: TextAlign.center,
          ),
        Text(
          'Nearest_Mosque_Result_Count'.tr(
            args: [
              _mosques.length.toString(),
              formatMosqueDistance(_searchedRadiusMeters.toDouble()),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        ExpansionTile(
          key: const ValueKey('mosque_search_details'),
          title: Text('Mosque_Search_Details'.tr()),
          children: [
            Text(
              'Mosque_Search_Centre'.tr(
                namedArgs: {
                  'latitude': _location!.latitude.toStringAsFixed(4),
                  'longitude': _location!.longitude.toStringAsFixed(4),
                },
              ),
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Mosque_Straight_Line'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.of(context).muted),
              ),
            ),
          ],
        ),
        if (MediaQuery.sizeOf(context).width < 760 && _mosques.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('mosque_list_toggle'),
                label: Text('Mosque_List'.tr()),
                selected: !_showMap,
                onSelected: (_) => setState(() => _showMap = false),
              ),
              ChoiceChip(
                key: const ValueKey('mosque_map_toggle'),
                label: Text('Mosque_Map'.tr()),
                selected: _showMap,
                onSelected: (_) => setState(() => _showMap = true),
              ),
            ],
          ),
      ],
    ),
  );

  void _expandRadius() {
    final next = _radiusOptionsMeters
        .where((radius) => radius > _searchedRadiusMeters)
        .firstOrNull;
    if (next == null || _loading) return;
    setState(() => _selectedRadiusMeters = next);
    _searchMosques();
  }

  Widget _buildBody() {
    if (_location == null) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _buildMessage(
        icon: Icons.location_off,
        text: (_errorKey ?? 'Nearest_Mosque_Search_Error').tr(),
        action: Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(onPressed: _searchMosques, child: Text('Reload'.tr())),
            if (_errorKey?.contains('Location') == true)
              TextButton(
                onPressed: () async {
                  final opened =
                      _errorKey ==
                          'Nearest_Mosque_Location_Permission_Denied_Forever'
                      ? await Geolocator.openAppSettings()
                      : await Geolocator.openLocationSettings();
                  if (!opened && mounted) _message('Qiblah_Settings_Error');
                },
                child: Text('Qiblah_Open_Settings'.tr()),
              ),
          ],
        ),
      );
    }
    if (_mosques.isEmpty) {
      return _buildMessage(
        icon: Icons.mosque,
        text: 'Nearest_Mosque_No_Results'.tr(
          args: [formatMosqueDistance(_searchedRadiusMeters.toDouble())],
        ),
        action: TextButton(
          onPressed: _loading
              ? null
              : _radiusOptionsMeters.any((r) => r > _searchedRadiusMeters)
              ? _expandRadius
              : _searchMosques,
          child: Text(
            (_radiusOptionsMeters.any((r) => r > _searchedRadiusMeters)
                    ? 'Mosque_Expand_Radius'
                    : 'Reload')
                .tr(),
          ),
        ),
      );
    }
    Widget list() => ListView.builder(
      key: const PageStorageKey('mosque_results'),
      padding: const EdgeInsets.all(16),
      itemCount: _mosques.length,
      itemBuilder: (context, index) => _buildMosqueCard(_mosques[index]),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              Expanded(child: _buildMap()),
              Expanded(child: list()),
            ],
          );
        }
        if (!_showMap) return list();
        final selected = _mosques
            .where((mosque) => mosque.id == _selectedMosque)
            .firstOrNull;
        return Column(
          children: [
            Expanded(child: _buildMap()),
            if (selected != null)
              Flexible(
                child: SingleChildScrollView(child: _buildMosqueCard(selected)),
              ),
          ],
        );
      },
    );
  }

  void _selectMosque(MosquePlace mosque) {
    setState(() => _selectedMosque = mosque.id);
    if (_mapReady) {
      _mapController.move(LatLng(mosque.latitude, mosque.longitude), 15);
    }
  }

  void _message(String key) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(key.tr())));
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('Mosque_Launch_Failed');
      }
    } catch (_) {
      _message('Mosque_Launch_Failed');
    }
  }

  Widget _buildMap() {
    final MosqueSearchLocation location = _location!;
    final LatLng center = _mosques.isNotEmpty
        ? LatLng(_mosques.first.latitude, _mosques.first.longitude)
        : LatLng(location.latitude, location.longitude);

    if (widget.mapBuilder != null) {
      return KeyedSubtree(
        key: const ValueKey('mosque_map_panel'),
        child: widget.mapBuilder!(location, _mosques),
      );
    }
    return Padding(
      key: const ValueKey('mosque_map_panel'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('$_savedAt'),
              mapController: _mapController,
              options: MapOptions(
                onMapReady: () => _mapReady = true,
                initialCameraFit: _mosques.isEmpty
                    ? null
                    : CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([
                          LatLng(location.latitude, location.longitude),
                          ..._mosques.map(
                            (m) => LatLng(m.latitude, m.longitude),
                          ),
                        ]),
                        padding: const EdgeInsets.all(48),
                        maxZoom: 15,
                      ),
                initialCenter: center,
                initialZoom: _initialZoomForRadius(_searchedRadiusMeters),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bplusplus.muslim',
                  errorTileCallback: (_, __, ___) {
                    if (!mounted || _mapTilesFailed) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_mapTilesFailed) {
                        setState(() => _mapTilesFailed = true);
                      }
                    });
                  },
                ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.my_location,
                        color: AppPalette.of(context).accent,
                        size: 34,
                      ),
                    ),
                    ..._mosques.map(
                      (MosquePlace mosque) => Marker(
                        point: LatLng(mosque.latitude, mosque.longitude),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _selectMosque(mosque),
                          child: Container(
                            decoration: _selectedMosque == mosque.id
                                ? BoxDecoration(
                                    color: AppPalette.of(context).accentSurface,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Image.asset('assets/mosque/mosque.png'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Material(
                color: AppPalette.of(context).panel,
                child: TextButton(
                  onPressed: () => _openExternal(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                  child: const Text(
                    '\u00a9 OpenStreetMap contributors',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
            if (_mapTilesFailed)
              PositionedDirectional(
                top: 8,
                start: 8,
                end: 8,
                child: Material(
                  color: AppPalette.of(context).panel,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Mosque_Map_Unavailable'.tr()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMosqueCard(MosquePlace mosque) {
    final bool hasAddress = mosque.address.trim().isNotEmpty;

    return Card(
      color: AppPalette.of(context).canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppPalette.of(context).border),
      ),
      child: ListTile(
        key: ValueKey('mosque_${mosque.id}'),
        selected: _selectedMosque == mosque.id,
        selectedTileColor: AppPalette.of(context).accentSurface,
        leading: Image.asset('assets/mosque/mosque.png', width: 36),
        title: Text(
          mosque.name == 'Nearest_Mosque_Unknown_Name'
              ? mosque.name.tr()
              : mosque.name,
          style: TextStyle(
            color: AppPalette.of(context).text,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          hasAddress
              ? '${formatMosqueDistance(mosque.distanceMeters)} - ${mosque.address}'
              : formatMosqueDistance(mosque.distanceMeters),
          style: TextStyle(color: AppPalette.of(context).text),
        ),
        trailing: IconButton(
          tooltip: 'Nearest_Mosque_Open_Maps'.tr(),
          icon: Icon(Icons.directions, color: AppPalette.of(context).accent),
          onPressed: () => _showMosqueOptions(mosque),
        ),
        onTap: () => _selectMosque(mosque),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: AppPalette.of(context).accent, size: 52),
              const SizedBox(height: 16),
              Text(
                text,
                style: TextStyle(
                  color: AppPalette.of(context).text,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              action,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMosqueOptions(MosquePlace mosque) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.of(context).panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Image.asset('assets/mosque/mosque.png', width: 32),
                title: Text(
                  mosque.name == 'Nearest_Mosque_Unknown_Name'
                      ? mosque.name.tr()
                      : mosque.name,
                  style: TextStyle(
                    color: AppPalette.of(context).text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  formatMosqueDistance(mosque.distanceMeters),
                  style: TextStyle(color: AppPalette.of(context).text),
                ),
              ),
              Divider(color: AppPalette.of(context).border),
              ListTile(
                leading: Icon(Icons.map, color: AppPalette.of(context).accent),
                title: Text(
                  'Nearest_Mosque_Open_Maps'.tr(),
                  style: TextStyle(color: AppPalette.of(context).text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps(mosque);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.navigation,
                  color: AppPalette.of(context).accent,
                ),
                title: Text(
                  'Nearest_Mosque_Open_Waze'.tr(),
                  style: TextStyle(color: AppPalette.of(context).text),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openWaze(mosque);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: AppPalette.of(context).accent),
                title: Text(
                  'Nearest_Mosque_Copy_Coordinates'.tr(),
                  style: TextStyle(color: AppPalette.of(context).text),
                ),
                onTap: () async {
                  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                    this.context,
                  );
                  Navigator.pop(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${mosque.latitude},${mosque.longitude}',
                    ),
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Copied'.tr())),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps(MosquePlace mosque) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${mosque.latitude},${mosque.longitude}',
    );
    await _openExternal(uri);
  }

  Future<void> _openWaze(MosquePlace mosque) async {
    final Uri uri = Uri.parse(
      'https://waze.com/ul?ll=${mosque.latitude},${mosque.longitude}&navigate=yes',
    );
    await _openExternal(uri);
  }

  double _initialZoomForRadius(int radiusMeters) {
    if (radiusMeters <= 3000) return 13;
    if (radiusMeters <= 5000) return 12;
    if (radiusMeters <= 10000) return 11;
    return 10;
  }
}
