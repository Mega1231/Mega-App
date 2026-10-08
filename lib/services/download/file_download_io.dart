import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to the app documents folder and returns the file path.
Future<String> saveGeneratedFile(Uint8List bytes, String fileName,
    {String mimeType = 'application/pdf'}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Saves [bytes] to the documents folder (mobile has no browser tab).
Future<void> openFileInBrowser(Uint8List bytes, String fileName,
        {required String mimeType}) =>
    saveGeneratedFile(bytes, fileName, mimeType: mimeType);
