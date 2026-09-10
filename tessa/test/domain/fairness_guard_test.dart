import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quelltext ohne Zeilenkommentare — damit die Waechter auf echten Code
/// anschlagen und nicht auf Prosa, die dieselben Woerter erklaert.
String codeOf(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

List<File> dartFilesIn(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    throw StateError('Verzeichnis fehlt: $path (Tests aus dem Projektroot starten)');
  }
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('Fairness-Garantie', () {
    // Siehe CLAUDE.md: Die Steinsequenz haengt ausschliesslich vom Seed ab.
    // Diese Tests halten die Erzeugung davon frei, ueberhaupt etwas anderes
    // erreichen zu koennen — Punktzahl, Uhr, Geraet, Kauf- oder Werbezustand.
    const verbotenInErzeugung = [
      'dart:io',
      'dart:math',
      'dart:async',
      'package:',
      'DateTime',
      'Platform',
      'Timer',
      'HttpClient',
      'sqflite',
      'SharedPreferences',
      'Stopwatch',
    ];

    test('die Erzeugung erreicht nichts ausserhalb von Seed und Index', () {
      final files = dartFilesIn('lib/domain/generation');
      expect(files, isNotEmpty);
      for (final file in files) {
        final code = codeOf(file);
        for (final verboten in verbotenInErzeugung) {
          expect(code.contains(verboten), isFalse,
              reason: '${file.path} verwendet "$verboten" — die Steinsequenz '
                  'darf nur von Seed und Index abhaengen (CLAUDE.md)');
        }
      }
    });

    test('die Erzeugung importiert nur Modelle aus der Domaene', () {
      for (final file in dartFilesIn('lib/domain/generation')) {
        final imports = codeOf(file)
            .split('\n')
            .where((line) => line.trimLeft().startsWith('import '));
        for (final line in imports) {
          expect(line.contains("'../model/") || line.contains("'./") ||
                  !line.contains('/'),
              isTrue,
              reason: '${file.path}: unerwarteter Import $line');
        }
      }
    });

    test('die Domaene bleibt frei von Flutter', () {
      // Reines Dart heisst: schnell testbar und ohne Bindung an eine Oberflaeche.
      for (final file in dartFilesIn('lib/domain')) {
        expect(codeOf(file).contains('package:flutter'), isFalse,
            reason: '${file.path} importiert Flutter');
      }
    });
  });
}
