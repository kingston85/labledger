import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/storage.dart';

String safeName(String s) {
  final c = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').replaceAll(RegExp(r'\s+'), '_');
  return c.isEmpty ? 'labledger' : c;
}

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// On a PC there is no share sheet: ask where to save the file instead.
Future<void> _saveAs(ScaffoldMessengerState messenger, String fileName, Uint8List bytes, String mime) async {
  final ext = fileName.contains('.') ? fileName.split('.').last : '';
  final loc = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [if (ext.isNotEmpty) XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
  );
  if (loc == null) return;
  var path = loc.path;
  if (ext.isNotEmpty && !path.toLowerCase().endsWith('.$ext')) path = '$path.$ext';
  await File(path).writeAsBytes(bytes, flush: true);
  messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
}

Future<void> shareBytes(BuildContext context, String fileName, Uint8List bytes, String mime, {String? subject}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (isDesktop) {
    try {
      await _saveAs(messenger, fileName, bytes, mime);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
    return;
  }
  try {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: subject ?? fileName);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not share: $e')));
  }
}

Future<void> shareText(BuildContext context, String fileName, String text, String mime, {String? subject}) =>
    shareBytes(context, fileName, Uint8List.fromList(utf8.encode(text)), mime, subject: subject);

Future<void> shareBackupFile(BuildContext context, Future<void> Function() saveNow) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await saveNow();
    final f = await Storage.file();
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    if (isDesktop) {
      final d0 = DateTime.now();
      await _saveAs(messenger, 'LabLedger_backup_${d0.year}-${d0.month.toString().padLeft(2, '0')}-${d0.day.toString().padLeft(2, '0')}.json',
          await f.readAsBytes(), 'application/json');
      return;
    }
    final copy = await f.copy('${dir.path}/LabLedger_backup_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json');
    await Share.shareXFiles([XFile(copy.path, mimeType: 'application/json')], subject: 'LabLedger backup');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not back up: $e')));
  }
}

/// Lets the user pick a LabLedger backup (.json) and returns its contents.
Future<Map<String, dynamic>?> pickBackup(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'LabLedger backup', extensions: ['json'], mimeTypes: ['application/json', 'application/octet-stream', 'text/plain'], uniformTypeIdentifiers: ['public.json']),
    ]);
    if (file == null) return null;
    final data = jsonDecode(await file.readAsString());
    if (data is! Map || data['samples'] is! List) throw 'This is not a LabLedger backup file.';
    return data.cast<String, dynamic>();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open backup: $e')));
    return null;
  }
}
