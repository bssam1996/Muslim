import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/radio/radio_station.dart';
import 'package:muslim/UI/radio/radio_stations_data.dart';
import 'package:muslim/shared/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _favoriteRadioStationIdsKey = 'favorite_radio_station_ids';

class RadioPageClass extends StatefulWidget {
  const RadioPageClass({super.key});

  @override
  State<RadioPageClass> createState() => _RadioPageClassState();
}

class _RadioPageClassState extends State<RadioPageClass> {
  final TextEditingController _searchController = TextEditingController();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String _query = '';
  Set<int> _favoriteStationIds = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadFavoriteStations());
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RadioStation> _filterStations(List<RadioStation> stations) {
    return stations.where((station) => station.matches(_query)).toList();
  }

  List<RadioStation> _visibleStations(List<RadioStation> stations) {
    final List<RadioStation> filteredStations = _filterStations(stations);
    final List<RadioStation> favorites = filteredStations
        .where((station) => _favoriteStationIds.contains(station.id))
        .toList();
    final List<RadioStation> others = filteredStations
        .where((station) => !_favoriteStationIds.contains(station.id))
        .toList();
    return <RadioStation>[...favorites, ...others];
  }

  Future<void> _loadFavoriteStations() async {
    try {
      final SharedPreferences prefs = await _prefs;
      final List<String> storedIds =
          prefs.getStringList(_favoriteRadioStationIdsKey) ?? <String>[];
      final Set<int> stationIds =
          radioStations.map((station) => station.id).toSet();
      final Set<int> favoriteIds = storedIds
          .map(int.tryParse)
          .whereType<int>()
          .where(stationIds.contains)
          .toSet();
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteStationIds = favoriteIds;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _saveFavoriteStations() async {
    try {
      final SharedPreferences prefs = await _prefs;
      final List<int> favoriteIds = _favoriteStationIds.toList()..sort();
      await prefs.setStringList(
        _favoriteRadioStationIdsKey,
        favoriteIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void _toggleFavorite(RadioStation station) {
    setState(() {
      if (_favoriteStationIds.contains(station.id)) {
        _favoriteStationIds.remove(station.id);
      } else {
        _favoriteStationIds.add(station.id);
      }
    });
    unawaited(_saveFavoriteStations());
  }

  void _openRadio(RadioStation station) {
    showDialog<void>(
      context: context,
      builder: (context) => _RadioPlayerDialog(station: station),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: 'Radio_Search_Hint'.tr(),
        hintStyle: const TextStyle(color: highlightedColor),
        prefixIcon: const Icon(Icons.search, color: textColor),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: textColor),
                onPressed: _searchController.clear,
              ),
        filled: true,
        fillColor: settingsWidgetBGColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: boxesBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: highlightedColor),
        ),
      ),
    );
  }

  Widget _buildStationGrid(List<RadioStation> stations) {
    final List<RadioStation> visibleStations = _visibleStations(stations);
    if (visibleStations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Radio_No_Results'.tr(),
            style: const TextStyle(color: highlightedColor, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.05,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: visibleStations.length,
          itemBuilder: (context, index) {
            final RadioStation station = visibleStations[index];
            return _RadioStationTile(
              station: station,
              isFavorite: _favoriteStationIds.contains(station.id),
              onFavoritePressed: () => _toggleFavorite(station),
              onTap: () => _openRadio(station),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Radio_Title',
          style: TextStyle(color: textColor),
        ).tr(),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: textColor),
      ),
      backgroundColor: thirdColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              interpolatedColor7,
              thirdColor,
              interpolatedColor1,
              interpolatedColor2,
              interpolatedColor3,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _buildSearchField(),
                Expanded(
                  child: _buildStationGrid(radioStations),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioStationTile extends StatelessWidget {
  final RadioStation station;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback onTap;

  const _RadioStationTile({
    required this.station,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: primaryColor,
      color: settingsWidgetBGColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: boxesBorderColor),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: highlightedColor),
                    ),
                    child: Image.asset('assets/radio/radio128.png'),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Center(
                          child: Text(
                            // station.nameForLocale(context),
                            station.englishName,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Center(
                          child: Text(
                            // station.nameForLocale(context),
                            station.arabicName,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // const Icon(
                  //   Icons.play_circle_outline,
                  //   color: highlightedTextColor,
                  // ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton(
              tooltip: isFavorite
                  ? 'Radio_Remove_Favorite'.tr()
                  : 'Radio_Add_Favorite'.tr(),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? highlightedTextColor : textColor,
              ),
              onPressed: onFavoritePressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioPlayerDialog extends StatefulWidget {
  final RadioStation station;

  const _RadioPlayerDialog({required this.station});

  @override
  State<_RadioPlayerDialog> createState() => _RadioPlayerDialogState();
}

class _RadioPlayerDialogState extends State<_RadioPlayerDialog> {
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _stateSubscription;
  PlayerState _playerState = PlayerState.stopped;
  bool _isLoading = true;
  bool _hasError = false;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
        _isLoading = false;
      });
    });
    unawaited(_play());
  }

  Future<void> _play() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await _player.play(UrlSource(widget.station.url));
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    unawaited(_player.stop());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: settingsWidgetBGColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.station.nameForLocale(context),
        style: const TextStyle(color: textColor, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/radio/radio128.png', width: 72, height: 72),
          const SizedBox(height: 16),
          if (_isLoading)
            Column(
              children: [
                const CircularProgressIndicator(color: highlightedColor),
                const SizedBox(height: 12),
                Text(
                  'Radio_Buffering'.tr(),
                  style: const TextStyle(color: highlightedColor),
                ),
              ],
            )
          else if (_hasError)
            Text(
              'Radio_Play_Error'.tr(),
              style: const TextStyle(color: highlightedColor),
              textAlign: TextAlign.center,
            )
          else
            Text(
              _isPlaying ? 'Radio_Playing'.tr() : 'Radio_Paused'.tr(),
              style: const TextStyle(color: highlightedColor),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (!_hasError)
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: textColor,
              size: 36,
            ),
            onPressed: _isLoading ? null : _togglePlayback,
          )
        else
          TextButton(
            onPressed: _play,
            child: Text(
              'Reload'.tr(),
              style: const TextStyle(color: highlightedTextColor),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close'.tr(),
            style: const TextStyle(color: highlightedTextColor),
          ),
        ),
      ],
    );
  }
}
