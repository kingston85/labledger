// Sample photographs: picked from the gallery / disk and copied into the
// app's own folder so they survive the original being moved or deleted.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

const _images = XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'], mimeTypes: ['image/*'], uniformTypeIdentifiers: ['public.image']);

Future<Directory> _photoDir() async {
  final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  final base = desktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
  final d = Directory('${base.path}${Platform.pathSeparator}photos');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// Lets the user choose one or more pictures and returns their stored paths.
Future<List<String>> pickPhotos(String prefix) async {
  final files = await openFiles(acceptedTypeGroups: const [_images]);
  if (files.isEmpty) return const [];
  final dir = await _photoDir();
  final out = <String>[];
  var i = 0;
  for (final f in files) {
    final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
    final safe = prefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = '${dir.path}${Platform.pathSeparator}${safe}_${DateTime.now().millisecondsSinceEpoch}_${i++}.$ext';
    await File(path).writeAsBytes(await f.readAsBytes(), flush: true);
    out.add(path);
  }
  return out;
}

/// Picks one image and returns it base64-encoded (used for the lab logo).
Future<String?> pickImageB64({int maxBytes = 600 * 1024}) async {
  final f = await openFile(acceptedTypeGroups: const [_images]);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  if (bytes.length > maxBytes) throw Exception('Image is larger than ${maxBytes ~/ 1024} KB — please use a smaller logo file.');
  return base64Encode(bytes);
}

Future<Uint8List?> readPhoto(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> deletePhoto(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
