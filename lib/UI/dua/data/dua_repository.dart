import 'package:flutter/services.dart';
import '../models/dua_catalog.dart';
import 'dua_preview.dart';

class DuaRepository {
  static Future<DuaCatalog> load() async {
    final published = DuaCatalog.decode(
      await rootBundle.loadString('assets/dua/catalog/catalog.json'),
    );
    if (published.entries.isNotEmpty) return published;
    // The user enabled the source-checked pilot in all build modes. Preserve
    // its review metadata; editorial approval is managed through releases.
    return DuaCatalog.decode(duaPreviewJson, allowPreview: true);
  }
}
