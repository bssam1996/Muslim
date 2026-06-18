import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:muslim/shared/constants.dart';
import 'package:muslim/utils/mosque_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class NearestMosquePageClass extends StatefulWidget {
  const NearestMosquePageClass({super.key});

  @override
  State<NearestMosquePageClass> createState() => _NearestMosquePageClassState();
}

class _NearestMosquePageClassState extends State<NearestMosquePageClass> {
  static const List<int> _radiusOptionsMeters = <int>[1000, 3000, 5000, 10000, 25000];

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
      _searchMosques();
    });
  }

  Future<void> _searchMosques() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    try {
      final MosqueSearchLocation location = await getMosqueSearchLocation();
      final MosqueSearchResult result = await findNearbyMosques(
        latitude: location.latitude,
        longitude: location.longitude,
        initialRadiusMeters: _selectedRadiusMeters,
      );

      if (!mounted) return;
      setState(() {
        _location = location;
        _mosques = result.mosques;
        _searchedRadiusMeters = result.radiusMeters;
        _loading = false;
      });
    } on MosqueLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKey = e.translationKey;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorKey = 'Nearest_Mosque_Search_Error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: interpolatedColor3,
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: textColor),
        title: Text(
          'Nearest_Mosque_Title'.tr(),
          style: const TextStyle(color: textColor),
        ),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              primaryColor,
              interpolatedColor5,
              interpolatedColor6,
              interpolatedColor7,
              thirdColor,
              interpolatedColor1,
              interpolatedColor2,
              interpolatedColor3,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildSearchControls(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedRadiusMeters,
              dropdownColor: primaryColor,
              decoration: InputDecoration(
                labelText: 'Nearest_Mosque_Radius'.tr(),
                labelStyle: const TextStyle(color: textColor),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: boxesBorderColor),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: highlightedBoxesBorderColor),
                ),
              ),
              iconEnabledColor: textColor,
              style: const TextStyle(color: textColor),
              items: _radiusOptionsMeters
                  .map(
                    (int radius) => DropdownMenuItem<int>(
                      value: radius,
                      child: Text(formatMosqueDistance(radius.toDouble())),
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
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _searchMosques,
            style: ElevatedButton.styleFrom(
              backgroundColor: highlightedColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
            icon: const Icon(Icons.search),
            label: Text('Search'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: highlightedTextColor),
            const SizedBox(height: 16),
            Text(
              'Nearest_Mosque_Loading'.tr(),
              style: const TextStyle(color: textColor),
            ),
          ],
        ),
      );
    }

    if (_errorKey != null) {
      return _buildMessage(
        icon: Icons.location_off,
        text: _errorKey!.tr(),
        action: ElevatedButton(
          onPressed: _searchMosques,
          child: Text('Reload'.tr()),
        ),
      );
    }

    if (_location == null) {
      return const SizedBox.shrink();
    }

    if (_mosques.isEmpty) {
      return _buildMessage(
        icon: Icons.mosque,
        text: 'Nearest_Mosque_No_Results'.tr(
          args: <String>[
            formatMosqueDistance(_searchedRadiusMeters.toDouble()),
          ],
        ),
        action: ElevatedButton(
          onPressed: _searchMosques,
          child: Text('Reload'.tr()),
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (_location!.fromFallback)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Nearest_Mosque_Using_Last_Location'.tr(),
              style: const TextStyle(color: highlightedTextColor),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Nearest_Mosque_Result_Count'.tr(
              args: <String>[
                _mosques.length.toString(),
                formatMosqueDistance(_searchedRadiusMeters.toDouble()),
              ],
            ),
            style: const TextStyle(color: textColor),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 260, child: _buildMap()),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _mosques.length,
            itemBuilder: (BuildContext context, int index) {
              return _buildMosqueCard(_mosques[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final MosqueSearchLocation location = _location!;
    final LatLng center = _mosques.isNotEmpty
        ? LatLng(_mosques.first.latitude, _mosques.first.longitude)
        : LatLng(location.latitude, location.longitude);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: _initialZoomForRadius(_searchedRadiusMeters),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bplusplus.muslim',
              errorTileCallback: (_, __, ___) {},
            ),
            MarkerLayer(
              markers: <Marker>[
                Marker(
                  point: LatLng(location.latitude, location.longitude),
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.my_location,
                    color: highlightedTextColor,
                    size: 34,
                  ),
                ),
                ..._mosques.map(
                  (MosquePlace mosque) => Marker(
                    point: LatLng(mosque.latitude, mosque.longitude),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showMosqueOptions(mosque),
                      child: Image.asset('assets/mosque/mosque.png'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMosqueCard(MosquePlace mosque) {
    final bool hasAddress = mosque.address.trim().isNotEmpty;

    return Card(
      color: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: boxesBorderColor),
      ),
      child: ListTile(
        leading: Image.asset('assets/mosque/mosque.png', width: 36),
        title: Text(
          mosque.name.tr(),
          style: const TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          hasAddress
              ? '${formatMosqueDistance(mosque.distanceMeters)} - ${mosque.address}'
              : formatMosqueDistance(mosque.distanceMeters),
          style: const TextStyle(color: textColor),
        ),
        trailing: IconButton(
          tooltip: 'Nearest_Mosque_Open_Maps'.tr(),
          icon: const Icon(Icons.directions, color: highlightedTextColor),
          onPressed: () => _showMosqueOptions(mosque),
        ),
        onTap: () => _showMosqueOptions(mosque),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: highlightedTextColor, size: 52),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(color: textColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }

  Future<void> _showMosqueOptions(MosquePlace mosque) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: thirdColor,
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
                  mosque.name.tr(),
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  formatMosqueDistance(mosque.distanceMeters),
                  style: const TextStyle(color: textColor),
                ),
              ),
              const Divider(color: dividerColor),
              ListTile(
                leading: const Icon(Icons.map, color: highlightedTextColor),
                title: Text(
                  'Nearest_Mosque_Open_Maps'.tr(),
                  style: const TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps(mosque);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.navigation,
                  color: highlightedTextColor,
                ),
                title: Text(
                  'Nearest_Mosque_Open_Waze'.tr(),
                  style: const TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openWaze(mosque);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: highlightedTextColor),
                title: Text(
                  'Nearest_Mosque_Copy_Coordinates'.tr(),
                  style: const TextStyle(color: textColor),
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
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWaze(MosquePlace mosque) async {
    final Uri uri = Uri.parse(
      'https://waze.com/ul?ll=${mosque.latitude},${mosque.longitude}&navigate=yes',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  double _initialZoomForRadius(int radiusMeters) {
    if (radiusMeters <= 3000) return 13;
    if (radiusMeters <= 5000) return 12;
    if (radiusMeters <= 10000) return 11;
    return 10;
  }
}
