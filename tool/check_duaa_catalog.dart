import 'dart:io';
import 'package:muslim/UI/dua/models/dua_catalog.dart';

/// Editorial approval check, separate from runtime availability in release.
void main(List<String> args) {
  final path = args.isEmpty ? 'assets/dua/catalog/catalog.json' : args.single;
  try {
    final catalog = DuaCatalog.decode(File(path).readAsStringSync());
    if (catalog.entries.isEmpty) {
      stderr.writeln(
        'No independently approved Duaa entries yet. The source-checked pilot is available in all builds; editorial approval is managed through releases.',
      );
      exitCode = 2;
      return;
    }
    stdout.writeln(
      '${catalog.version}: ${catalog.entries.length} approved entries; ${catalog.sourcesFor(catalog.entries).length} sources.',
    );
  } catch (error) {
    stderr.writeln('Catalogue rejected: $error');
    exitCode = 1;
  }
}
