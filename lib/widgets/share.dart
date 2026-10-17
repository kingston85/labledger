import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/storage.dart';

String safeName(String s) {
  final c = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').replaceAll(RegExp(r'\s+'), '_');
  return c.isEmpty ? 'labledger' : c;
}

Future<void> shareBytes(BuildContext context, String fileName, Uint8List bytes, String mime, {String? subject}) async {
  final messenger = ScaffoldMessenger.of(context);
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
    final copy = await f.copy('${dir.path}/LabLedger_backup_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json');
    await Share.shareXFiles([XFile(copy.path, mimeType: 'application/json')], subject: 'LabLedger backup');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not back up: $e')));
  }
}
