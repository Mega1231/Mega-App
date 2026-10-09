import 'dart:io';
import 'dart:typed_data';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to the app documents folder and returns the file path.
Future<String> saveGeneratedFile(Uint8List bytes, String fileName,
    {String mimeType = 'application/pdf'}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Opens [bytes] in the phone's viewer. Uses the temp folder, not the
/// documents folder, because these are applicants' private documents.
Future<void> openFileInBrowser(Uint8List bytes, String fileName,
    {required String mimeType}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await OpenFile.open(file.path, type: mimeType);
}
