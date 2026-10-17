import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Saves all app data as one JSON file in the app's private folder.
/// Writes go to a temp file first, then replace the old file, so a crash
/// mid-save never corrupts existing data.
class Storage {
  Storage._();

  static const _fileName = 'labledger_data.json';

  static Future<File> file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final f = await file();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final f = await file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}
