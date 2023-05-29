import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:muslim/shared/loading_indicator.dart';
import 'package:muslim/UI/qiblah/qiblah_compass.dart';

class QiblahClass extends StatefulWidget {
  const QiblahClass({Key? key}) : super(key: key);
  @override
  _QiblahClassState createState() => _QiblahClassState();
}

class _QiblahClassState extends State<QiblahClass> {
  final _deviceSupport = FlutterQiblah.androidDeviceSensorSupport();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Qiblah Compass'),
        ),
        body: FutureBuilder(
          future: _deviceSupport,
          builder: (_, AsyncSnapshot<bool?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return LoadingIndicator();
            }
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error.toString()}"),
              );
            }

            if (snapshot.data!) {
              return QiblahCompass();
            }else{
              return LoadingIndicator();
            }
          },
        ),
      );
  }
}