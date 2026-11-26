import 'package:muslim/shared/app_theme.dart';
import 'dart:async';
import 'dart:math' show pi;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah_advanced/flutter_qiblah_advanced.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:muslim/shared/loading_indicator.dart';

import 'location_error_widget.dart';

class QiblahCompass extends StatefulWidget {
  const QiblahCompass({super.key, this.checkLocation, this.requestPermissions});
  final Future<LocationStatus> Function()? checkLocation;
  final Future<LocationPermission> Function()? requestPermissions;

  @override
  State<QiblahCompass> createState() => _QiblahCompassState();
}

class _QiblahCompassState extends State<QiblahCompass>
    with WidgetsBindingObserver {
  late Future<LocationStatus> _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = _readStatus(requestPermission: true);
  }

  Future<LocationStatus> _readStatus({bool requestPermission = false}) async {
    final check = widget.checkLocation ?? FlutterQiblah.checkLocationStatus;
    var status = await check().timeout(const Duration(seconds: 10));
    if (mounted &&
        requestPermission &&
        status.enabled &&
        status.status == LocationPermission.denied) {
      await (widget.requestPermissions ?? FlutterQiblah.requestPermissions)();
      if (mounted) status = await check().timeout(const Duration(seconds: 10));
    }
    return status;
  }

  void _retry() => setState(() {
    _status = _readStatus(requestPermission: true);
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _status = _readStatus();
      });
    }
  }

  Future<void> _openSettings({required bool appSettings}) async {
    try {
      final opened = await (appSettings
          ? Geolocator.openAppSettings()
          : Geolocator.openLocationSettings());
      if (!opened) {
        throw StateError('Settings unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Qiblah_Settings_Error'.tr())));
      }
    }
    if (mounted) {
      setState(() {
        _status = _readStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LocationStatus>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LoadingIndicator();
      }
      final status = snapshot.data;
      if (snapshot.hasError || status == null) {
        return LocationErrorWidget(
          error: 'Qiblah_Location_Error'.tr(),
          callback: _retry,
        );
      }
      if (!status.enabled) {
        return LocationErrorWidget(
          error: 'Qiblah_Location_Disabled'.tr(),
          actionLabel: 'Qiblah_Open_Settings'.tr(),
          callback: () => _openSettings(appSettings: false),
          onRetry: _retry,
        );
      }
      switch (status.status) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return const QiblahCompassWidget();
        case LocationPermission.denied:
          return LocationErrorWidget(
            error: 'Qiblah_Permission_Denied'.tr(),
            callback: _retry,
          );
        case LocationPermission.deniedForever:
          return LocationErrorWidget(
            error: 'Qiblah_Permission_Permanent'.tr(),
            actionLabel: 'Qiblah_Open_Settings'.tr(),
            callback: () => _openSettings(appSettings: true),
            onRetry: _retry,
          );
        default:
          return LocationErrorWidget(
            error: 'Qiblah_Location_Error'.tr(),
            callback: _retry,
          );
      }
    },
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class QiblahCompassWidget extends StatefulWidget {
  const QiblahCompassWidget({super.key, this.directions});
  final Stream<QiblahDirection> Function()? directions;

  @override
  State<QiblahCompassWidget> createState() => _QiblahCompassWidgetState();
}

class _QiblahCompassWidgetState extends State<QiblahCompassWidget> {
  late Stream<QiblahDirection> _directions;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      _directions = (widget.directions?.call() ?? FlutterQiblah.qiblahStream)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      _directions = Stream.error(error);
    }
  }

  @override
  void dispose() {
    if (widget.directions == null) FlutterQiblah().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QiblahDirection>(
    stream: _directions,
    builder: (context, snapshot) {
      final direction = snapshot.data;
      if (!snapshot.hasError &&
          direction == null &&
          snapshot.connectionState != ConnectionState.done) {
        return const LoadingIndicator();
      }
      if (snapshot.hasError ||
          direction == null ||
          !direction.direction.isFinite ||
          !direction.qiblah.isFinite ||
          !direction.offset.isFinite) {
        return LocationErrorWidget(
          error: 'Qiblah_Sensor_Error'.tr(),
          callback: () => setState(() {
            if (widget.directions == null) FlutterQiblah().dispose();
            _connect();
          }),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: direction.direction * (pi / 180) * -1,
              child: SvgPicture.asset(
                'assets/qiblah/compass.svg',
                theme: SvgTheme(currentColor: AppPalette.of(context).text),
              ),
            ),
            Transform.rotate(
              angle: direction.qiblah * (pi / 180) * -1,
              child: SvgPicture.asset(
                'assets/qiblah/needle.svg',
                fit: BoxFit.contain,
                height: 270,
              ),
            ),
            Positioned(
              bottom: 8,
              child: Text(
                '${direction.offset.toStringAsFixed(1)}\u00b0',
                style: TextStyle(color: AppPalette.of(context).text),
              ),
            ),
          ],
        ),
      );
    },
  );
}
