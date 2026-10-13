import 'package:muslim/shared/app_status.dart';
import 'package:muslim/shared/app_theme.dart';
import 'dart:async';

import '../../utils/radio_playback.dart';
import '../../utils/serial_task_queue.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/UI/radio/radio_station.dart';
import 'package:muslim/UI/radio/radio_stations_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _favoriteRadioStationIdsKey = 'favorite_radio_station_ids';

class RadioPageClass extends StatefulWidget {
  const RadioPageClass({super.key, this.createPlayer});
  final RadioAudioBackend Function()? createPlayer;

  @override
  State<RadioPageClass> createState() => _RadioPageClassState();
}

class _RadioPageClassState extends State<RadioPageClass> {
  final TextEditingController _searchController = TextEditingController();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  String _query = '';
  bool _favoritesOnly = false;
  bool _listMode = false;
  bool _preferencesLoaded = false;
  final _favoriteWrites = SerialTaskQueue();
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
    return stations
        .where(
          (station) =>
              station.matches(_query) &&
              (!_favoritesOnly || _favoriteStationIds.contains(station.id)),
        )
        .toList();
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
      final Set<int> stationIds = radioStations
          .map((station) => station.id)
          .toSet();
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
        _listMode = prefs.getBool('radio_list_mode') ?? false;
        _preferencesLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _preferencesLoaded = true);
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _saveFavoriteStations() {
    final favoriteIds = _favoriteStationIds.toList()..sort();
    return _favoriteWrites.run(() async {
      try {
        final prefs = await _prefs;
        if (!await prefs.setStringList(
          _favoriteRadioStationIdsKey,
          favoriteIds.map((id) => id.toString()).toList(),
        )) {
          throw StateError('Save failed');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Radio_Save_Failed'.tr())));
        }
      }
    });
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
      builder: (context) => _RadioPlayerDialog(
        station: station,
        createPlayer: widget.createPlayer,
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: AppPalette.of(context).text),
      decoration: InputDecoration(
        hintText: 'Radio_Search_Hint'.tr(),
        hintStyle: TextStyle(color: AppPalette.of(context).accent),
        prefixIcon: Icon(Icons.search, color: AppPalette.of(context).text),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.clear, color: AppPalette.of(context).text),
                onPressed: _searchController.clear,
              ),
        filled: true,
        fillColor: AppPalette.of(context).panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppPalette.of(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppPalette.of(context).accent),
        ),
      ),
    );
  }

  Widget _buildStationGrid(List<RadioStation> stations) {
    if (!_preferencesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<RadioStation> visibleStations = _visibleStations(stations);
    if (visibleStations.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AppStatus(
            message:
                (_favoritesOnly ? 'Radio_No_Favorites' : 'Radio_No_Results')
                    .tr(),
            actionLabel: _favoritesOnly ? 'Radio_All_Stations'.tr() : null,
            onAction: _favoritesOnly
                ? () => setState(() => _favoritesOnly = false)
                : null,
            icon: Icons.radio_outlined,
          ),
        ),
      );
    }

    if (_listMode || MediaQuery.textScalerOf(context).scale(15) > 19) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: visibleStations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final station = visibleStations[index];
          final favorite = _favoriteStationIds.contains(station.id);
          return Card(
            child: ListTile(
              key: ValueKey('radio_station_${station.id}'),
              title: Text(station.nameForLocale(context)),
              onTap: () => _openRadio(station),
              trailing: IconButton(
                tooltip:
                    (favorite ? 'Radio_Remove_Favorite' : 'Radio_Add_Favorite')
                        .tr(),
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => _toggleFavorite(station),
              ),
            ),
          );
        },
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
            mainAxisExtent: 210,
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
        title: Text(
          'Radio_Title',
          style: TextStyle(color: AppPalette.of(context).text),
        ).tr(),
        backgroundColor: AppPalette.of(context).canvas,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
      ),
      backgroundColor: AppPalette.of(context).panel,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.of(context).canvas,
              AppPalette.of(context).panel,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
              AppPalette.of(context).canvas,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _buildSearchField(),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      key: const ValueKey('radio_favorites_filter'),
                      label: Text('Radio_Favorites'.tr()),
                      selected: _favoritesOnly,
                      onSelected: (value) =>
                          setState(() => _favoritesOnly = value),
                    ),
                    FilterChip(
                      key: const ValueKey('radio_list_mode'),
                      label: Text('Radio_List_Mode'.tr()),
                      selected: _listMode,
                      onSelected: !_preferencesLoaded
                          ? null
                          : (value) {
                              setState(() => _listMode = value);
                              unawaited(
                                _favoriteWrites.run(() async {
                                  try {
                                    final prefs = await _prefs;
                                    if (!await prefs.setBool(
                                      'radio_list_mode',
                                      value,
                                    )) {
                                      throw StateError('Save failed');
                                    }
                                  } catch (_) {
                                    if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text('Radio_Save_Failed'.tr()),
                                      ),
                                    );
                                  }
                                }),
                              );
                            },
                    ),
                  ],
                ),
                Expanded(child: _buildStationGrid(radioStations)),
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
  Widget build(BuildContext context) => Card(
    key: ValueKey('radio_station_${station.id}'),
    child: Column(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radio,
                    size: 36,
                    color: AppPalette.of(context).accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    station.nameForLocale(context),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.of(context).text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            tooltip:
                (isFavorite ? 'Radio_Remove_Favorite' : 'Radio_Add_Favorite')
                    .tr(),
            onPressed: onFavoritePressed,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: AppPalette.of(context).accent,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RadioPlayerDialog extends StatefulWidget {
  const _RadioPlayerDialog({required this.station, this.createPlayer});
  final RadioStation station;
  final RadioAudioBackend Function()? createPlayer;
  @override
  State<_RadioPlayerDialog> createState() => _RadioPlayerDialogState();
}

class _RadioPlayerDialogState extends State<_RadioPlayerDialog> {
  late final RadioPlayback _playback;
  @override
  void initState() {
    super.initState();
    _playback = RadioPlayback(createPlayer: widget.createPlayer);
    unawaited(_playback.connect(widget.station.url));
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _playback,
    builder: (context, _) {
      final state = _playback.state;
      return AlertDialog(
        scrollable: true,
        title: Text(widget.station.nameForLocale(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio, size: 48),
            const SizedBox(height: 12),
            if (state == RadioPlaybackState.buffering)
              const CircularProgressIndicator(),
            Text(
              (switch (state) {
                RadioPlaybackState.buffering => 'Radio_Buffering',
                RadioPlaybackState.playing => 'Radio_Playing',
                RadioPlaybackState.paused => 'Radio_Paused',
                RadioPlaybackState.error => 'Radio_Play_Error',
              }).tr(),
            ),
            const SizedBox(height: 12),
            Text(
              'Radio_Close_Stops'.tr(),
              style: TextStyle(color: AppPalette.of(context).muted),
            ),
          ],
        ),
        actions: [
          if (state == RadioPlaybackState.error)
            TextButton(
              onPressed: () => _playback.connect(widget.station.url),
              child: Text('Reload'.tr()),
            )
          else
            TextButton.icon(
              onPressed: state == RadioPlaybackState.buffering
                  ? null
                  : _playback.toggle,
              icon: Icon(
                state == RadioPlaybackState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              label: Text(
                (state == RadioPlaybackState.playing
                        ? 'Radio_Pause_Action'
                        : 'Radio_Play_Action')
                    .tr(),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'.tr()),
          ),
        ],
      );
    },
  );
}
