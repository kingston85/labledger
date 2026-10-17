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
    // Phones keep data in the app's private documents folder; on a PC that
    // would be the user's Documents, so use the per-user app data folder.
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final dir = desktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
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
    if (Platform.isWindows && await f.exists()) await f.delete(); // rename cannot replace on Windows
    await tmp.rename(f.path);
  }
}
