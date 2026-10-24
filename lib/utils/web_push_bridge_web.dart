import 'dart:js_interop';

@JS('muslimWebPush.call')
external JSPromise<JSString> _call(
  JSString action,
  JSString api,
  JSString data,
);

Future<String> callWebPush(String action, String apiUrl, String payload) =>
    _call(
      action.toJS,
      apiUrl.toJS,
      payload.toJS,
    ).toDart.then((value) => value.toDart);
