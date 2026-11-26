import 'package:muslim/shared/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah_advanced/flutter_qiblah_advanced.dart';
import 'package:muslim/shared/loading_indicator.dart';

import 'location_error_widget.dart';
import 'qiblah_compass.dart';

class QiblahClass extends StatefulWidget {
  const QiblahClass({super.key, this.sensorSupport});
  final Future<bool?> Function()? sensorSupport;

  @override
  State<QiblahClass> createState() => _QiblahClassState();
}

class _QiblahClassState extends State<QiblahClass> {
  late Future<bool?> _deviceSupport;

  @override
  void initState() {
    super.initState();
    _deviceSupport = _checkSupport();
  }

  Future<bool?> _checkSupport() async =>
      await (widget.sensorSupport?.call() ??
              FlutterQiblah.androidDeviceSensorSupport())
          .timeout(const Duration(seconds: 10));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Qiblah_Title',
        style: TextStyle(color: AppPalette.of(context).text),
      ).tr(),
      iconTheme: IconThemeData(color: AppPalette.of(context).text),
      backgroundColor: AppPalette.of(context).canvas,
    ),
    backgroundColor: AppPalette.of(context).panel,
    body: SafeArea(
      child: FutureBuilder<bool?>(
        future: _deviceSupport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return LocationErrorWidget(
              error: 'Qiblah_Sensor_Error'.tr(),
              callback: () => setState(() {
                _deviceSupport = _checkSupport();
              }),
            );
          }
          if (snapshot.data != true) {
            return LocationErrorWidget(error: 'Qiblah_Unsupported'.tr());
          }
          return const QiblahCompass();
        },
      ),
    ),
  );
}
