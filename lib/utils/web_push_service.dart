import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/constants.dart';
import 'helper.dart' as helper;
import 'web_push_bridge.dart';

const webPushEnabledKey = 'web_push_enabled_v1';
const webPushPrayersKey = 'web_push_prayers_v1';
const webPushLanguageKey = 'web_push_language_v1';

class WebPushException implements Exception {
  const WebPushException(this.code);
  final String code;
  String get translationKey => switch (code) {
    'unsupported' => 'Web_Push_Unsupported',
    'setup_required' => 'Web_Push_Setup_Required',
    'permission_denied' => 'Web_Push_Permission_Denied',
    'location_required' => 'Web_Push_Location_Required',
    _ => 'Web_Push_Error',
  };
}

class WebPushStatus {
  const WebPushStatus({
    this.enabled = false,
    this.subscribed = false,
    this.permission = 'default',
    this.nextPrayer,
    this.nextAt,
    this.timeZone,
  });
  factory WebPushStatus.fromJson(Map<String, dynamic> json) => WebPushStatus(
    enabled: json['enabled'] == true,
    subscribed: json['subscribed'] == true,
    permission: json['permission'] as String? ?? 'default',
    nextPrayer: json['nextPrayer'] as String?,
    nextAt: DateTime.tryParse(json['nextAt'] as String? ?? ''),
    timeZone: json['timeZone'] as String?,
  );
  final bool enabled;
  final bool subscribed;
  final String permission;
  final String? nextPrayer;
  final DateTime? nextAt;
  final String? timeZone;
}

/// Separate from the Android preferences, plugin and alarm scheduler.
class WebPushService {
  const WebPushService();
  static const apiUrl = String.fromEnvironment(
    'WEB_PUSH_API_URL',
    defaultValue: '${MUSLIM_API_URL}web-push',
  );

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final raw = await callWebPush(action, apiUrl, jsonEncode(payload));
    final result = jsonDecode(raw) as Map<String, dynamic>;
    if (result['error'] case final String code) throw WebPushException(code);
    return result;
  }

  Future<WebPushStatus> status() async =>
      WebPushStatus.fromJson(await _call('status'));

  Future<Map<String, dynamic>> configuration(
    SharedPreferences prefs, {
    String? language,
    List<String>? prayers,
  }) async {
    final location = jsonDecode(prefs.getString('location') ?? '{}') as Map;
    final path = await helper.constructAPIParameters(
      '',
      helper.dateFormatter(DateTime.now()),
      Map<String, dynamic>.from(location),
      Future.value(prefs),
    );
    if (path == null) throw const WebPushException('location_required');
    return {
      'query': Uri.parse(path).queryParameters,
      'locale': language ?? prefs.getString(webPushLanguageKey) ?? 'en',
      'prayers': prayers ?? selectedPrayers(prefs),
    };
  }

  List<String> selectedPrayers(SharedPreferences prefs) =>
      prefs.getStringList(webPushPrayersKey) ??
      List.of(PRAYER_NOTIFICATION_NAMES);

  /// The prepared configuration allows the browser permission request to run
  /// directly in the tap handler, before any preferences/network awaits.
  Future<void> enable(
    SharedPreferences prefs,
    Map<String, dynamic> config,
  ) async {
    await _call('enable', config);
    await prefs.setBool(webPushEnabledKey, true);
    await prefs.setString(webPushLanguageKey, config['locale'] as String);
  }

  Future<void> disable(SharedPreferences prefs) async {
    await _call('disable');
    await prefs.setBool(webPushEnabledKey, false);
  }

  Future<void> update(
    SharedPreferences prefs, {
    String? language,
    List<String>? prayers,
  }) async {
    final config = await configuration(
      prefs,
      language: language,
      prayers: prayers,
    );
    await _call('sync', config);
    if (prayers != null) await prefs.setStringList(webPushPrayersKey, prayers);
    if (language != null) await prefs.setString(webPushLanguageKey, language);
  }

  Future<void> test() async {
    await _call('test');
  }
}

/// Best effort sync on startup/resume/settings changes. Failures are reported
/// to the caller so settings can display their existing update-pending notice.
Future<bool> syncSavedWebPush({String? language}) async {
  if (!kIsWeb) return true;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(webPushEnabledKey) != true) return true;
  try {
    await const WebPushService().update(prefs, language: language);
    return true;
  } catch (_) {
    return false;
  }
}
