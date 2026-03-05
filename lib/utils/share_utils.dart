import 'package:share_plus/share_plus.dart';

import '../shared/constants.dart' as constants;

void shareApp(){
  Uri uri = Uri.parse(constants.MUSLIM_GOOGLE_PLAY_URI);
  final params = ShareParams(
      title: "Muslim",
      subject: "Muslim App Recommendation",
      uri: uri);

  SharePlus.instance.share(params);
}