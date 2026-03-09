import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import '../../utils/notification_service.dart';
import '../../utils/shared_preference_methods.dart'
    as shared_preference_methods;

class PrayerNotificationsPageClass extends StatefulWidget {
  final Future<SharedPreferences> prefs;

  const PrayerNotificationsPageClass({super.key, required this.prefs});

  @override
  State<PrayerNotificationsPageClass> createState() =>
      _PrayerNotificationsPageClassState();
}

class _PrayerNotificationsPageClassState
    extends State<PrayerNotificationsPageClass> {
  static const detailsStyle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor);
  static const helperStyle =
      TextStyle(fontSize: 13, color: highlightedColor, height: 1.4);

  bool prayerNotification = false;

  @override
  void initState() {
    super.initState();
    EasyLoading.showInfo("Prayer_Notifications_Loading_Tip".tr());
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        _updatePrayerNotifications();
      });
    } catch (e) {
      if (kDebugMode) {
        EasyLoading.dismiss();
        print(e);
      }
    }
  }

  Future<void> _updatePrayerNotifications() async {
    final bool sharedPrayerNotification =
        await shared_preference_methods.checkExistenceData(
      widget.prefs,
      'prayerNotification',
    );
    bool prayerNotificationValue = false;

    if (sharedPrayerNotification) {
      prayerNotificationValue = await shared_preference_methods.getBoolData(
        widget.prefs,
        'prayerNotification',
      );
    } else {
      await shared_preference_methods.setBoolData(
        widget.prefs,
        'prayerNotification',
        prayerNotificationValue,
      );
    }

    if (!mounted) {
      EasyLoading.dismiss();
      return;
    }

    setState(() {
      prayerNotification = prayerNotificationValue;
    });
    EasyLoading.dismiss();
  }

  Future<void> _changePrayerNotification(bool value) async {
    if (!Platform.isAndroid) {
      EasyLoading.showError(
        "Prayer_Notifications_Not_Supported".tr(),
        dismissOnTap: true,
      );
      return;
    }

    if (value) {
      final bool notificationGranted =
          await Permission.notification.request().isGranted;
      if (!notificationGranted) {
        EasyLoading.showError(
          "Unable to get notifications permission".tr(),
          dismissOnTap: true,
        );
        return;
      }

      final bool exactAlarmGranted =
          await NotificationService().requestExactAlarmPermissionIfNeeded();
      if (!exactAlarmGranted) {
        EasyLoading.showInfo(
          "Prayer_Notifications_Exact_Alarm_Info".tr(),
          dismissOnTap: true,
        );
      }
    } else {
      await NotificationService().clearAllNotifications();
    }

    final bool result = await shared_preference_methods.setBoolData(
      widget.prefs,
      'prayerNotification',
      value,
    );
    if (!result) {
      EasyLoading.showError("Couldn't save data".tr(), dismissOnTap: true);
    }
    await _updatePrayerNotifications();
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: settingsWidgetBGColor,
        border: Border.all(color: boxesBorderColor, width: 1),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Prayer_Notifications_Title".tr(),
          style: const TextStyle(color: textColor),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prayer_Notifications_Title".tr(),
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Prayer_Notifications_Desc".tr(),
                          style: helperStyle,
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 20,
                    thickness: 5,
                    color: dividerColor,
                  ),
                  _buildCard(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Prayer_Notifications_Enable_Title".tr(),
                                style: detailsStyle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Prayer_Notifications_Enable_Desc".tr(),
                                style: helperStyle,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Switch(
                            activeThumbColor: textColor,
                            inactiveThumbColor: Colors.grey,
                            value: prayerNotification,
                            onChanged: _changePrayerNotification,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
