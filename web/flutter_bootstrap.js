{{flutter_js}}
{{flutter_build_config}}

// The prayer push worker owns the app scope. Do not register Flutter's legacy
// cache worker over it on subsequent visits.
_flutter.loader.load();
