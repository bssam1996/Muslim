import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants.dart';
import '../../utils/web_push_service.dart';

class WebPrayerNotificationsPage extends StatefulWidget {
  const WebPrayerNotificationsPage({
    super.key,
    required this.prefs,
    this.service = const WebPushService(),
  });
  final Future<SharedPreferences> prefs;
  final WebPushService service;

  @override
  State<WebPrayerNotificationsPage> createState() =>
      _WebPrayerNotificationsPageState();
}

class _WebPrayerNotificationsPageState extends State<WebPrayerNotificationsPage>
    with WidgetsBindingObserver {
  SharedPreferences? _prefs;
  WebPushStatus? _status;
  Map<String, dynamic>? _configuration;
  List<String> _prayers = [];
  String? _error;
  String? _message;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  String _errorKey(Object error) =>
      error is WebPushException ? error.translationKey : 'Web_Push_Error';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _configuration = null;
    });
    try {
      final prefs = await widget.prefs;
      final status = await widget.service.status();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _status = status;
        _prayers = widget.service.selectedPrayers(prefs);
      });
      await prefs.setBool(webPushEnabledKey, status.subscribed);
      final config = await widget.service.configuration(
        prefs,
        language: mounted ? context.locale.languageCode : null,
      );
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _status = status;
        _configuration = config;
        _prayers = widget.service.selectedPrayers(prefs);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorKey(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? message}) async {
    // Calling action before awaiting preserves the notification permission
    // request's user gesture on Safari and other browsers.
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted) setState(() => _message = message);
    } catch (error) {
      if (mounted) setState(() => _error = _errorKey(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status?.enabled == true;
    return Scaffold(
      appBar: AppBar(title: Text('Prayer_Notifications_Title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Web_Push_Description'.tr()),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _busy ? null : _load,
                child: Text('Web_Push_Retry'.tr()),
              ),
            ),
          ],
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!.tr())),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            key: const ValueKey('web_push_enable'),
            title: Text('Web_Push_Enable'.tr()),
            subtitle: Text(
              (enabled ? 'Web_Push_Enabled' : 'Web_Push_Disabled').tr(),
            ),
            value: enabled,
            onChanged: _busy || (!enabled && _configuration == null)
                ? null
                : (value) => _run(
                    () => value
                        ? widget.service.enable(_prefs!, _configuration!)
                        : widget.service.disable(_prefs!),
                  ),
          ),
          if (_status?.subscribed == true && !enabled) ...[
            if (_status?.permission != 'granted')
              Text('Web_Push_Permission_Denied'.tr()),
            TextButton(
              key: const ValueKey('web_push_remove'),
              onPressed: _busy
                  ? null
                  : () => _run(() => widget.service.disable(_prefs!)),
              child: Text('Web_Push_Remove'.tr()),
            ),
          ],
          for (final name in PRAYER_NOTIFICATION_NAMES)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              key: ValueKey('web_push_$name'),
              title: Text(name.tr()),
              value: _prayers.contains(name),
              onChanged: _busy || !enabled
                  ? null
                  : (value) {
                      final next = PRAYER_NOTIFICATION_NAMES
                          .where(
                            (prayer) => prayer == name
                                ? value == true
                                : _prayers.contains(prayer),
                          )
                          .toList();
                      _run(
                        () => widget.service.update(
                          _prefs!,
                          prayers: next,
                          language: context.locale.languageCode,
                        ),
                      );
                    },
            ),
          if (enabled && _prayers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status?.nextPrayer != null && _status?.nextAt != null
                  ? 'Web_Push_Next'.tr(
                      namedArgs: {
                        'prayer': _status!.nextPrayer!.tr(),
                        'time': DateFormat.yMd(
                          context.locale.toString(),
                        ).add_Hm().format(_status!.nextAt!.toLocal()),
                      },
                    )
                  : 'Web_Push_Schedule_Pending'.tr(),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('web_push_test'),
            onPressed: _busy || !enabled
                ? null
                : () =>
                      _run(widget.service.test, message: 'Web_Push_Test_Sent'),
            icon: const Icon(Icons.notifications_outlined),
            label: Text('Web_Push_Test'.tr()),
          ),
          const SizedBox(height: 16),
          Text('Web_Push_Limitations'.tr()),
          const SizedBox(height: 12),
          Text('Web_Push_Privacy'.tr()),
        ],
      ),
    );
  }
}
